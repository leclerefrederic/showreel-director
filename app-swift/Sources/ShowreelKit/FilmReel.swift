import Foundation

/// The layers of the Film strip from bottom to top (FL1). The music's grid is under the frames, so a beat line never crosses a scene; the playhead is the one line over a scene.
public enum StripLayer: Int, CaseIterable, Sendable {
    case background, grid, frames, transitionMarkers, musicMarkers, playhead
}

public enum StripLayerOrder {
    public static let bottomToTop = StripLayer.allCases
    /// The z-index a view takes: the layer's place in the order, so no view can reorder them.
    public static func z(_ l: StripLayer) -> Double { Double(l.rawValue) }
}

/// Where a thumbnail sits in the room it has: centred both ways, whole (aspect fit, never cropped or stretched). No picture yet: the 16:9 of a capture.
public enum ThumbnailFit {
    public static let defaultAspect = 16.0 / 9
    public static func rect(in area: CGRect, aspect: Double?) -> CGRect {
        let a = (aspect ?? 0) > 0 ? aspect! : defaultAspect
        guard area.width > 0, area.height > 0 else { return CGRect(x: area.midX, y: area.midY, width: 0, height: 0) }
        let w = min(area.width, area.height * a), h = w / a
        return CGRect(x: area.minX + (area.width - w) / 2, y: area.minY + (area.height - h) / 2, width: w, height: h)
    }
}

/// The film-reel frame of a scene: perforations in a band of their own above and below the content, and a cap at each cut. The sizes come from the tokens.
public struct ReelLayout: Equatable, Sendable {
    /// Height of each perforation band; 0 when the frame is too narrow or too short for perforations.
    public let band: Double
    public let perforations: [CGRect]           // top row, then bottom row
    public let capStart: CGRect
    public let capEnd: CGRect
    /// The room left for the frame's content (picture, label, status, duration), between the bands.
    public let content: CGRect
}

public enum ReelFrame {
    /// Under this width the perforations disappear and only the caps remain.
    public static let minWidth = 60.0
    /// A frame shorter than this has no room for two bands next to a picture.
    public static let minHeight = 40.0

    public static func perforationCount(width: Double, tokens t: DesignTokens.Strip = DesignTokens.graphite.strip) -> Int {
        guard width >= minWidth else { return 0 }
        return max(0, Int((width - 2 * t.capWidth - t.perforationPitch + t.perforationWidth) / t.perforationPitch))
    }

    public static func layout(width: Double, height: Double, tokens t: DesignTokens.Strip = DesignTokens.graphite.strip) -> ReelLayout {
        let n = perforationCount(width: width, tokens: t)
        let band = n > 0 && height >= minHeight ? t.reelBand : 0
        var rects: [CGRect] = []
        if band > 0 {
            let run = Double(n - 1) * t.perforationPitch + t.perforationWidth, x0 = (width - run) / 2
            for y in [(band - t.perforationHeight) / 2, height - band + (band - t.perforationHeight) / 2] {
                for i in 0..<n { rects.append(CGRect(x: x0 + Double(i) * t.perforationPitch, y: y, width: t.perforationWidth, height: t.perforationHeight)) }
            }
        }
        let cap = min(t.capWidth, width / 2)
        return ReelLayout(band: band, perforations: rects, capStart: CGRect(x: 0, y: 0, width: cap, height: height), capEnd: CGRect(x: width - cap, y: 0, width: cap, height: height),
                          content: CGRect(x: 0, y: band, width: width, height: max(1, height - 2 * band)))
    }
}
