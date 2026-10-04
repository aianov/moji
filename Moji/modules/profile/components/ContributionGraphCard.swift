import SwiftUI

struct ContributionGraphCard: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: ProfileServicesStore { .shared }
    private var interactions: ProfileInteractionsStore { .shared }

    var body: some View {
        let graph = service.graph()
        let years = service.years
        let selectedDay = service.selectedDay(in: graph)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activity")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                    Text(summaryText(graph))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.text.secondary)
                }

                Spacer(minLength: 0)

                YearStepper(
                    year: graph.year,
                    canGoBack: years.first.map { $0 < graph.year } ?? false,
                    canGoForward: years.last.map { $0 > graph.year } ?? false,
                    onShift: { interactions.shiftYear(by: $0) }
                )
            }

            ContributionGraphView(
                model: graph,
                selectedKey: service.selectedDayKey,
                onSelect: { interactions.selectDay($0) }
            )

            HStack(alignment: .center, spacing: 8) {
                Text(dayText(selectedDay))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selectedDay == nil ? theme.text.secondary.opacity(0.75) : theme.text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)

                Spacer(minLength: 0)

                ContributionLegend()
            }
            .animation(.easeInOut(duration: 0.2), value: service.selectedDayKey)
        }
        .profileCard()
    }

    private func summaryText(_ graph: ContributionGraphModel) -> String {
        let days = String(localized: "\(graph.practicedDays) days")
        let sessions = String(localized: "\(graph.sessions) sessions")
        let year = String(graph.year)
        return String(localized: "\(days) · \(sessions) in \(year)")
    }

    private func dayText(_ day: ContributionDay?) -> String {
        guard let day else { return String(localized: "Tap a day") }
        let date = day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        guard day.count > 0 else {
            return String(localized: "\(date) · rest day")
        }
        let sessions = String(localized: "\(day.count) sessions")
        return "\(date) · \(sessions)"
    }
}

private struct YearStepper: View {
    let year: Int
    let canGoBack: Bool
    let canGoForward: Bool
    let onShift: (Int) -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 6) {
            LiquidGlassButton(
                shape: .circle,
                size: 32,
                disabled: !canGoBack,
                accessibilityLabel: String(localized: "Previous year"),
                action: { onShift(-1) }
            ) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.text.primary)
            }

            Text(String(year))
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
                .contentTransition(.numericText(value: Double(year)))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: year)

            LiquidGlassButton(
                shape: .circle,
                size: 32,
                disabled: !canGoForward,
                accessibilityLabel: String(localized: "Next year"),
                action: { onShift(1) }
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.text.primary)
            }
        }
    }
}

struct ContributionGraphView: View {
    let model: ContributionGraphModel
    let selectedKey: String?
    let onSelect: (ContributionDay) -> Void

    static let cell: CGFloat = 12
    static let gap: CGFloat = 3
    private static let monthRowHeight: CGFloat = 14

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    private var gridWidth: CGFloat {
        CGFloat(model.weeks.count) * (Self.cell + Self.gap) - Self.gap
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .trailing, spacing: Self.gap) {
                Color.clear
                    .frame(height: Self.monthRowHeight)
                ForEach(0..<7, id: \.self) { row in
                    Text(row < model.weekdayLabels.count ? (model.weekdayLabels[row] ?? "") : "")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.text.secondary)
                        .frame(height: Self.cell)
                }
            }
            .fixedSize()

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: Self.gap) {
                        ZStack(alignment: .topLeading) {
                            ForEach(model.months) { month in
                                Text(month.title)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(theme.text.secondary)
                                    .fixedSize()
                                    .offset(x: CGFloat(month.weekIndex) * (Self.cell + Self.gap))
                            }
                        }
                        .frame(width: max(0, gridWidth), height: Self.monthRowHeight, alignment: .topLeading)

                        HStack(alignment: .top, spacing: Self.gap) {
                            ForEach(model.weeks) { week in
                                VStack(spacing: Self.gap) {
                                    ForEach(0..<7, id: \.self) { row in
                                        dayCell(row < week.days.count ? week.days[row] : nil)
                                    }
                                }
                                .id(week.index)
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    scroll(proxy)
                }
                .onChange(of: model.year) { _, _ in
                    scroll(proxy)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: ContributionDay?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)

        if let day {
            let isSelected = day.key == selectedKey

            shape
                .fill(MojiTint.contribution(level: day.level, appearance: theme.appearance))
                .opacity(day.isFuture ? 0.4 : 1)
                .overlay {
                    if isSelected {
                        shape.strokeBorder(MojiTint.gold, lineWidth: 1.5)
                    } else if day.isToday {
                        shape.strokeBorder(theme.text.primary.opacity(0.65), lineWidth: 1.2)
                    }
                }
                .frame(width: Self.cell, height: Self.cell)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(day)
                }
                .accessibilityElement()
                .accessibilityLabel(Text(day.key))
                .accessibilityValue(Text(String(localized: "\(day.count) sessions")))
                .accessibilityAddTraits(.isButton)
        } else {
            Color.clear
                .frame(width: Self.cell, height: Self.cell)
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        if let todayWeekIndex = model.todayWeekIndex {
            let target = min(model.weeks.count - 1, todayWeekIndex + 2)
            proxy.scrollTo(target, anchor: .trailing)
        } else if let first = model.weeks.first {
            proxy.scrollTo(first.index, anchor: .leading)
        }
    }
}

private struct ContributionLegend: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 3) {
            Text("Less")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .padding(.trailing, 2)
            ForEach(0..<4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(MojiTint.contribution(level: level, appearance: theme.appearance))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .padding(.leading, 2)
        }
        .accessibilityHidden(true)
    }
}
