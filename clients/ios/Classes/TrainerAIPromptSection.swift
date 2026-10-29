//
//  TrainerAIPromptSection.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-10-27.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

/// TrainerAIPromptSection.swift keeps the trainer's natural language classifier state: the prompt being written,
/// prompt tests, cost estimates and the billing banners. TrainerViewController.swift owns one model so the state
/// survives the TrainerView reload that follows every classifier save.
@MainActor final class TrainerAIPromptModel: ObservableObject {
    enum TestState: Equatable {
        case idle
        case testing
        case finished(PromptTestResult.Outcome)
    }

    @Published private(set) var drafts: [PromptClassifierKind: String] = [:]
    @Published private(set) var draftScores: [PromptClassifierKind: Int] = [:]
    @Published private(set) var tests: [PromptClassifierKind: TestState] = [:]
    @Published private(set) var estimate: AIClassifierCostEstimate?
    @Published private(set) var isLimitReached = false
    @Published var scopeOverrides: [String: ClassifierScope] = [:]

    private(set) var contextKey: String?

    let api: AIClassifierAPI
    var billingStatus: () -> UsageBillingStatus
    var storyVolumes: () -> AIClassifierStoryVolumes
    /// Saves through NewsBlurAppDelegate.m savePromptClassifier, like every other trainer classifier.
    var savePrompt: (_ prompt: String, _ kind: PromptClassifierKind, _ feedId: String, _ score: Int,
                     _ scope: ClassifierScope, _ folderName: String) -> Void
    var changeScope: (_ prompt: String, _ kind: PromptClassifierKind, _ feedId: String, _ score: Int,
                      _ oldScope: ClassifierScope, _ oldFolderName: String,
                      _ scope: ClassifierScope, _ folderName: String) -> Void
    var openBilling: () -> Void

    /// apps/analyzer/views.py ignores prompts longer than this.
    static let maximumPromptLength = 500

    init(api: AIClassifierAPI? = nil,
         billingStatus: (() -> UsageBillingStatus)? = nil,
         storyVolumes: (() -> AIClassifierStoryVolumes)? = nil,
         openBilling: (() -> Void)? = nil) {
        self.api = api ?? AIClassifierAPI()
        self.billingStatus = billingStatus ?? { UsageBillingStatus.current }
        self.storyVolumes = storyVolumes ?? { AIClassifierStoryVolumes.live(appDelegate: NewsBlurAppDelegate.shared) }
        self.openBilling = openBilling ?? { NewsBlurAppDelegate.shared?.showUsageBillingDialog() }
        savePrompt = { prompt, kind, feedId, score, scope, folderName in
            NewsBlurAppDelegate.shared?.savePromptClassifier(prompt, feedId: feedId, score: score,
                                                             includeImages: kind.includesImages,
                                                             scope: scope.rawValue, folderName: folderName)
        }
        changeScope = { prompt, kind, feedId, score, oldScope, oldFolderName, scope, folderName in
            NewsBlurAppDelegate.shared?.changeClassifierScope(kind.saveType, value: prompt, feedId: feedId, score: score,
                                                              oldScope: oldScope.rawValue, oldFolderName: oldFolderName,
                                                              scope: scope.rawValue, folderName: folderName)
        }
    }

    // MARK: Context

    /// Clears drafts and results when the trainer opens for another site or story, then loads cost estimates.
    func prepare(feedId: String?, storyHash: String?) {
        let key = "\(feedId ?? ""):\(storyHash ?? "")"
        guard key != contextKey else { return }
        contextKey = key
        drafts = [:]
        draftScores = [:]
        tests = [:]
        scopeOverrides = [:]
        estimate = nil
        isLimitReached = false

        // reader_classifier.js only asks for cost estimates when the reader can run AI classifiers.
        guard billingStatus().canUseAIClassifiers else { return }
        api.fetchUsage(feedId: feedId) { [weak self] usage in
            guard let self, self.contextKey == key, let usage, usage.canUseAI else { return }
            if let estimate = usage.estimate { self.estimate = estimate }
            self.isLimitReached = usage.isLimitReached
        }
    }

    // MARK: Drafts

    func draft(_ kind: PromptClassifierKind) -> String {
        drafts[kind] ?? ""
    }

    func trimmedDraft(_ kind: PromptClassifierKind) -> String {
        draft(kind).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A new prompt starts as a focus prompt, like the web's live preview pill.
    func draftScore(_ kind: PromptClassifierKind) -> Int {
        draftScores[kind] ?? 1
    }

    func setDraft(_ text: String, for kind: PromptClassifierKind) {
        let limited = String(text.prefix(Self.maximumPromptLength))
        guard limited != draft(kind) else { return }
        drafts[kind] = limited
        // reader_classifier.js clears a test result once the prompt changes.
        if tests[kind] != .testing { tests[kind] = .idle }
    }

    func toggleDraftDirection(_ kind: PromptClassifierKind) {
        draftScores[kind] = draftScore(kind) > 0 ? -1 : 1
        if tests[kind] != .testing { tests[kind] = .idle }
    }

    func addDraft(_ kind: PromptClassifierKind, feedId: String?) {
        let prompt = trimmedDraft(kind)
        guard !prompt.isEmpty, let feedId else { return }
        let score = draftScore(kind)
        drafts[kind] = ""
        draftScores[kind] = 1
        tests[kind] = .idle
        savePrompt(prompt, kind, feedId, score, .feed, "")
    }

    // MARK: Saved prompts

    func scope(for prompt: PromptClassifier) -> ClassifierScope {
        scopeOverrides[overrideKey(prompt)] ?? prompt.scope
    }

    func folderName(for prompt: PromptClassifier, currentFolderName: String) -> String {
        if let override = scopeOverrides[overrideKey(prompt)] {
            return override == .folder ? currentFolderName : ""
        }
        return prompt.scope == .folder ? prompt.folderName : ""
    }

    func scopeBinding(for prompt: PromptClassifier, currentFolderName: String) -> Binding<ClassifierScope> {
        Binding(get: { self.scope(for: prompt) }, set: { newScope in
            guard Self.hasDestination(newScope, folderName: currentFolderName) else { return }
            self.scopeOverrides[self.overrideKey(prompt)] = newScope
        })
    }

    /// apps/analyzer/views.py saves a folder prompt without a folder name as feed_id=0 and an empty folder_id, which
    /// is a global prompt that runs, and bills, on every site. So a site outside any folder can't scope to its folder.
    static func hasDestination(_ scope: ClassifierScope, folderName: String) -> Bool {
        scope != .folder || !folderName.isEmpty
    }

    func tap(_ prompt: PromptClassifier, feedId: String?, currentFolderName: String) {
        save(prompt, score: PromptClassifierSave.nextScore(afterTapping: prompt.score), feedId: feedId,
             currentFolderName: currentFolderName)
    }

    func tapDislike(_ prompt: PromptClassifier, feedId: String?, currentFolderName: String) {
        save(prompt, score: PromptClassifierSave.nextScore(afterTappingDislike: prompt.score), feedId: feedId,
             currentFolderName: currentFolderName)
    }

    func changeScope(_ prompt: PromptClassifier, to newScope: ClassifierScope, feedId: String?, currentFolderName: String) {
        let newFolderName = newScope == .folder ? currentFolderName : ""
        // NewsBlurAppDelegate.m changeClassifierScope removes the prompt before saving it again, so the new scope
        // is checked first and an invalid move leaves the original prompt where it was.
        guard Self.hasDestination(newScope, folderName: newFolderName) else { return }
        let oldScope = scope(for: prompt)
        let oldFolderName = folderName(for: prompt, currentFolderName: currentFolderName)
        scopeOverrides[overrideKey(prompt)] = newScope
        guard let feedId, prompt.score != 0 else { return }
        changeScope(prompt.prompt, prompt.kind, feedId, prompt.score, oldScope, oldFolderName, newScope, newFolderName)
    }

    private func save(_ prompt: PromptClassifier, score: Int, feedId: String?, currentFolderName: String) {
        let savedScope = scope(for: prompt)
        let savedFolderName = folderName(for: prompt, currentFolderName: currentFolderName)
        guard let feedId, Self.hasDestination(savedScope, folderName: savedFolderName) else { return }
        savePrompt(prompt.prompt, prompt.kind, feedId, score, savedScope, savedFolderName)
    }

    private func overrideKey(_ prompt: PromptClassifier) -> String {
        ClassifierScopeResolver.overrideKey(type: prompt.kind.saveType, name: prompt.prompt)
    }

    // MARK: Prompt tests

    func test(_ kind: PromptClassifierKind) -> TestState {
        tests[kind] ?? .idle
    }

    /// Runs one paid AI classification of the story against the draft prompt.
    func runTest(_ kind: PromptClassifierKind, storyHash: String?, feedId: String?) {
        let prompt = trimmedDraft(kind)
        guard !prompt.isEmpty, let storyHash, !storyHash.isEmpty, test(kind) != .testing else { return }
        tests[kind] = .testing
        let key = contextKey
        let classifierType = testClassifierType(kind)
        api.testPrompt(prompt, kind: kind, storyHash: storyHash, feedId: feedId ?? "0",
                       classifierType: classifierType) { [weak self] result in
            guard let self, self.contextKey == key else { return }
            if let estimate = result.costEstimate { self.estimate = estimate }
            // A newer draft or a flipped focus/hide direction replaces the result, matching reader_classifier.js
            // clearing it on input, since the result answered a different filter.
            guard self.trimmedDraft(kind) == prompt, self.testClassifierType(kind) == classifierType else {
                self.tests[kind] = .idle
                return
            }
            self.tests[kind] = .finished(result.outcome)
        }
    }

    /// The classifier_type apps/analyzer/views.py test_prompt_classifier scores the draft as.
    private func testClassifierType(_ kind: PromptClassifierKind) -> String {
        draftScore(kind) < 0 ? "hidden" : "focus"
    }

    /// The badge under the prompt field after a test, from reader_classifier.js.
    func testStatus(_ kind: PromptClassifierKind, imageCount: Int) -> (text: String, isMatch: Bool, isError: Bool)? {
        guard case .finished(let outcome) = test(kind) else { return nil }
        switch outcome {
        case .failed(let message):
            return (message ?? NBLocalization.text("Test failed"), false, true)
        case .classified(let matches, let imageMatches):
            if kind == .content {
                return matches
                    ? (NBLocalization.text("✓ Story matches this filter"), true, false)
                    : (NBLocalization.text("✗ Story does not match this filter"), false, false)
            }
            let total = max(imageCount, imageMatches.count)
            let matchCount = imageMatches.filter { $0 }.count
            if matchCount == 0 {
                return total == 1
                    ? (NBLocalization.text("✗ Image does not match this filter"), false, false)
                    : (NBLocalization.text("✗ No images match this filter"), false, false)
            } else if total == 1 {
                return (NBLocalization.text("✓ Image matches this filter"), true, false)
            }
            return (NBLocalization.plural("✓ %2$@ of %1$@ images match this filter", count: total,
                                          with: NBLocalization.formattedCount(matchCount)), true, false)
        }
    }

    /// Each image's match after an image test, or nil before one.
    func imageMatch(at index: Int) -> Bool? {
        guard case .finished(.classified(_, let imageMatches)) = test(.image), imageMatches.indices.contains(index) else {
            return nil
        }
        return imageMatches[index]
    }

    // MARK: Costs and banners

    func sectionCost(_ kind: PromptClassifierKind, saved: [PromptClassifier], feedId: String?,
                     currentFolderName: String) -> AIClassifierSectionCost? {
        guard let estimate else { return nil }
        let volumes = storyVolumes()
        var filters = saved.filter { $0.score != 0 }.map { prompt -> AIClassifierCostFilter in
            let scope = scope(for: prompt)
            let stories = volumes.stories(scope: scope, folderName: folderName(for: prompt, currentFolderName: currentFolderName),
                                          feedId: feedId)
            return AIClassifierCostFilter(scope: scope, storiesPerMonth: stories)
        }
        // reader_classifier.js counts the live preview pill too, so the estimate moves while typing.
        if !trimmedDraft(kind).isEmpty {
            filters.append(AIClassifierCostFilter(scope: .feed, storiesPerMonth: volumes.stories(scope: .feed, folderName: "", feedId: feedId)))
        }
        return AIClassifierCostFormatter.sectionCost(kind: kind, costPerRun: estimate.costPerRun(for: kind),
                                                     feedStoriesPerMonth: volumes.stories(scope: .feed, folderName: "", feedId: feedId),
                                                     filters: filters)
    }

    /// reader_classifier.js reminds a reader with prompts that they won't run without usage billing.
    func showsBillingBanner(_ kind: PromptClassifierKind, saved: [PromptClassifier]) -> Bool {
        guard !isLimitReached, !billingStatus().canUseAIClassifiers else { return false }
        return saved.contains { $0.score != 0 } || !trimmedDraft(kind).isEmpty
    }

    /// The cost row's billing button: managing an active plan, or setting one up. Self-hosted AI has none.
    var billingButtonTitle: String? {
        let status = billingStatus()
        if status.isUsageBilling { return NBLocalization.text("Manage billing and limits") }
        if status.isSelfHostedAI { return nil }
        return NBLocalization.text("Set up billing")
    }
}

// MARK: - Section view

/// TrainerAIPromptSection.swift draws the web's "Natural Language Text Classifier" and "Natural Language Image
/// Classifier" trainer sections (make_content_filter_section and make_image_filter_section in reader_classifier.js).
struct TrainerAIPromptSection: View {
    let kind: PromptClassifierKind
    @ObservedObject var model: TrainerAIPromptModel
    let feed: Feed?
    /// The story being trained, or nil in the site trainer, which has no prompt tests.
    let story: Story?
    let isPremiumArchive: Bool
    let currentFolderName: String
    let fontBuilder: (String, CGFloat) -> Font

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(explainer)
                .font(fontBuilder("WhitneySSm-Medium", 12))
                .foregroundColor(TrainerAIPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            if let cost = model.sectionCost(kind, saved: savedPrompts, feedId: feed?.id, currentFolderName: currentFolderName) {
                costRow(cost)
            }

            if kind == .image, !imageURLs.isEmpty {
                imageGrid
            }

            inputRow

            if let status = model.testStatus(kind, imageCount: imageURLs.count) {
                statusBadge(status.text, isMatch: status.isMatch, isError: status.isError)
            }

            draftCapsule

            if !savedPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(savedPrompts) { prompt in
                        savedCapsule(prompt)
                    }
                }
            }

            if model.isLimitReached {
                limitReachedBanner
            } else if model.showsBillingBanner(kind, saved: savedPrompts) {
                billingBanner
            }

            Spacer().frame(height: 4)
        }
    }

    // MARK: Data

    var savedPrompts: [PromptClassifier] {
        PromptClassifier.saved(in: feed?.classifiers, kind: kind)
    }

    var imageURLs: [URL] {
        guard let story else { return [] }
        let secure = story.dictionary["secure_image_urls"] as? [String: String] ?? [:]
        let addresses = story.dictionary["image_urls"] as? [String] ?? []
        return addresses.compactMap { address in
            let resolved = address.hasPrefix("http://") ? (secure[address] ?? address) : address
            return URL(string: resolved)
        }
    }

    var explainer: String {
        kind == .image
            ? NBLocalization.text("Describe what to look for and AI will analyze each story’s images against your prompt.")
            : NBLocalization.text("Describe a topic and AI will score each story against your prompt to focus or hide matches.")
    }

    var placeholder: String {
        kind == .image
            ? NBLocalization.text("e.g., \"food photography\" or \"charts and graphs\"")
            : NBLocalization.text("e.g., \"AI and machine learning\" or \"local politics\"")
    }

    // MARK: Cost row

    func costRow(_ cost: AIClassifierSectionCost) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    (Text(cost.monthly).font(.system(size: 15, weight: .semibold))
                        + Text(NBLocalization.text("/mo")).font(.system(size: 11)))
                    Text("\u{00B7}").foregroundColor(TrainerAIPalette.secondaryText)
                    (Text(cost.daily).font(.system(size: 13, weight: .medium))
                        + Text(NBLocalization.text("/day")).font(.system(size: 10)))
                }
                .foregroundColor(TrainerAIPalette.text)
                .fixedSize()

                Text(cost.breakdown)
                    .font(.system(size: 10))
                    .foregroundColor(TrainerAIPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let title = model.billingButtonTitle {
                Button(action: model.openBilling) {
                    Text(title)
                        .font(fontBuilder("WhitneySSm-Medium", 11))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(TrainerAIPalette.green))
                        .fixedSize()
                }
                .buttonStyle(BorderlessButtonStyle())
                .layoutPriority(1)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(TrainerAIPalette.costBackground))
    }

    // MARK: Images

    var imageGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    imageThumbnail(url, match: model.imageMatch(at: index))
                }
            }
            .padding(.vertical, 2)
        }
    }

    func imageThumbnail(_ url: URL, match: Bool?) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                TrainerAIPalette.costBackground
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(model.test(.image) == .testing ? 0.5 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(match == true ? TrainerAIPalette.green : Color.clear, lineWidth: 3)
        )
        .overlay(alignment: .bottom) {
            if let match {
                Text(match ? NBLocalization.text("Match") : NBLocalization.text("No match"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(match ? TrainerAIPalette.green : Color.black.opacity(0.55)))
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: Input

    var inputRow: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: Binding(get: { model.draft(kind) }, set: { model.setDraft($0, for: kind) }))
                .font(fontBuilder("WhitneySSm-Medium", 14))
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(TrainerAIPalette.fieldBackground)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(TrainerAIPalette.fieldBorder, lineWidth: 1))
                .disableAutocorrection(false)
                .submitLabel(.done)
                .focused($isFieldFocused)
                .onSubmit { model.addDraft(kind, feedId: feed?.id) }

            if hasTestButton {
                Button {
                    isFieldFocused = false
                    model.runTest(kind, storyHash: story?.hash, feedId: feed?.id)
                } label: {
                    Text(testButtonTitle)
                        .font(fontBuilder("WhitneySSm-Medium", 12))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(TrainerAIPalette.green))
                        .opacity(isTestEnabled ? 1 : 0.45)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(!isTestEnabled)
                .accessibilityIdentifier("trainer-ai-test-\(kind.rawValue)")
            }
        }
    }

    var hasTestButton: Bool {
        guard story != nil else { return false }
        return kind == .content || !imageURLs.isEmpty
    }

    var isTestEnabled: Bool {
        !model.trimmedDraft(kind).isEmpty && model.test(kind) != .testing
    }

    var testButtonTitle: String {
        let testing = model.test(kind) == .testing
        if kind == .content {
            return testing ? NBLocalization.text("Testing on this story...") : NBLocalization.text("Test on this story")
        }
        if testing { return NBLocalization.text("Analyzing images...") }
        return imageURLs.count == 1 ? NBLocalization.text("Test on this image") : NBLocalization.text("Test on these images")
    }

    func statusBadge(_ text: String, isMatch: Bool, isError: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isError ? TrainerAIPalette.errorText : isMatch ? TrainerAIPalette.matchText : TrainerAIPalette.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(isError ? TrainerAIPalette.errorBackground : isMatch ? TrainerAIPalette.matchBackground : TrainerAIPalette.costBackground))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Capsules

    /// The live preview: tap it to add the prompt, or flip it between focus and hide first.
    @ViewBuilder
    var draftCapsule: some View {
        let text = model.trimmedDraft(kind)
        if text.isEmpty {
            TrainerPromptCapsule(kind: kind, text: NBLocalization.text("Describe what to focus or hide"), score: 0,
                                 isPlaceholder: true)
        } else {
            Button {
                isFieldFocused = false
                model.addDraft(kind, feedId: feed?.id)
            } label: {
                TrainerPromptCapsule(kind: kind, text: text, score: model.draftScore(kind), isDraft: true,
                                     onDislike: { model.toggleDraftDirection(kind) })
            }
            .buttonStyle(BorderlessButtonStyle())
            .accessibilityIdentifier("trainer-ai-draft-\(kind.rawValue)")
        }
    }

    func savedCapsule(_ prompt: PromptClassifier) -> some View {
        Button {
            model.tap(prompt, feedId: feed?.id, currentFolderName: currentFolderName)
        } label: {
            TrainerPromptCapsule(kind: kind, text: prompt.prompt, score: prompt.score, showsScope: true,
                                 scope: model.scopeBinding(for: prompt, currentFolderName: currentFolderName),
                                 isPremiumArchive: isPremiumArchive,
                                 isFolderAvailable: TrainerAIPromptModel.hasDestination(.folder, folderName: currentFolderName),
                                 onScopeChanged: { newScope in
                                     model.changeScope(prompt, to: newScope, feedId: feed?.id, currentFolderName: currentFolderName)
                                 },
                                 onDislike: { model.tapDislike(prompt, feedId: feed?.id, currentFolderName: currentFolderName) })
        }
        .buttonStyle(BorderlessButtonStyle())
    }

    // MARK: Banners

    /// "AI filters are saved but won't run until you set up usage-based billing." from reader_classifier.js,
    /// translated whole with the link phrase placed wherever the language puts it.
    var billingBanner: some View {
        Button(action: model.openBilling) {
            Text(billingBannerText)
                .font(fontBuilder("WhitneySSm-Medium", 12))
                .foregroundColor(TrainerAIPalette.bannerText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(TrainerAIPalette.bannerBackground))
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityIdentifier("trainer-ai-billing-banner")
    }

    var billingBannerText: AttributedString {
        let marker = "\u{E002}"
        var text = AttributedString(String(format: NBLocalization.text("AI filters are saved but won't run until you %@."), marker))
        text.font = .system(size: 12, weight: .bold)
        if let range = text.range(of: marker) {
            var link = AttributedString(NBLocalization.text("set up usage-based billing"))
            link.font = .system(size: 12, weight: .bold)
            link.underlineStyle = .single
            link.foregroundColor = TrainerAIPalette.bannerLink
            text.replaceSubrange(range, with: link)
        }
        return text
    }

    var limitReachedBanner: some View {
        Button(action: model.openBilling) {
            (Text(NBLocalization.text("Monthly spending limit reached. ")).bold()
                + Text(NBLocalization.text("Natural language classifiers are paused until next billing cycle. "))
                + Text(NBLocalization.text("Increase or remove your limit")).underline().foregroundColor(TrainerAIPalette.bannerLink))
                .font(fontBuilder("WhitneySSm-Medium", 12))
                .foregroundColor(TrainerAIPalette.limitText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(TrainerAIPalette.limitBackground))
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityIdentifier("trainer-ai-limit-banner")
    }
}

/// TrainerAIPromptSection.swift's section header, with the web's AI and vision icons.
struct TrainerAIPromptHeader: View {
    let kind: PromptClassifierKind
    let font: Font
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: kind == .image ? "eye" : "text.bubble")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(TrainerAIPalette.accent)
            Text(kind == .image ? NBLocalization.text("Natural Language Image Classifier")
                                : NBLocalization.text("Natural Language Text Classifier"))
                .font(font)
                .foregroundColor(color)
        }
    }
}

// MARK: - Prompt capsule

/// A natural language prompt in the trainer: like (focus) or dislike (hidden), with the scope toggles of the other
/// classifier capsules in TrainerCapsule.swift. Prompts wrap instead of growing past the trainer's width.
struct TrainerPromptCapsule: View {
    let kind: PromptClassifierKind
    let text: String
    let score: Int
    var isPlaceholder = false
    var isDraft = false
    var showsScope = false
    @Binding var scope: ClassifierScope
    var isPremiumArchive = false
    var isFolderAvailable = true
    var onScopeChanged: ((ClassifierScope) -> Void)?
    var onDislike: (() -> Void)?

    init(kind: PromptClassifierKind, text: String, score: Int, isPlaceholder: Bool = false, isDraft: Bool = false,
         showsScope: Bool = false, scope: Binding<ClassifierScope> = .constant(.feed), isPremiumArchive: Bool = false,
         isFolderAvailable: Bool = true, onScopeChanged: ((ClassifierScope) -> Void)? = nil,
         onDislike: (() -> Void)? = nil) {
        self.kind = kind
        self.text = text
        self.score = score
        self.isPlaceholder = isPlaceholder
        self.isDraft = isDraft
        self.showsScope = showsScope
        self._scope = scope
        self.isPremiumArchive = isPremiumArchive
        self.isFolderAvailable = isFolderAvailable
        self.onScopeChanged = onScopeChanged
        self.onDislike = onDislike
    }

    var classifierScore: Feed.Score {
        score > 0 ? .like : score < 0 ? .dislike : .none
    }

    var isActive: Bool { score != 0 }

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: classifierScore.imageName)
                    .foregroundColor(isActive ? .white : TrainerAIPalette.neutralIcon)

                if showsScope {
                    ScopeToggleView(classifierType: kindLabel, activeScope: $scope, score: classifierScore,
                                    isPremiumArchive: isPremiumArchive, onScopeChanged: onScopeChanged,
                                    isFolderAvailable: isFolderAvailable)
                }

                Text(kindLabel.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.3)
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(isActive ? Color.white.opacity(0.25) : TrainerAIPalette.accent)
                    .cornerRadius(3)
                    .fixedSize()

                Text(text)
                    .font(.system(size: 13))
                    .italic(isPlaceholder)
                    .foregroundColor(isActive ? .white : isPlaceholder ? TrainerAIPalette.secondaryText : TrainerAIPalette.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.leading, 10)
            .padding(.trailing, onDislike != nil ? 6 : 12)

            if let onDislike {
                Rectangle()
                    .fill(isActive ? Color.white.opacity(0.25) : TrainerAIPalette.divider)
                    .frame(width: 1, height: 18)

                Button(action: onDislike) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(score < 0 ? .white : isActive ? .white.opacity(0.5) : TrainerAIPalette.dislikeIcon)
                        .frame(width: 30, height: 26)
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.trailing, 4)
            }
        }
        .background(RoundedRectangle(cornerRadius: 15).fill(background))
        .overlay {
            if isDraft || isPlaceholder {
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundColor(isActive ? Color.white.opacity(0.6) : TrainerAIPalette.accent.opacity(0.6))
            }
        }
    }

    var kindLabel: String {
        kind == .image ? NBLocalization.text("Image") : NBLocalization.text("Content")
    }

    var background: Color {
        if score > 0 { return Color(red: 0, green: 0.5, blue: 0) }
        if score < 0 { return Color.red }
        return Color.themed([0xD8D8D8, 0xD0C4B4, 0x595959, 0x595959])
    }
}

// MARK: - Colors

/// TrainerAIPromptSection.swift's colors for the Light, Sepia, Medium and Dark themes.
enum TrainerAIPalette {
    static var text: Color { Color.themed([0x1C1C1E, 0x3C3226, 0xF2F2F7, 0xF2F2F7]) }
    static var secondaryText: Color { Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D]) }
    static var accent: Color { Color(red: 0.353, green: 0.420, blue: 0.851) } // #5A6BD9
    static var green: Color { Color.themed([0x5F9B4C, 0x5F9B4C, 0x4E8A3E, 0x4E8A3E]) }
    static var neutralIcon: Color { Color.themed([0x777777, 0x8B7B6B, 0xBBBBBB, 0xBBBBBB]) }
    static var dislikeIcon: Color { Color.themed([0xA90103, 0xA90103, 0xE87272, 0xE87272]) }
    static var divider: Color { Color.themed([0xBBBBBB, 0xB0A090, 0x777777, 0x777777]) }
    static var fieldBackground: Color { Color.themed([0xFFFFFF, 0xFFFBF5, 0x2C2C2E, 0x1C1C1E]) }
    static var fieldBorder: Color { Color.themed([0xC7C7CC, 0xD4C8B8, 0x555555, 0x444444]) }
    static var costBackground: Color { Color.themed([0xF2F4EF, 0xF3E9DA, 0x2C2C2E, 0x1C1C1E]) }
    static var matchText: Color { Color.themed([0x2E7D32, 0x2E7D32, 0x9DE58D, 0x9DE58D]) }
    static var matchBackground: Color { Color.themed([0xE8F5E9, 0xE6EFD9, 0x29442B, 0x1F3A21]) }
    static var errorText: Color { Color.themed([0xC62828, 0xB0352B, 0xFFA3A5, 0xFFA3A5]) }
    static var errorBackground: Color { Color.themed([0xFFEBEE, 0xF8E1DA, 0x512D31, 0x3E2226]) }
    static var bannerText: Color { Color.themed([0x5D4A1F, 0x5D4A1F, 0xF0DDA8, 0xF0DDA8]) }
    static var bannerBackground: Color { Color.themed([0xFFF4D6, 0xF7E6C4, 0x4A3F22, 0x3A3119]) }
    static var bannerLink: Color { Color.themed([0x2F6FB3, 0x8A5A1E, 0x8CC4FF, 0x8CC4FF]) }
    static var limitText: Color { Color.themed([0x8A1F1F, 0x8A1F1F, 0xFFC2C2, 0xFFC2C2]) }
    static var limitBackground: Color { Color.themed([0xFDE7E7, 0xF6DCD3, 0x4F2A2A, 0x3D2020]) }
}
