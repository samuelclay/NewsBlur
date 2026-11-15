// DescribeTabView.swift: the Describe tab of Add + Discover Sites. A written description of the feeds you want is
// sent to /discover/describe/start, and DiscoverSitesViewModel polls /discover/describe/status while the pipeline
// in apps/describe/pipeline.py reads, searches, judges and hunts the web. Mirrors describe_feeds_view.js.
import SwiftUI

@available(iOS 15.0, *)
struct DescribeTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var composerFocused: Bool

    private var state: DescribeTabState { viewModel.describeState }
    private var trimmedPrompt: String { state.prompt.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                // DescribeTabView.swift keeps the history rail beside the search on iPad, like the web's left rail.
                HStack(alignment: .top, spacing: 16) {
                    DescribeHistoryView(viewModel: viewModel, layout: .rail)
                        .frame(width: 260)
                    VStack(alignment: .leading, spacing: 16) {
                        mainColumn
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    mainColumn
                }
                .padding(16)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DiscoverColors.background)
        .accessibilityIdentifier("discover-describe-tab")
        .onAppear {
            if !state.isHistoryLoaded { viewModel.loadDescribeHistory() }
        }
    }

    @ViewBuilder
    private var mainColumn: some View {
        if state.showsUpgrade {
            upgradeCard
        } else {
            composer
        }
        if horizontalSizeClass != .regular {
            DescribeHistoryView(viewModel: viewModel, layout: .strip)
        }
        if let search = state.search {
            DescribeStatusView(search: search, searchAgain: viewModel.searchDescribeAgain)
        }
        searchBody
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DiscoverColors.accent)
                    .padding(.top, 13)
                    .accessibilityHidden(true)
                DescribePromptField(text: $viewModel.describeState.prompt, isFocused: $composerFocused, onSubmit: submit)
            }
            .padding(.horizontal, 10)
            .background(DiscoverColors.textFieldBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverColors.border, lineWidth: 1))

            HStack(alignment: .top, spacing: 12) {
                Text(NBLocalization.text("NewsBlur reads your description, searches its index of feeds and the open web, then judges every match. It can take a minute."))
                    .font(.caption)
                    .foregroundColor(DiscoverColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: submit) {
                    Label(state.isStarting ? NBLocalization.text("Starting…") : NBLocalization.text("Find feeds"),
                          systemImage: "sparkles")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(DiscoverColors.accent)
                .disabled(state.isStarting || trimmedPrompt.isEmpty)
                .accessibilityIdentifier("discover-describe-submit")
            }

            if let usage = state.usage {
                Text(usage.label)
                    .font(.caption)
                    .foregroundColor(DiscoverColors.textSecondary)
                    .accessibilityIdentifier("discover-describe-usage")
            }
        }
    }

    private func submit() {
        guard !trimmedPrompt.isEmpty else {
            composerFocused = true
            return
        }
        composerFocused = false
        viewModel.startDescribeSearch(prompt: trimmedPrompt)
    }

    // MARK: - Body

    @ViewBuilder
    private var searchBody: some View {
        if state.showsUpgrade {
            EmptyView()
        } else if let message = state.errorMessage {
            DiscoverResultsStatusView(isLoading: false, isEmpty: false, error: message, isSearching: true) {
                if trimmedPrompt.isEmpty {
                    viewModel.startNewDescribeSearch()
                } else {
                    viewModel.startDescribeSearch(prompt: trimmedPrompt)
                }
            }
        } else if state.isOpening {
            ProgressView(NBLocalization.text("Loading your search…"))
                .font(.subheadline)
                .foregroundColor(DiscoverColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(24)
        } else if let search = state.search {
            resultsGrid(search)
        } else {
            emptyState
        }
    }

    private func resultsGrid(_ search: DescribeSearch) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], spacing: 12) {
            ForEach(search.results) { result in
                DiscoverFeedCardView(feed: result.feed, onTryFeed: onTryFeed, onAddFeed: onAddFeed,
                                     verdict: result, headlines: result.stories)
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    // DescribeTabView.swift opens the preview from anywhere on the card; its own buttons still win their taps.
                    .onTapGesture { onTryFeed?(result.feed) }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .accessibilityIdentifier("discover-describe-result-\(result.feedId)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("discover-describe-results")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NBLocalization.text("Try describing something like"))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DiscoverColors.textSecondary)
            ForEach(Array(DescribePhase.examplePrompts.enumerated()), id: \.offset) { index, example in
                Button { viewModel.useDescribeExample(example) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(DiscoverColors.accent)
                        Text(example)
                            .font(.subheadline)
                            .foregroundColor(DiscoverColors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(state.isStarting)
                .accessibilityIdentifier("discover-describe-example-\(index)")
            }
        }
        .padding(.top, 8)
        .accessibilityIdentifier("discover-describe-empty")
    }

    private var upgradeCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundColor(DiscoverColors.accent)
            Text(NBLocalization.text("Find feeds by describing them"))
                .font(.headline)
                .foregroundColor(DiscoverColors.textPrimary)
            Text(state.upgradeMessage
                 ?? NBLocalization.text("Describing the feeds you want is a premium feature. Upgrade to search by description."))
                .font(.subheadline)
                .foregroundColor(DiscoverColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                // DescribeTabView.swift opens the same premium sheet as the rest of the app (NewsBlurAppDelegate.m).
                NewsBlurAppDelegate.shared()?.showPremiumDialog()
            } label: {
                Text(NBLocalization.text("Upgrade to Premium"))
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DiscoverColors.accent)
            .accessibilityIdentifier("discover-describe-upgrade")
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1))
        .accessibilityIdentifier("discover-describe-upgrade-card")
    }
}

// DescribeTabView.swift: a multi-line prompt whose Return key starts the search, like Enter in the web textarea.
@available(iOS 15.0, *)
struct DescribePromptField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    static var placeholder: String {
        NBLocalization.text("Describe the feeds you’re looking for, like “reviews of new iOS apps with screenshots”")
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                TextField(Self.placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)
            } else {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(Self.placeholder)
                            .foregroundColor(DiscoverColors.textSecondary.opacity(0.7))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .frame(minHeight: 44, maxHeight: 120)
                }
            }
        }
        .font(.body)
        .foregroundColor(DiscoverColors.textPrimary)
        .focused(isFocused)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .accessibilityIdentifier("discover-describe-prompt")
        .onChange(of: text) { value in
            // DescribeTabView.swift treats a typed newline as submit on every iOS version.
            guard value.contains("\n") else { return }
            text = value.replacingOccurrences(of: "\n", with: " ")
            onSubmit()
        }
    }
}

// DescribeTabView.swift: the last 20 searches, as a horizontal strip on iPhone or a rail beside the search on iPad.
@available(iOS 15.0, *)
struct DescribeHistoryView: View {
    enum Layout {
        case strip
        case rail
    }

    @ObservedObject var viewModel: DiscoverSitesViewModel
    let layout: Layout

    private var state: DescribeTabState { viewModel.describeState }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NBLocalization.text("Your searches"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DiscoverColors.textPrimary)
                Spacer()
                if state.search != nil || !state.prompt.isEmpty {
                    Button(action: viewModel.startNewDescribeSearch) {
                        Label(NBLocalization.text("New"), systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .foregroundColor(DiscoverColors.accent)
                    .accessibilityIdentifier("discover-describe-new")
                }
            }
            if let message = state.historyErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(DiscoverColors.errorText)
            }
            if state.history.isEmpty {
                Text(state.isHistoryLoaded
                     ? NBLocalization.text("Searches you run will be kept here.") : NBLocalization.text("Loading…"))
                    .font(.caption)
                    .foregroundColor(DiscoverColors.textSecondary)
                    .accessibilityIdentifier("discover-describe-history-empty")
            } else if layout == .strip {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(state.history) { entry in
                            item(entry).frame(width: 220)
                        }
                    }
                }
                .accessibilityIdentifier("discover-describe-history")
            } else {
                VStack(spacing: 8) {
                    ForEach(state.history) { entry in
                        item(entry)
                    }
                }
                .accessibilityIdentifier("discover-describe-history")
            }
        }
    }

    private func item(_ entry: DescribeSearchSummary) -> some View {
        DescribeHistoryItemView(
            entry: entry,
            isActive: state.search?.id == entry.id,
            isDeleting: state.deletingSearchIDs.contains(entry.id),
            onOpen: { viewModel.openDescribeSearch(id: entry.id) },
            onDelete: { viewModel.deleteDescribeSearch(id: entry.id) }
        )
    }
}

@available(iOS 15.0, *)
struct DescribeHistoryItemView: View {
    let entry: DescribeSearchSummary
    let isActive: Bool
    let isDeleting: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.prompt)
                        .font(.subheadline)
                        .foregroundColor(DiscoverColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if entry.isRunning {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        }
                        Text(entry.metaLabel)
                        Text(entry.relativeDateLabel())
                    }
                    .font(.caption)
                    .foregroundColor(DiscoverColors.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.prompt)
            .accessibilityValue(entry.metaLabel)
            .accessibilityAddTraits(isActive ? .isSelected : [])
            .accessibilityIdentifier("discover-describe-history-\(entry.id)")
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DiscoverColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityLabel(NBLocalization.text("Remove from history"))
            .accessibilityIdentifier("discover-describe-history-delete-\(entry.id)")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(isActive ? DiscoverColors.accent : DiscoverColors.border.opacity(0.6), lineWidth: isActive ? 1.5 : 1))
        .opacity(isDeleting ? 0.4 : 1)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label(NBLocalization.text("Remove from history"), systemImage: "trash")
            }
        }
    }
}

// DescribeTabView.swift: the status line, phase stepper and Search again button (describe_feeds_view.js render_status).
@available(iOS 15.0, *)
struct DescribeStatusView: View {
    let search: DescribeSearch
    let searchAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                if search.isRunning {
                    ProgressView().scaleEffect(0.8).frame(width: 16, height: 20)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(search.statusMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(search.status == "error" ? DiscoverColors.errorText : DiscoverColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("discover-describe-status-message")
                    if search.isRunning && !search.results.isEmpty {
                        Text(NBLocalization.plural("%@ feeds so far", groupedCount: search.results.count))
                            .font(.caption)
                            .foregroundColor(DiscoverColors.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if search.isFinished {
                    Button(action: searchAgain) {
                        Label(NBLocalization.text("Search again"), systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(DiscoverColors.textSecondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityIdentifier("discover-describe-search-again")
                }
            }
            DescribePhaseStepperView(phase: search.phase, status: search.status)
            if !search.subQueries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text(NBLocalization.text("Searching for"))
                            .font(.caption)
                            .foregroundColor(DiscoverColors.textSecondary)
                        ForEach(search.subQueries, id: \.self) { query in
                            Text(query)
                                .font(.caption)
                                .foregroundColor(DiscoverColors.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DiscoverColors.subcategoryBackground, in: Capsule())
                        }
                    }
                }
                .accessibilityIdentifier("discover-describe-queries")
            }
            if let note = search.statsNote {
                Text(note)
                    .font(.caption)
                    .foregroundColor(DiscoverColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1))
        .accessibilityIdentifier("discover-describe-status")
    }
}

// DescribeTabView.swift: Reading → Searching feeds → Judging → Searching the web → Done, with the current phase highlighted.
@available(iOS 15.0, *)
struct DescribePhaseStepperView: View {
    let phase: String
    let status: String

    private var currentIndex: Int? {
        if status == "complete" { return DescribePhase.allCases.count - 1 }
        guard let phase = DescribePhase(rawValue: phase) else { return nil }
        return DescribePhase.allCases.firstIndex(of: phase)
    }

    var body: some View {
        let steps = DescribePhase.allCases
        let current = currentIndex
        let isRunning = status == "queued" || status == "running"
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let isDone = status == "complete" || (current.map { index < $0 } ?? false)
                let isCurrent = !isDone && isRunning && index == current
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(index == 0 ? Color.clear : lineColor(reached: isDone || isCurrent))
                            .frame(height: 2)
                        Circle()
                            .fill(dotColor(isDone: isDone, isCurrent: isCurrent))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(DiscoverColors.stepCurrent.opacity(isCurrent ? 0.35 : 0), lineWidth: 4))
                        Rectangle()
                            .fill(index == steps.count - 1 ? Color.clear : lineColor(reached: isDone))
                            .frame(height: 2)
                    }
                    Text(step.label)
                        .font(.caption2.weight(isCurrent ? .bold : .medium))
                        .foregroundColor(labelColor(isDone: isDone, isCurrent: isCurrent))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityValue(isDone ? NBLocalization.text("Done") : isCurrent ? NBLocalization.text("In progress") : "")
                .accessibilityIdentifier("discover-describe-step-\(step.rawValue)")
            }
        }
        .accessibilityIdentifier("discover-describe-steps")
    }

    private func lineColor(reached: Bool) -> Color {
        reached ? DiscoverColors.stepDone : DiscoverColors.stepUpcoming
    }

    private func dotColor(isDone: Bool, isCurrent: Bool) -> Color {
        if isDone { return DiscoverColors.stepDone }
        if isCurrent { return DiscoverColors.stepCurrent }
        return DiscoverColors.stepUpcoming
    }

    private func labelColor(isDone: Bool, isCurrent: Bool) -> Color {
        if isDone { return DiscoverColors.stepDone }
        if isCurrent { return DiscoverColors.stepCurrent }
        return DiscoverColors.textSecondary
    }
}
