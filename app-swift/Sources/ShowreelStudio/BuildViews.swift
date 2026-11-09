import AppKit
import ShowreelKit
import SwiftUI
import WebKit

/// Build and preview. The copilot writes the version folder (the one step that needs an AI); the app then builds it with the skill's
/// scripts, tests it, shows the result as green or red, and plays the reel. Outputs go to <project>/vN/dist.
struct BuildPanel: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ChecksPanel(block: "build")
            if !settings.hasKey {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "key").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Writing the film needs an AI").font(.callout.weight(.semibold))
                        Text("Connect one to build a new version. Everything else in the app stays usable, and you can still test and play a version that already exists.").fontSmall().foregroundStyle(.secondary)
                        Button("Connect AI") { AppSettingsWindow.open() }
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 10) {
                Button { project.startBuild(with: chat) } label: { Label(BuildJob.pending(project.store).map { "Continue \($0)" } ?? "Build a new version", systemImage: "hammer") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabledWithReason(Availability.startBuild(in: project.activity, hasKey: settings.hasKey, canBuild: BuildRunner.canBuild(project.store), clapRunning: chat.running).reasonText,
                                        way: Availability.startBuild(in: project.activity, hasKey: settings.hasKey, canBuild: BuildRunner.canBuild(project.store), clapRunning: chat.running).wayText)
                    .help("Clap writes \(Versions.next(project.store)) from your storyboard and decisions, then the app builds and tests it.")
            }
            BuildProgressPanel()
            if !project.layoutWarnings.isEmpty, project.activity.build == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text("\(project.layoutWarnings.count) scene\(project.layoutWarnings.count == 1 ? " has" : "s have") layout warnings").font(.callout.weight(.semibold))
                    Spacer()
                    Button("Show them") { project.showLayoutWarnings = true }
                }
                .padding(10).background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            if !BuildRunner.canBuild(project.store) {
                Text("The Go comes first: give it in the Scene editor once every visible scene is Ready.").fontSmall().foregroundStyle(.secondary)
            }
            if !project.versions.isEmpty { versionsRow }
            if let r = project.buildReport { report(r) }
            if let v = project.playVersion, Versions.hasDist(project.store, v) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Playing \(v)").font(.headline)
                    WebPreview(url: Versions.distURL(project.store, v), nonce: project.playNonce, onCreate: { _ in })
                        .frame(height: 440).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
                }
            }
        }
    }

    private var versionsRow: some View {
        HStack {
            Picker("Version", selection: Binding(get: { project.playVersion ?? project.film.playable ?? "" }, set: { project.playVersion = $0; project.playNonce += 1 })) {
                ForEach(project.versions.filter { Versions.hasDist(project.store, $0) }, id: \.self) { Text($0).tag($0) }
            }.frame(maxWidth: 200)
            Button("Test it again") { project.runChecks(project.playVersion ?? project.versions.last ?? "") }.disabledWithReason(project.buildBusy ? "A build is running" : nil, way: "Wait for the end, or Cancel the build")
                .help("Builds and tests this version again. Needs no AI.")
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.root.appendingPathComponent(project.playVersion ?? project.versions.last ?? "")]) }
            if let v = project.playVersion, Versions.hasDist(project.store, v) { Button("Open in the browser") { NSWorkspace.shared.open(Versions.distURL(project.store, v)) } }
        }
    }

    private func report(_ r: BuildReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(r.ok ? "\(r.version): built and tested" : "\(r.version): needs attention", systemImage: r.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.headline).foregroundStyle(r.ok ? Color.green : .red)
            ForEach(r.steps) { s in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: s.level.symbol).foregroundStyle(s.level.color).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.title).font(.callout.weight(.medium))
                        Text(s.detail).fontSmall().foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct BuildBlockView: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Build and preview").font(.title2.weight(.semibold))
                    Text("The film is built from your storyboard and decisions, tested, and played here.").font(.callout).foregroundStyle(.secondary)
                }
                if project.showreel == nil {
                    Text("This project has no data yet. Confirm the import or create it with the banner above.").foregroundStyle(.secondary)
                } else {
                    BuildPanel()
                }
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .panelBackground()
    }
}
