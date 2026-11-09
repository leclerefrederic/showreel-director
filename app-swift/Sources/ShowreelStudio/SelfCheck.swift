import AppKit
import Foundation
import ShowreelKit

/// A UI with no window: answers proposals with a fixed choice and records what it was shown.
private final class NullUI: AgentUI {
    var accept = false
    var proposals: [Proposal] = []
    var cards: [OperationCard] = []
    func proposeOperation(_ card: OperationCard) async -> Bool { cards.append(card); return accept }
    func propose(_ p: Proposal) async -> Bool { proposals.append(p); return accept }
    func foregroundFile() async -> String? { "storyboard.md" }
    func text(_ t: String) {}
    func endText() {}
    func tool(_ name: String, _ input: [String: Any]) {}
    func show(_ url: String, _ title: String) {}
    func screenshot(javascript: String?, waitMs: Int) async -> Data? { nil }
    func ask(_ questions: [[String: Any]]) async -> [String] { [] }
}

private final class Box<T> {
    var value: T
    init(_ v: T) { value = v }
}

/// Runs an async job on the main actor while keeping the main run loop turning (the engine's web view needs it).
private func awaitMain<T>(timeout: TimeInterval = 60, _ job: @escaping @MainActor () async throws -> T) -> Result<T, Error> {
    var result: Result<T, Error>?
    Task { @MainActor in do { result = .success(try await job()) } catch { result = .failure(error) } }
    let end = Date(timeIntervalSinceNow: timeout)
    while result == nil && Date() < end { RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05)) }
    return result ?? .failure(AgentError.msg("timeout"))
}

/// Counts the colours of an image and how much of it is a given colour (raw values, no colour management).
private func pixelStats(_ data: Data, background hex: String) -> (distinct: Int, shareOfBackground: Double) {
    guard let rep = NSBitmapImageRep(data: data) else { return (0, 0) }
    let t = EnginePalette.rgb(hex).map { Int($0) }
    var seen = Set<Int>(), near = 0, total = 0
    for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide {
        guard let c = rep.colorAt(x: x, y: y) else { continue }
        let r = Int((c.redComponent * 255).rounded()), g = Int((c.greenComponent * 255).rounded()), b = Int((c.blueComponent * 255).rounded())
        seen.insert((r / 16) << 8 | (g / 16) << 4 | (b / 16)); total += 1
        if abs(r - t[0]) <= 10 && abs(g - t[1]) <= 10 && abs(b - t[2]) <= 10 { near += 1 }
    } }
    return (seen.count, Double(near) / Double(max(total, 1)))
}

/// `ShowreelStudio --selftest`: checks, without any window or network, that the app finds everything it needs
/// (inside its own bundle when packaged), builds its prompt and runs its tools safely. Exit code 0 when all pass.
enum SelfCheck {
    static func run() -> Int32 {
        var failures = 0
        func check(_ ok: Bool, _ label: String) { print((ok ? "PASS " : "FAIL ") + label); if !ok { failures += 1 } }
        let fm = FileManager.default
        let bundled = Bundle.main.bundlePath.hasSuffix(".app")
        let bundlePath = Bundle.main.bundlePath
        func inside(_ u: URL?) -> Bool { guard let u = u else { return false }; return !bundled || u.path.hasPrefix(bundlePath + "/") }

        let root = Skill.root()
        check(root != nil && inside(root), "skill folder found" + (bundled ? " inside the app" : ""))
        let shared = resource("shared", dev: "app-swift/shared")
        for f in ["tools.json", "addendum.md", "capabilities.json"] {
            let u = shared?.appendingPathComponent(f)
            check(u != nil && fm.fileExists(atPath: u!.path) && inside(u), "shared/\(f)")
        }
        check(!Tools.definitions.isEmpty, "tool definitions load (\(Tools.definitions.count))")
        let script = ShellRunner.scriptURL()
        check(script != nil && inside(script), "setup script found")
        if bundled {
            check(Skill.fingerprint().count == 12, "skill fingerprint present (\(Skill.fingerprint()))")
            check(fm.fileExists(atPath: bundlePath + "/Contents/Resources/AppIcon.icns"), "app icon in the bundle")
        }

        let tmp = fm.temporaryDirectory.appendingPathComponent("showreel-selftest-\(UUID().uuidString)")
        try? fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        if let sp = try? Skill.systemPrompt(project: tmp, lang: nil) {
            check(sp.text.contains("Showreel director") && sp.text.contains("Running inside Showreel Studio") && !sp.text.contains("{{"),
                  "system prompt builds, no placeholder left")
        } else {
            check(false, "system prompt builds")
        }

        if let r = root {
            let ui = NullUI()
            let tools = Tools(project: tmp, skill: r, ui: ui)
            func call(_ name: String, _ input: [String: Any]) -> String {
                let sem = DispatchSemaphore(value: 0)
                let out = Box("")
                Task { out.value = await tools.run(name, input).text; sem.signal() }
                sem.wait()
                return out.value
            }
            check(call("write_file", ["path": "a/b.txt", "content": "hello"]).hasPrefix("wrote") && fm.fileExists(atPath: tmp.appendingPathComponent("a/b.txt").path), "write_file writes inside the project")
            check(call("write_file", ["path": "../escape.txt", "content": "no"]).hasPrefix("refused"), "write_file refuses to leave the project")
            check(call("read_file", ["path": "/etc/hosts"]).hasPrefix("refused"), "read_file refuses outside project and skill")
            check(call("read_file", ["path": "SKILL.md", "limit": 3]).contains("\t"), "read_file falls back to the skill folder")
            check(call("bash", ["command": "echo selftest-ok"]).contains("selftest-ok"), "bash runs in a login shell")
            check(call("bash", ["command": "pwd"]).contains(tmp.lastPathComponent), "bash starts in the project folder")
            check(call("no_such_tool", [:]).hasPrefix("unknown tool"), "unknown tool is reported")

            // project model: showreel.json, the copilot's edits as proposals, history
            let store = ProjectStore(root: tmp)
            check((try? store.create(name: "Selftest", conversationLanguage: "en", reelLanguages: ["en"])) != nil
                  && store.loadShowreel()?.name == "Selftest", "showreel.json is created and read back")
            check(call("get_state", [:]).contains("\"name\" : \"Selftest\"") && call("get_state", [:]).contains("storyboard.md"),
                  "get_state returns the showreel and the file in front of the user")
            _ = call("write_file", ["path": "notes.md", "content": "one\n"])
            ui.accept = false
            check(call("propose_edit", ["file": "notes.md", "content": "two\n"]).hasPrefix("refused by the user")
                  && store.read("notes.md") == "one\n", "a refused proposal leaves the file alone")
            ui.accept = true
            check(call("propose_edit", ["file": "notes.md", "content": "two\n"]).hasPrefix("accepted")
                  && store.read("notes.md") == "two\n", "an accepted proposal is written")
            check(call("write_file", ["path": "notes.md", "content": "three\n"]).hasPrefix("accepted")
                  && ui.proposals.count == 3, "write_file on an existing markdown file becomes a proposal")
            check(store.snapshots("notes.md").count == 2, "each write keeps the previous version in the history")
            check(call("write_file", ["path": ".studio/x.txt", "content": "no"]).hasPrefix("refused"), ".studio stays private to the app")

            // blocks: process.json, typed operations as cards, assets, the app owns showreel.json
            let spec = ProcessSpec.load()
            check(spec?.blocks.map { $0.id } == Blocks.ids, "process.json blocks match the app (\(spec?.blocks.count ?? 0))")
            check(store.loadShowreel()?.isStudioOwned == true, "the first save marks origin.tool as studio")
            ui.accept = false
            check(call("update_parameter", ["key": "audience", "value": "Teams"]).hasPrefix("refused by the user") && store.loadShowreel()?.parameters.audience == nil,
                  "a refused card changes nothing")
            ui.accept = true
            check(call("update_parameter", ["key": "audience", "value": "Teams"]).hasPrefix("accepted") && store.loadShowreel()?.parameters.audience == "Teams"
                  && ui.cards.last?.changes == [Change("Audience", "(empty)", "Teams")], "an accepted card applies a typed change")
            check(call("write_file", ["path": "showreel.json", "content": "{}"]).hasPrefix("refused"), "showreel.json refuses file writes")
            let src = tmp.appendingPathComponent("incoming-logo.svg")
            try? "<svg/>".write(to: src, atomically: true, encoding: .utf8)
            let added = (try? Assets.add([src], to: store)) ?? []
            check(added.first?.id == "logo-01" && Assets.load(store).count == 1
                  && fm.fileExists(atPath: tmp.appendingPathComponent("assets/prepared/logo-01-incoming.svg").path), "a dropped file is copied and listed in MANIFEST.csv")
            check(store.read("brief.md")?.contains("Teams") == true, "brief.md is generated from showreel.json")

            // modes, wizard, checks, versions
            check(store.settings.mode == StudioSettings.beginner, "a new project starts in beginner mode")
            let steps = Wizard.steps(assets: Assets.load(store), spec: spec)
            check(steps.count >= 10 && steps.contains { !$0.isBuilt }, "the wizard has its steps and the blocks to come (\(steps.count))")
            check(Wizard.firstUndecided(steps, file: store.loadShowreel(), assets: Assets.load(store), settings: store.settings, spec: spec).map { steps[$0].id } == "project.message",
                  "the wizard resumes after what is already decided (languages, audience) at the first undecided step")
            check(Checks.run(area: "project", store: store).first { $0.id.hasPrefix("feasibility") }?.level == .pending && !Checks.run(area: "resources", store: store).isEmpty, "deterministic checks run without AI")
            check(spec?.blocks.filter { $0.ai == "required" }.map { $0.id } == ["build"], "only build requires generation")
            check(Skill.version()?.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil, "skill version is read (\(Skill.version() ?? "none"))")
        }
        // the engine: the skill's own JavaScript, run from the skill folder (the app bundle when packaged), draws an effect and a background
        _ = NSApplication.shared
        let engineScript = shared?.appendingPathComponent("engine-host.js")
        check(engineScript != nil && fm.fileExists(atPath: engineScript!.path) && inside(engineScript), "engine host script found" + (bundled ? " inside the app" : ""))
        check(shared?.appendingPathComponent("look-packages.json").path.isEmpty == false && LookPackages.all().count >= 6, "starting looks load (\(LookPackages.all().count))")
        let pal = EnginePalette(bg: "#101820", fg: "#FFFFFF", accent: "#F2AA4C", accent2: "#4CC2F2")
        let drawn = awaitMain { () -> (Int, Int, Data, Data, [String], Set<String>, Set<String>) in
            let e = EngineRenderer()
            try await e.start()
            let fx = try await e.renderEffect("Pop", palette: pal, font: "Helvetica", t: 0.9)
            let bgd = try await e.renderBackground("duotone", palette: pal, t: 0)
            return (e.catalogue?.effects.count ?? 0, e.catalogue?.backgrounds.count ?? 0, fx, bgd, try await e.errors(), Set(e.catalogue?.effects.map { $0.name } ?? []), Set(e.catalogue?.effects.filter { $0.cat == EngineCatalogue.transitionCategory }.map { $0.name } ?? []))
        }
        switch drawn {
        case .success(let (nfx, nbg, fx, bgd, errs, names, trans)):
            check(trans == Set(Look.transitions().map { $0.name }) && trans.count >= 40, "the scene transitions of the library are the engine's (\(trans.count))")
            check(names == Set(Look.effects()), "the effect library the checks read (effects-index.md) is the engine's catalogue (\(names.count))")
            check(nfx >= 240 && nbg >= 20, "engine catalogue loads (\(nfx) effects, \(nbg) backgrounds)")
            let a = pixelStats(fx, background: pal.bg), b = pixelStats(bgd, background: pal.bg)
            check(a.distinct > 3 && a.shareOfBackground > 0.5, "an effect renders: not empty, drawn in the palette (\(a.distinct) colours)")
            check(b.distinct > 1 && b.shareOfBackground > 0.4, "a background renders: not empty, drawn in the palette (\(b.distinct) colours)")
            check(errs.isEmpty, "the engine raised no error while drawing")
        case .failure(let err):
            check(false, "engine renders an effect and a background (\(err.localizedDescription))")
        }
        // storyboard, the Go and the build, from the bundle: the Go is never deduced, and a version builds into the project folder
        let sb = fm.temporaryDirectory.appendingPathComponent("showreel-selftest-build-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: sb) }
        let bs = ProjectStore(root: sb)
        if (try? bs.create(name: "Selftest", conversationLanguage: "en", reelLanguages: ["en"])) != nil, let r = Skill.root() {
            try? bs.apply(.addScene(id: "", SceneEdit(duration: "4", text: "Hello", status: "validated")))
            try? bs.apply(.gate("storyboard", passed: true))
            check(bs.loadShowreel()?.scenes.first?.id == "S01" && bs.loadShowreel()?.gates["review"] == nil && !BuildRunner.canBuild(bs), "scenes are added with stable IDs, and the Go is never deduced")
            check((try? bs.apply(.gate("review", passed: true))) != nil && BuildRunner.canBuild(bs), "the Go is given by an explicit operation")
            let vd = sb.appendingPathComponent("v1")
            try? fm.createDirectory(at: vd, withIntermediateDirectories: true)
            try? "{\"title\": \"Selftest\", \"main\": \"main.js\", \"duration\": 8, \"tokens\": {\"--page\": \"#000\", \"--bar-bg\": \"#111\", \"--bar-fg\": \"#eee\", \"--btn-bg\": \"#ddd\", \"--btn-fg\": \"#111\", \"--accent\": \"#fff\", \"--ov-bg\": \"rgba(0,0,0,.85)\", \"--ov-fg\": \"#fff\", \"--font-ui\": \"sans-serif\", \"--font-title\": \"sans-serif\"}, \"weight_budget_mb\": 20}".write(to: vd.appendingPathComponent("project.json"), atomically: true, encoding: .utf8)
            if let tpl = try? String(contentsOf: r.appendingPathComponent("engine/main.template.js"), encoding: .utf8) { try? tpl.write(to: vd.appendingPathComponent("main.js"), atomically: true, encoding: .utf8) }
            let tools = awaitMain(timeout: 120) { await Shell.run("command -v python3 && command -v node && node -e \"require('jsdom')\"", in: sb, timeout: 30)?.status ?? 1 }
            if case .success(0) = tools {
                let rep = awaitMain(timeout: 240) { await BuildRunner.run(version: "v1", store: bs, skill: r) }
                if case .success(let report) = rep {
                    check(report.ok, "a version builds, tests clean and lands in the project folder (" + report.steps.map { "\($0.id.dropFirst(6)) \($0.level.rawValue)" }.joined(separator: ", ") + ")")
                    check(Versions.hasDist(bs, "v1") && inside(r) && !fm.fileExists(atPath: r.appendingPathComponent("dist").path), "the output is v1/dist in the project, nothing written into the skill")
                } else { check(false, "the build runner finished") }
            } else { print("SKIP build run (python3, node or jsdom missing: run the setup check)") }
        }
        // the scene library and the montage (phase W1): the phase T shape migrates, switching a scene off and reordering are typed operations that take the Go back
        let phaseT = #"{"schema": 1, "name": "T", "scenes": [{"id": "S01", "start": 0, "end": 4, "text": "A"}, {"id": "S02", "start": 4, "end": 6, "status": "ditched"}]}"#
        let migrated = try? ShowreelFile.decode(phaseT)
        check(migrated?.scenes.first?.duration == 4 && migrated?.storyboards.first?.items.map { $0.enabled } == [true, false] && migrated?.scenes[1].archived == true,
              "a phase T file migrates into a scene library and one montage (ditched = archived and off)")
        if bs.loadShowreel() != nil {
            try? bs.apply(.addScene(id: "", SceneEdit(duration: "3", text: "Second", status: "validated")))
            try? bs.apply(.gate("review", passed: true))
            try? bs.apply(.moveScene(id: "S02", after: "start", montage: nil))
            check(bs.loadShowreel()?.film.map { $0.id } == ["S02", "S01"] && bs.loadShowreel()?.gates["review"] == "open", "reordering the storyboard is an operation, and takes the Go back")
            try? bs.apply(.sceneEnabled(id: "S01", enabled: false, montage: nil))
            check(bs.loadShowreel()?.film.map { $0.id } == ["S02"] && bs.loadShowreel()?.library.count == 2, "switching a scene off keeps it in the library")
            check(bs.read("storyboard.md")?.contains("off") == true, "storyboard.md is generated from the library and the montage")
            try? bs.apply(.content(scene: "S02", .add(ContentEdit(type: "text", text: "More", color: "accent", animation: "Pop"), after: nil)))
            check(bs.loadShowreel()?.scenes.first { $0.id == "S02" }?.content.last?.animation.effect == "Pop" && BuildRunner.prompt(version: "v2", store: bs).contains("animation: FIXED Pop"),
                  "a content item is an operation, and the build message lists it with its fixed attributes")
            try? bs.apply(.sceneEnabled(id: "S01", enabled: true, montage: nil))
            if let lead = bs.loadShowreel()?.film.first?.id {
                try? bs.apply(.transition(from: lead, TransitionEdit(type: "Push", duration: 0.5)))
                try? bs.apply(.resize(scene: lead, duration: 6, ripple: true))
                check(bs.loadShowreel()?.storyboards.first?.items.first { $0.scene == lead }?.transition.type == "Push" && bs.loadShowreel()?.scenes.first { $0.id == lead }?.duration == 6
                      && BuildRunner.prompt(version: "v2", store: bs).contains("Push 0.5 s"), "a transition and a duration are operations, and the build message lists the transition")
            }
            check(Film.data(bs.loadShowreel()!)["scenes"] is [[String: Any]] && BuildRunner.prompt(version: "v2", store: bs).contains("SRF.fromData(MODULES") && Look.transitionsPreviewOnly().count == 6
                  && (try? bs.apply(.transition(from: bs.loadShowreel()?.film.first?.id ?? "S01", TransitionEdit(type: "Morph")))) == nil, "the build message quotes the montage (film.json) and a preview-only transition cannot be chosen")
            try? bs.apply(.sceneLook(id: "S02", [DecisionChange(.background, "duotone")]))
            if let f = bs.loadShowreel(), let sc = f.scenes.first(where: { $0.id == "S02" }) {
                let node = SceneTree.build(sc, in: f, assets: [], store: bs).first { $0.group == .look }?.nodes.first { $0.id == "background" }
                check(node?.origin == .overridden && f.decisions.background == nil, "a scene overrides its background without touching the project's")
            }
        }
        // direct manipulation (phase W5): a scene's name is a label, a drop is a typed operation that undo takes back, and a refused drop says why
        if let f0 = bs.loadShowreel(), let first = f0.film.first?.id {
            let textsBefore = [bs.read(ShowreelFile.fileName), bs.read(Assets.manifestPath)]
            try? bs.apply(.scene(id: first, SceneEdit(name: "Opening")))
            let named = bs.loadShowreel()?.scenes.first { $0.id == first }
            let dropped = try? Drops.drop(.background(Look.backgroundIDs().first { $0 != "duotone" } ?? "duotone"), on: .scene(first), store: bs)
            let refused = Drops.verdict(.transition("Push"), on: .scene(first), store: bs)
            check(named?.id == first && named?.label == "\(first) \u{00B7} Opening" && dropped != nil && !refused.isValid && !refused.text.isEmpty
                  && (try? bs.undo()) != nil && (try? bs.undo()) != nil && [bs.read(ShowreelFile.fileName), bs.read(Assets.manifestPath)] == textsBefore && bs.undoLog.canRedo,
                  "a scene has a name next to its stable ID, a drop is an operation that undo takes back, and a refused drop says why")
        }
        // phase L: the catalogues are pickers where they are used, and a picker builds the same operation as a drag; the six preview-only transitions are marked
        let trs = Catalogue.choices(.transition)
        check(Catalogue.choices(.effect).count > 200 && trs.count == 42 && trs.filter { !$0.selectable }.count == 6 && Catalogue.choices(.background).count > 20
              && (try? Catalogue.operation(.effect, choice: "Pop", target: .item(scene: "S01", item: "c1"))) == .content(scene: "S01", .update(item: "c1", ContentEdit(animation: "Pop"))),
              "the catalogues are pickers (\(Catalogue.choices(.effect).count) effects, \(trs.count) transitions with \(trs.filter { !$0.selectable }.count) preview-only, \(Catalogue.choices(.background).count) backgrounds) that call the operation a drag builds")
        // phase P1: the design board reads the decisions, a scene's look is locked until its switch, and the tree has the three groups of the inspector
        if let f1 = bs.loadShowreel(), let sc = f1.scenes.first {
            let board = DesignBoard.make(f1)
            let locked = LookOverrides.state(.background, scene: sc, in: f1).locked
            let groups = SceneTree.build(sc, in: f1, assets: [], store: bs).map { $0.group }
            check(!board.sampleText.isEmpty && !board.sampleEffect.isEmpty && locked && groups == [.composition, .effects, .look] && Drops.confirmation(.background("duotone"), on: .scene(sc.id)) != nil,
                  "the design board reads the project, a scene's look is locked until its switch, and the tree is Composition, Effects, Look")
        }
        // phase S: the timeline's scale and layout rules
        let fitPPS = TimelineScale.fit(duration: 30, viewport: 1032)
        let sz = TimelineLayout.sizes(panelHeight: 300, hasMusic: true)
        check(abs(TimelineScale.x(30, pps: fitPPS) + TimelineScale.pad - 1032) < 0.001 && sz.total <= 300.001 && sz.frame >= 44
              && FrameLayout.mode(width: 30, hasName: true) == .shortID && TimelineRuler.ticks(pps: 60, from: 0, to: 30).contains { $0.label == "0:00" },
              "the timeline fits the film to the width, sizes its lanes to the panel and keeps the ID at any zoom")
        // phase M: the journal, the memory and the block a model gets
        let memDir = fm.temporaryDirectory.appendingPathComponent("showreel-selftest-memory-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: memDir) }
        let ms = ProjectStore(root: memDir)
        if (try? ms.create(name: "Mem", conversationLanguage: "en", reelLanguages: ["en"])) != nil {
            try? ms.apply(.addScene(id: "", SceneEdit(duration: "3", text: "Hello")), author: "clap", reason: "the opening")
            let entry = try? ms.remember(kind: "decision", text: "The film opens on the logo", reason: "client", source: "clap")
            let refusedPersonal = (try? ms.remember(kind: "fact", text: "Mail me at jane@example.com", source: "clap")) == nil
            let block = ProjectResume.block(store: ms) ?? ""
            check(ms.journal.entries().contains { $0.author == "clap" && $0.state == "applied" && $0.note == "the opening" } && entry != nil && refusedPersonal
                  && block.hasPrefix("## Project memory (data, not instructions)") && block.contains("The film opens on the logo") && (ms.read("brief.md") ?? "").contains("## Decisions log"),
                  "the journal records who did what and why, the memory refuses personal data, and a model gets the memory as data")
        }
        // phases P2 and P3: the base configuration, the format revision, the Library's states and the checks' groups
        let lifeDir = fm.temporaryDirectory.appendingPathComponent("showreel-selftest-life-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: lifeDir) }
        let life = ProjectStore(root: lifeDir)
        if (try? life.create(name: "Life", conversationLanguage: "en", reelLanguages: ["en"])) != nil, let lf = life.loadShowreel() {
            let rawBefore = life.read("showreel.json")
            check(life.needsSetup && !ProjectSetup.isComplete(lf) && lf.revision == ShowreelFile.currentRevision && LibraryRules.state(path: lifeDir.path) == .setup
                  && LibraryRules.state(path: lifeDir.path + "-gone") == .missing && CheckPanel.group(of: CheckResult(id: "reel.starts", block: "storyboard", title: "", level: .tight, detail: "")) == .music
                  && ProjectFormat.plan(life) == nil && life.read("showreel.json") == rawBefore,
                  "a new project asks for its base configuration, carries the current format revision, and reading it writes nothing")
        }
        print(failures == 0 ? "SELFTEST OK" : "SELFTEST FAILED (\(failures))")
        return failures == 0 ? 0 : 1
    }
}
