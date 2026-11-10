import ShowreelKit
import SwiftUI

/// The film-reel marks of a scene's frame (FL1): perforations in the bands above and below, a cap at the start and at the end. Static, no hit-testing. Geometry is ShowreelKit's `ReelFrame`.
struct ReelFrameMarks: View {
    @EnvironmentObject var theme: Theme
    let layout: ReelLayout
    let selected: Bool

    var body: some View {
        Canvas { ctx, _ in
            for r in layout.perforations { ctx.fill(Path(roundedRect: r, cornerRadius: 1), with: .color(theme.strip.perforation)) }
            let cap: Color = selected ? .accentColor : theme.strip.cap
            ctx.fill(Path(layout.capStart), with: .color(cap)); ctx.fill(Path(layout.capEnd), with: .color(cap))
        }
        .allowsHitTesting(false)
    }
}
