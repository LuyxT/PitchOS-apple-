import SwiftUI
import Charts

struct CashDiagramView: View {
    let timeline: [CashTimelinePoint]
    let categoryBreakdown: [CashCategoryBreakdown]
    let granularity: CashTimelineGranularity

    private struct PieSliceData: Identifiable {
        let id: UUID
        let color: Color
        let startAngle: Double
        let endAngle: Double
    }

    var body: some View {
        HStack(spacing: 12) {
            timelineBarAndLine
            categoryPie
        }
    }

    private var timelineBarAndLine: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Einnahmen/Ausgaben + Kontostand")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if timeline.isEmpty {
                emptyTimelineState
            } else {
                Chart {
                    RuleMark(y: .value("Null", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(AppTheme.border.opacity(0.8))

                    ForEach(timelineSeriesPoints) { point in
                        BarMark(
                            x: .value("Zeitraum", point.label),
                            y: .value("Betrag", point.value)
                        )
                        .position(by: .value("Typ", point.series))
                        .foregroundStyle(by: .value("Typ", point.series))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }

                    ForEach(timeline) { point in
                        LineMark(
                            x: .value("Zeitraum", point.label),
                            y: .value("Kontostand", point.balance)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }

                    ForEach(timeline) { point in
                        PointMark(
                            x: .value("Zeitraum", point.label),
                            y: .value("Kontostand", point.balance)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(18)
                    }
                }
                .chartForegroundStyleScale([
                    "Einnahmen": LinearGradient(
                        colors: [AppTheme.primaryDark.opacity(0.94), AppTheme.primaryDark.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    "Ausgaben": LinearGradient(
                        colors: [Color.red.opacity(0.92), Color.red.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                ])
                .chartLegend(position: .top, alignment: .trailing, spacing: 10)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: xAxisMarkCount)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppTheme.border.opacity(0.65))
                        AxisTick(stroke: StrokeStyle(lineWidth: 0.8))
                            .foregroundStyle(AppTheme.border.opacity(0.8))
                        AxisValueLabel()
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppTheme.border.opacity(0.5))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(yAxisLabel(for: amount))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot
                        .background(AppTheme.surface.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(height: 220)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surfaceAlt.opacity(0.5))
        )
    }

    private var emptyTimelineState: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(AppTheme.surface.opacity(0.35))
            .frame(height: 220)
            .overlay {
                Text("Keine Daten im gewählten Zeitraum")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
    }

    private var categoryPie: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kategorien")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let radius = side * 0.44
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

                ZStack {
                    ForEach(pieSliceData) { slice in
                        PieSlice(startAngle: .degrees(slice.startAngle), endAngle: .degrees(slice.endAngle))
                            .fill(slice.color)
                            .overlay(
                                PieSlice(startAngle: .degrees(slice.startAngle), endAngle: .degrees(slice.endAngle))
                                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                            )
                            .frame(width: radius * 2, height: radius * 2)
                            .position(center)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(categoryBreakdown.prefix(5)) { row in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: row.colorHex))
                            .frame(width: 8, height: 8)
                        Text(row.categoryName)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(Int(row.ratio * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 260)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surfaceAlt.opacity(0.5))
        )
    }

    private var pieSliceData: [PieSliceData] {
        let total = max(categoryBreakdown.reduce(0.0) { $0 + $1.amount }, 1)
        var runningAngle = -90.0
        return categoryBreakdown.map { slice in
            let ratio = slice.amount / total
            let end = runningAngle + ratio * 360
            defer { runningAngle = end }
            return PieSliceData(
                id: slice.id,
                color: Color(hex: slice.colorHex),
                startAngle: runningAngle,
                endAngle: end
            )
        }
    }

    private var timelineSeriesPoints: [TimelineSeriesPoint] {
        timeline.flatMap { point in
            [
                TimelineSeriesPoint(label: point.label, series: "Einnahmen", value: point.income),
                TimelineSeriesPoint(label: point.label, series: "Ausgaben", value: -point.expense)
            ]
        }
    }

    private var xAxisMarkCount: Int {
        let count = timeline.count
        switch (granularity, count) {
        case (.daily, 0...14):
            return count
        case (.daily, 15...31):
            return 8
        case (.daily, _):
            return 10
        default:
            break
        }

        switch count {
        case 0...7:
            return count
        case 8...21:
            return 8
        default:
            return 10
        }
    }

    private func yAxisLabel(for value: Double) -> String {
        let absolute = abs(value)
        if absolute >= 1000 {
            let short = String(format: "%.1fk", absolute / 1000.0)
            return value < 0 ? "-\(short)" : short
        }
        let rounded = String(format: "%.0f", absolute)
        return value < 0 ? "-\(rounded)" : rounded
    }
}

private struct TimelineSeriesPoint: Identifiable {
    let id = UUID()
    let label: String
    let series: String
    let value: Double
}

private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
