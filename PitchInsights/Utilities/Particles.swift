import SwiftUI

struct ParticleDustView: View {
    let intensity: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let count = max(6, Int(14 * intensity))
                for index in 0..<count {
                    let seed = Double(index) * 12.7
                    let baseX = (sin(seed) * 0.5 + 0.5) * size.width
                    let drift = sin(time * 0.2 + seed) * 12
                    let y = (cos(seed) * 0.5 + 0.5) * size.height
                    let radius = 2 + CGFloat((sin(seed + time * 0.4) + 1) * 1.5)
                    let opacity = 0.18 + (sin(time * 0.3 + seed) + 1) * 0.1
                    let rect = CGRect(x: baseX + drift, y: y, width: radius, height: radius)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ParticleBurstView: View {
    let trigger: Int
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = (timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) + Double(trigger))
                let progress = min(1, max(0, (t * 0.5).truncatingRemainder(dividingBy: 1)))
                let count = 14
                for index in 0..<count {
                    let angle = Double(index) / Double(count) * Double.pi * 2
                    let distance = CGFloat(18 + progress * 70)
                    let x = size.width / 2 + CGFloat(cos(angle)) * distance
                    let y = size.height / 2 + CGFloat(sin(angle)) * distance
                    let radius = CGFloat(2.5 - progress * 1.4)
                    let alpha = 0.5 - progress * 0.45
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
