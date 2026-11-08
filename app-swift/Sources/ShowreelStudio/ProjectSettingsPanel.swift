import ShowreelKit
import SwiftUI

/// The project's settings, in one panel opened from the top bar: the parameters of the project, and the global look. Each setting has exactly one
/// editor, here; the scenes override the look in their own inspector, and the Catalogue palette is only a source of drags. The application's own
/// settings (key, gateway, model, environment) are not here: they are in the application menu.
struct SettingsDock: View {
    @EnvironmentObject var project: ProjectModel
    @State private var live: Double?
    @State private var startWidth: Double?

    var body: some View {
        GeometryReader { geo in
            let room = max(PanelLayout.minSettings, geo.size.width - 360)
            let w = CGFloat(max(PanelLayout.minSettings, min(live ?? project.layout.settingsWidth, room)))
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                SplitHandle(vertical: true) { dx, ended in
                    if startWidth == nil { startWidth = Double(w) }
                    let v = max(PanelLayout.minSettings, min((startWidth ?? Double(w)) - Double(dx), Double(room)))
                    if ended {
                        var l = project.layout
                        l = PanelLayout(library: l.library, inspector: l.inspector, strip: l.strip, settings: v)
                        live = nil; startWidth = nil; project.setLayout(l)
                    } else { live = v }
                }
                ProjectSettingsPanel().frame(width: w)
            }
            .shadow(color: .black.opacity(0.2), radius: 10, x: -2)
        }
    }
}

struct ProjectSettingsPanel: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Project settings", systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Button { project.showProjectSettings = false } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless).help("Close")
            }
            .padding(.horizontal, 14).padding(.top, 12)
            Picker("", selection: $project.settingsTab) { ForEach(SettingsTab.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented).labelsHidden().padding(14)
            Divider()
            if project.showreel == nil {
                Text("This project has no data yet. Confirm the import or create it with the banner above.").foregroundStyle(.secondary).padding(16)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch project.settingsTab {
                        case .project: ProjectSettingsForm()
                        case .look: GlobalLookSettings()
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand { project.showProjectSettings = false }
    }
}

struct ProjectSettingsForm: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack { Spacer(); ValidateButton(gate: "interview", block: "inspector") }
        ProjectForm()
    }
}

/// The global look. Six rows (an icon, a name, the current choice at a glance); a click goes into that editor, with a way back, like the System Settings of
/// macOS. In an editor the current choice is pinned at the top and the library is below it. The editors and their typed operations are the guided path's own.
struct GlobalLookSettings: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        Group {
            if let section = project.lookSection {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button { project.lookSection = nil } label: { Label("Look", systemImage: "chevron.left") }.buttonStyle(.borderless)
                        Spacer()
                        Text(section.title).font(.headline)
                        Spacer()
                        ValidateButton(gate: "style", block: "inspector")
                    }
                    editor(section)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(LookSection.allCases) { s in LookRow(section: s) }
                    HStack { Spacer(); ValidateButton(gate: "style", block: "inspector") }.padding(.top, 6)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: project.lookSection)
    }

    @ViewBuilder private func editor(_ s: LookSection) -> some View {
        switch s {
        case .looks: LookBoardView()
        case .palette: PaletteEditor(compact: true)
        case .fonts: FontPickerView(roles: [.titleFont, .textFont])
        case .background: BackgroundPickerView()
        case .moods: MoodsPickerView()
        case .effects: EffectsPickerView()
        }
    }
}

/// One row of the list of look editors.
struct LookRow: View {
    let section: LookSection
    @EnvironmentObject var project: ProjectModel
    @State private var hovering = false

    var body: some View {
        let summary = project.showreel.map { section.summary($0) } ?? LookSection.Summary(text: "", swatches: [], isSet: false)
        Button { project.lookSection = section } label: {
            HStack(spacing: 12) {
                Image(systemName: section.symbol).font(.system(size: 15)).foregroundStyle(.white).frame(width: 30, height: 30)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(section.title).font(.callout.weight(.medium))
                Spacer(minLength: 8)
                if !summary.swatches.isEmpty { Swatches(colours: summary.swatches) }
                else { Text(summary.text).font(.callout).foregroundStyle(summary.isSet ? Color.primary : .secondary).lineLimit(1).truncationMode(.tail) }
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(hovering ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}
