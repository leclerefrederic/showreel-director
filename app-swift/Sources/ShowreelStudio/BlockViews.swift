import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

/// The project's parameters, as a form: the questions of the interview's first round. Every change is a typed operation.
/// "Mark this block as validated": the gate of the block, set by the user.
struct ValidateButton: View {
    let gate: String
    let block: String
    @EnvironmentObject var project: ProjectModel

    private var passed: Bool { project.showreel?.gates[gate] == "passed" }

    var body: some View {
        Button {
            project.perform(.gate(gate, passed: !passed))
        } label: {
            Label(passed ? "Validated" : "Mark as validated", systemImage: passed ? "checkmark.circle.fill" : "checkmark.circle")
        }
        .buttonStyle(.bordered)
        .tint(passed ? .green : .accentColor)
        .help(passed ? "Click to reopen this block" : "Say you are done with this block")
    }
}
