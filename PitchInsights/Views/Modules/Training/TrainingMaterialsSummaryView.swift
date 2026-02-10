import SwiftUI

struct TrainingMaterialsSummaryView: View {
    let materials: [TrainingMaterialQuantity]
    let hints: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Material & Organisation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(materials.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if materials.isEmpty {
                Text("Kein Material hinterlegt")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(materials) { material in
                    HStack {
                        Text(material.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.black)
                        Spacer()
                        Text("\(material.quantity)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.surfaceAlt.opacity(0.45))
                    )
                }
            }

            Divider()

            Text("Aufbau-Hinweise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                Text("• \(hint)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}
