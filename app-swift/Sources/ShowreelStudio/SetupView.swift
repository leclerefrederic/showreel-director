import SwiftUI

/// Shown at launch until the environment is complete (or the user chooses to continue without).
struct SetupView: View {
    @EnvironmentObject var env: EnvModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: env.checking ? "stethoscope" : "wrench.and.screwdriver")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(env.checking ? "Checking your setup..." : "A few things are missing")
                .font(.title2.weight(.semibold))
            Text("Showreel Studio needs these tools to build, test and export reels. Without Node, canvas and ffmpeg you can still make a short HTML reel without music, but nothing is tested automatically and there is no MP4 export.")
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(env.items) { row($0) }
            }
            .padding(14)
            .frame(maxWidth: 520, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            hints
            HStack(spacing: 10) {
                Button("Install missing") { env.install() }.buttonStyle(PrimaryButtonStyle())
                    .buttonStyle(PrimaryButtonStyle())
                    .disabledWithReason(env.installing ? "Installing\u{2026}" : env.checking ? "Checking\u{2026}" : env.passed ? "Nothing is missing" : nil)
                Button("Check again") { env.check() }.buttonStyle(SecondaryButtonStyle())
                    .disabledWithReason(env.installing ? "Installing\u{2026}" : env.checking ? "Checking\u{2026}" : nil)
                Button("Continue without (reduced mode)") { env.skipped = true }.buttonStyle(.borderless)
                    .buttonStyle(.link)
                    .disabledWithReason(env.installing ? "Installing\u{2026}" : env.isMissing("python3") ? "Python 3 is missing" : nil, way: env.isMissing("python3") ? "Without it no script runs: install it first, then check again" : nil) // without Python 3 no script runs: not a reduced mode
            }
            if env.installing { ProgressView("Installing... this can take a few minutes").controlSize(.small) }
            if !env.log.isEmpty {
                DisclosureGroup("Details") {
                    ScrollView {
                        Text(env.log)
                            .fontSmall(mono: true)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                }
                .frame(maxWidth: 520)
            }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panelBackground()
    }

    @ViewBuilder
    private var hints: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !env.scriptFound {
                hint("The setup script was not found in the app. Rebuild the app.")
            }
            if env.isMissing("python3") {
                hint("Python 3 comes with the Command Line Tools. In Terminal, run: xcode-select --install. Without it nothing can be built, so you cannot continue.")
            }
            if !env.brewAvailable && (env.isMissing("node") || env.isMissing("npm") || env.isMissing("ffmpeg")) {
                hint("Node.js and ffmpeg are installed with Homebrew (brew.sh). Install Homebrew first, then check again.")
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func hint(_ t: String) -> some View {
        Label(t, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
    }

    private func row(_ it: EnvItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if it.ok == nil { ProgressView().controlSize(.small) }
                else { Image(systemName: it.ok == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(it.ok == true ? Color.green : Color.red) }
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(it.label).font(.body.weight(.medium))
                Text(it.detail).fontSmall().foregroundStyle(.secondary)
            }
        }
    }
}
