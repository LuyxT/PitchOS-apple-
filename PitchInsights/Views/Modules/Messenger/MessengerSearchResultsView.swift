import SwiftUI

struct MessengerSearchResultsView: View {
    let results: [MessengerSearchResult]
    let onSelect: (MessengerSearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Suche")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(results.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(results) { result in
                        Button {
                            onSelect(result)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: icon(for: result.type))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.primary)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(result.subtitle)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppTheme.surfaceAlt.opacity(0.5))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
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

    private func icon(for type: MessengerSearchResultType) -> String {
        switch type {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .message:
            return "text.bubble"
        case .analysisClip:
            return "film"
        case .analysisMarker:
            return "bookmark"
        }
    }
}

