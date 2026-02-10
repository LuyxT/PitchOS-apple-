import CoreGraphics

struct WindowLayoutSpec {
    let minimumSize: CGSize
    let preferredSize: CGSize
}

enum WindowSizing {
    static func spec(for module: Module) -> WindowLayoutSpec {
        switch module {
        case .trainerProfil:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1120, height: 760), preferredSize: CGSize(width: 1260, height: 820))
        case .kader:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1080, height: 700), preferredSize: CGSize(width: 1240, height: 820))
        case .kalender:
            return WindowLayoutSpec(minimumSize: CGSize(width: 980, height: 660), preferredSize: CGSize(width: 1200, height: 820))
        case .trainingsplanung:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1220, height: 760), preferredSize: CGSize(width: 1420, height: 900))
        case .spielanalyse:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1260, height: 780), preferredSize: CGSize(width: 1460, height: 920))
        case .taktiktafel:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1180, height: 760), preferredSize: CGSize(width: 1380, height: 900))
        case .messenger:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1180, height: 740), preferredSize: CGSize(width: 1380, height: 900))
        case .dateien:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1240, height: 760), preferredSize: CGSize(width: 1460, height: 920))
        case .verwaltung:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1220, height: 760), preferredSize: CGSize(width: 1440, height: 900))
        case .mannschaftskasse:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1220, height: 760), preferredSize: CGSize(width: 1440, height: 900))
        case .einstellungen:
            return WindowLayoutSpec(minimumSize: CGSize(width: 1120, height: 760), preferredSize: CGSize(width: 1320, height: 860))
        }
    }

    static func spec(for kind: FloatingWindowKind) -> WindowLayoutSpec {
        switch kind {
        case .module(let module):
            return spec(for: module)
        case .folder:
            return WindowLayoutSpec(minimumSize: CGSize(width: 620, height: 420), preferredSize: CGSize(width: 860, height: 620))
        case .playerProfile:
            return WindowLayoutSpec(minimumSize: CGSize(width: 840, height: 620), preferredSize: CGSize(width: 980, height: 760))
        }
    }

    static func defaultSize(for kind: FloatingWindowKind, workspace: CGSize) -> CGSize {
        let layout = spec(for: kind)
        let safeWorkspace = CGSize(
            width: max(0, workspace.width),
            height: max(0, workspace.height)
        )

        guard safeWorkspace.width > 0, safeWorkspace.height > 0 else {
            return layout.preferredSize
        }

        let width = max(layout.minimumSize.width, min(layout.preferredSize.width, safeWorkspace.width * 0.84))
        let height = max(layout.minimumSize.height, min(layout.preferredSize.height, safeWorkspace.height * 0.86))
        return CGSize(width: width, height: height)
    }

    static func clampedSize(_ size: CGSize, for kind: FloatingWindowKind) -> CGSize {
        let minimum = spec(for: kind).minimumSize
        return CGSize(
            width: max(minimum.width, size.width),
            height: max(minimum.height, size.height)
        )
    }

    static func clampedOrigin(origin: CGPoint, size: CGSize, workspace: CGSize) -> CGPoint {
        guard workspace.width > 0, workspace.height > 0 else { return origin }

        let margin: CGFloat = 12
        let maxX = max(margin, workspace.width - size.width - margin)
        let maxY = max(margin, workspace.height - size.height - margin)

        return CGPoint(
            x: min(max(origin.x, margin), maxX),
            y: min(max(origin.y, margin), maxY)
        )
    }
}

