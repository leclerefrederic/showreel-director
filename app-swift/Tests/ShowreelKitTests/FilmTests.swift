import XCTest
@testable import ShowreelKit

/// Phase W3b: the montage the build reads (film.json), the Build message in the film format, the transitions that cannot be chosen, and a Build with a
/// scripted model that writes a main.js in the film format and goes through build.py, the harness and the player test.
final class FilmTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("w3b"); store = ProjectStore(root: dir)
        try? store.create(name: "F", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t, status: "ok"))) }
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }

    func scenes(_ d: [String: Any]) -> [[String: Any]] { d["scenes"] as? [[String: Any]] ?? [] }

    // MARK: film.json

    func testTheMontageAsTheBuildReadsIt() throws {
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5, params: "dir=left", instruction: "the card becomes the logo")))
        try store.apply(.transition(from: "S02", TransitionEdit(type: "Iris")))
        let d = Film.data(file), s = scenes(d)
        XCTAssertEqual(s.map { $0["name"] as? String }, ["S01", "S02", "S03"])
        XCTAssertEqual(s.map { $0["t"] as? Double }, [0, 3, 6]); XCTAssertEqual(s.map { $0["duration"] as? Double }, [3, 3, 3])
        let t1 = try XCTUnwrap(s[0]["transition"] as? [String: Any])
        XCTAssertEqual(t1["type"] as? String, "Push"); XCTAssertEqual(t1["duration"] as? Double, 0.5); XCTAssertEqual((t1["params"] as? [String: Any])?["dir"] as? String, "left")
        XCTAssertEqual(t1["instruction"] as? String, "the card becomes the logo")
        XCTAssertEqual((s[1]["transition"] as? [String: Any])?["duration"] as? Double, 1.3, "the duration it will really have: the library's, capped at half the shorter scene")
        XCTAssertNil(s[2]["transition"], "the last scene has no successor")
        try store.apply(.sceneEnabled(id: "S03", enabled: false, montage: nil))
        XCTAssertNil(scenes(Film.data(file))[1]["transition"], "S02 is last now")
        XCTAssertEqual(scenes(Film.data(file)).count, 2, "a scene that is off is not in the film")
        XCTAssertEqual(Film.text(file), Film.text(file), "stable text")
    }

    func testFilmJSONIsWrittenInTheVersionFolderAndKnowsWhenItIsStale() throws {
        XCTAssertNil(Film.isCurrent(version: "v1", store: store))
        let url = try Film.write(version: "v1", store: store)
        XCTAssertEqual(url.lastPathComponent, "film.json"); XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "v1")
        XCTAssertEqual(Film.isCurrent(version: "v1", store: store), true)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        XCTAssertEqual(json?["schema"] as? Int, 1)
        try store.apply(.resize(scene: "S01", duration: 4, ripple: true))
        XCTAssertEqual(Film.isCurrent(version: "v1", store: store), false, "the montage changed after the build")
        XCTAssertEqual(Versions.next(store), "v2", "a folder that only holds film.json is not a version, but its name is never reused")
        XCTAssertEqual(Versions.list(store), [])
    }

    func testTheBuildMessageQuotesTheMontageAndAsksForTheFilmFormat() throws {
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5)))
        let p = BuildJob.frame(version: "v1", store: store, skill: try XCTUnwrap(Skill.root()))
        for needle in ["v1/film.json already exists", "do not repeat it", "Do not write main.js", "\"name\" : \"S01\"", "\"type\" : \"Push\"", "do not draw transitions yourself"] {
            XCTAssertTrue(p.contains(needle), needle)
        }
        XCTAssertFalse(p.contains("engine/main.template.js") || p.contains("main.film.template"), "the old formats are not what the message asks for")
        XCTAssertFalse(p.contains("The Go"))
    }

    // MARK: transitions that cannot be chosen

    func testPreviewOnlyTransitionsAreADataFileAndCannotBeChosen() throws {
        let list = Look.transitionsPreviewOnly()
        XCTAssertEqual(list, ["Morph", "Match cut", "Ink/paper inversion", "Curtain", "Mirror split", "Star reveal"])
        let all = Set(Look.transitions().map { $0.name })
        XCTAssertTrue(list.isSubset(of: all), "each one is a transition of the library")
        XCTAssertTrue(Look.isPreviewOnly("Morph") && !Look.isPreviewOnly("Push"))
        for name in list { XCTAssertThrowsError(try store.plan(.transition(from: "S01", TransitionEdit(type: name))), name) { XCTAssertTrue("\($0)".contains("preview only")) } }
        XCTAssertNoThrow(try store.plan(.transition(from: "S01", TransitionEdit(type: "Cross dissolve"))))
        // a montage edited by hand with one of them is flagged and the build message says to use a cut
        var f = file; f.storyboards[0].items[0].transition = .init(type: "Curtain", duration: 0.5); try store.save(f)
        XCTAssertEqual(Checks.run(area: "storyboard", store: store).first { $0.id == "reel.transition-length" }?.level, .fail)
        XCTAssertTrue(BuildJob.frame(version: "v1", store: store, skill: try XCTUnwrap(Skill.root())).contains("a preview-only transition"))
    }

    func testTheListIsWhatTheProbeFinds() async throws {
        let skill = try XCTUnwrap(Skill.root())
        let probe = await Shell.run("command -v node && command -v python3 && node -e \"require('@napi-rs/canvas')\"", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "node and @napi-rs/canvas are needed (run the app's setup check)")
        let build = dir.appendingPathComponent("film.html")
        let b = await Shell.run("python3 \(BuildRunner.q(skill.appendingPathComponent("scripts/build.py"))) \(BuildRunner.q(skill.appendingPathComponent("evals/film-spike/v1"))) --out \(BuildRunner.q(build))", in: dir, timeout: 120)
        XCTAssertEqual(b?.status, 0, b?.err ?? "")
        let r = await Shell.run("node \(BuildRunner.q(skill.appendingPathComponent("scripts/test_film.js"))) \(BuildRunner.q(build)) --all --json --quiet", in: dir, timeout: 300)
        let line = try XCTUnwrap(r?.out.split(separator: "\n").first { $0.hasPrefix("json ") })
        let j = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.dropFirst(5).utf8)) as? [String: [String]])
        XCTAssertEqual(Set(j["notWorking"] ?? []), Look.transitionsPreviewOnly(), "engine/transitions-preview-only.json is what scripts/test_film.js finds (tools/check.py checks the same)")
        XCTAssertEqual((j["working"] ?? []).count + (j["notWorking"] ?? []).count, Look.transitions().count)
    }

    // MARK: Build end to end with a scripted model

    func testBuildWithAScriptedModelWritesTheFilmFormatAndPlays() async throws {
        let probe = await Shell.run("command -v python3 && command -v node && node -e \"require('jsdom')\"", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "python3, node and jsdom are needed (run the app's setup check)")
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.8)))
        try store.apply(.gate("storyboard", passed: true)); try store.apply(.gate("review", passed: true))
        XCTAssertTrue(BuildRunner.canBuild(store))
        // what Build does first: the version folder with the montage in it, then the message
        let v = Versions.next(store)
        try Film.write(version: v, store: store)
        let prompt = BuildJob.frame(version: v, store: store, skill: try XCTUnwrap(Skill.root()))
        XCTAssertTrue(prompt.contains("\(v)/film.json"))
        // the scripted model writes project.json and main.js in the film format (no montage in main.js)
        let project = "{\"title\": \"Fake\", \"main\": \"main.js\", \"duration\": 9, \"fonts\": [], \"tokens\": {}, \"weight_budget_mb\": 5}"
        let main = """
        (function () {
          const { clamp, ease } = window.SR;
          const field = (col, word) => (g, lt, c) => {
            g.fillStyle = col; g.fillRect(0, 0, c.SW, c.SH);
            g.globalAlpha = ease.out3(clamp(lt / .5)); g.fillStyle = '#ffffff'; g.font = '700 64px system-ui,sans-serif'; g.textAlign = 'center'; g.fillText(word, c.SW / 2, c.SH / 2); g.globalAlpha = 1;
          };
          const film = window.SRF.fromData({ S01: field('#aa2222', 'One'), S02: field('#2222aa', 'Two'), S03: field('#22aa22', 'Three') },
            { palette: { bg: '#101820', fg: '#ffffff', accent: '#F2AA4C', accent2: '#4CC2F2' } });
          window.SHOWREEL = { title: { en: 'Fake' }, slug: 'fake', footnote: { en: '' }, languages: [{ id: 'en', label: 'EN' }], formats: { d: [1600, 900] },
            formatLabels: { d: 'Desktop' }, controls: { pause: true, seek: true, mute: true, volume: true, loop: false, replay: true, lang: true, format: true, notes: false },
            ui: { en: { reduced: 'Reduced motion', reducedOn: 'Reduced motion: on', play: 'Play', pause: 'Pause', muted: 'Sound off', sound: 'Sound on', rp: 'Replay', lp: 'Loop', fm: 'Format', lg: 'Language', startSound: 'Start with sound', startSilent: 'Start without sound' } },
            pageColor: '#000', setup() {}, render: film.render };
        })();
        """
        let ui = ScriptedUI()
        let t = ScriptedTransport([
            ([toolUse("a", "write_file", ["path": "\(v)/project.json", "content": project]), toolUse("b", "write_file", ["path": "\(v)/main.js", "content": main])], "tool_use"),
            ([textBlock("Built the film format.")], "end_turn"),
        ])
        let agent = try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: t)
        try await agent.send(prompt)
        XCTAssertEqual(Versions.list(store), [v], "the model wrote the version folder")
        let mainText = try String(contentsOf: dir.appendingPathComponent("\(v)/main.js"), encoding: .utf8)
        XCTAssertFalse(mainText.contains("Push") || mainText.contains("SRF.film("), "the montage is not copied into main.js")
        // the app builds, runs the harness and the player test, and the film plays
        let report = await BuildRunner.run(version: v, store: store, skill: try XCTUnwrap(Skill.root()))
        XCTAssertTrue(report.ok, report.steps.map { "\($0.title): \($0.level) \($0.detail)" }.joined(separator: "\n"))
        XCTAssertEqual(report.steps.map { $0.id }, ["build.make", "build.harness", "build.smoke"])
        let html = try String(contentsOf: Versions.distURL(store, v), encoding: .utf8)
        XCTAssertTrue(html.contains("\"film\":{") && html.contains("\"Push\"") && html.contains("G.SRT"), "film.json went into the page with the compositor")
        XCTAssertTrue(html.contains("\"name\":\"S02\""))
        // a model that forgets a scene is told by the build, not by a blank film
        try """
        (function () { window.SRF.fromData({ S01() {} }, {}); })();
        """.write(to: dir.appendingPathComponent("\(v)/main.js"), atomically: true, encoding: .utf8)
        let broken = await BuildRunner.run(version: v, store: store, skill: try XCTUnwrap(Skill.root()))
        XCTAssertFalse(broken.ok, "a scene without a module is a red result")
    }
}
