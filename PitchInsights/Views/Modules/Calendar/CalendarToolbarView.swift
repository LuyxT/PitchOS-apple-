import SwiftUI

struct CalendarToolbarView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var viewModel: CalendarViewModel
    let onCreate: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedLayout
            compactLayout
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
    }

    private var expandedLayout: some View {
        HStack(spacing: 12) {
            todayButton
            navigationButtons

            Spacer(minLength: 8)

            rangeTitle

            Spacer(minLength: 8)

            viewModeControl
                .frame(width: 320)

            createButton
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                todayButton
                navigationButtons
                rangeTitle
                    .frame(maxWidth: .infinity, alignment: .leading)
                createButton
            }

            viewModeControl
                .frame(maxWidth: .infinity)
        }
    }

    private var todayButton: some View {
        Button("Heute") {
            viewModel.goToToday()
        }
        .buttonStyle(SecondaryActionButtonStyle())
    }

    private var navigationButtons: some View {
        HStack(spacing: 6) {
            Button {
                viewModel.goToPrevious()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                viewModel.goToNext()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var rangeTitle: some View {
        Text(viewModel.rangeTitle())
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var viewModeControl: some View {
        SegmentedControl(
            items: CalendarViewMode.allCases,
            selection: $viewModel.viewMode,
            title: { $0.rawValue }
        )
    }

    private var createButton: some View {
        Button {
            onCreate()
        } label: {
            if isCompactPhoneLayout {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
            } else {
                Label("Neuer Termin", systemImage: "plus")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .keyboardShortcut("n", modifiers: [.command])
        .buttonStyle(PrimaryActionButtonStyle())
    }

    private var isCompactPhoneLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }
}

#Preview {
    CalendarToolbarView(viewModel: CalendarViewModel(), onCreate: {})
        .frame(width: 900)
}
