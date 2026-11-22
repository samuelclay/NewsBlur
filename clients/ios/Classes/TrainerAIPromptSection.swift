//
//  TrainerAIPromptSection.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-10-27.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

/// TrainerAIPromptSection.swift keeps the trainer's natural language classifier state: the prompt being written,
/// prompt tests, which kind of filter the AI filter card writes, and the reader's AI credits with estimates for this site. TrainerViewController.swift owns one model
/// so the state survives the TrainerView reload that follows every classifier save.
@MainActor final class TrainerAIPromptModel: ObservableObject {
    enum TestState: Equatable {
        case idle
        case testing
        case finished(PromptTestResult.Outcome)
    }

    @Published private(set) var drafts: [PromptClassifierKind: String] = [:]
    @Published private(set) var draftScores: [PromptClassifierKind: Int] = [:]
    @Published private(set) var tests: [PromptClassifierKind: TestState] = [:]
    @Published var scopeOverrides: [String: ClassifierScope] = [:]
    /// What the AI filter card's input reads: text or images (TrainerAIFilterHeader's switch).
    @Published var mode: PromptClassifierKind = .content
    /// /analyzer/ai_classifier_usage for the site being trained, loaded every time the trainer opens.
    @Published private(set) var usage: AIClassifierUsage?

    /// The site or story being trained, and the account and server it's trained on. Drafts, test results and scope
    /// overrides belong to one context, so another account's trainer for the same site never shows them.
    struct Context: Equatable {
        let account: String
        let host: String
        let feedId: String
        let storyHash: String
    }

    private(set) var context: Context?
    /// Moves on with every new context and every account change, so a usage fetch or prompt test answered for an
    /// earlier one is dropped, even once the reader is back on the same site and story.
    private var contextGeneration = 0
    /// The context generation a usage fetch is out for. Opening the trainer prepares it more than once, and those
    /// calls share the fetch already out.
    private var usageFetchGeneration: Int?

    let api: AIClassifierAPI
    /// The signed in account's user_profile from /reader/feeds.
    var userProfile: () -> [AnyHashable: Any]?
    /// Keeps fresh credits in the profile (AIClassifiers.swift AICreditsStore), so the AI credits screen and the
    /// settings menu agree with the trainer.
    var storeCredits: ([String: Any]) -> Void
    /// The signed in account and the server it's on.
    var signedInAccount: () -> (username: String, host: String)
    /// Saves through NewsBlurAppDelegate.m savePromptClassifier, like every other trainer classifier.
    var savePrompt: (_ prompt: String, _ kind: PromptClassifierKind, _ feedId: String, _ score: Int,
                     _ scope: ClassifierScope, _ folderName: String) -> Void
    var changeScope: (_ prompt: String, _ kind: PromptClassifierKind, _ feedId: String, _ score: Int,
                      _ oldScope: ClassifierScope, _ oldFolderName: String,
                      _ scope: ClassifierScope, _ folderName: String) -> Void
    /// Opens PremiumView.swift through NewsBlurAppDelegate.m showPremiumDialog.
    var openUpgrade: () -> Void
    /// Opens AICreditsView.swift through NewsBlurAppDelegate.m showAICreditsDialogStartingSetup, going straight on
    /// to Stripe checkout when startingSetup is set.
    var openCredits: (_ startingSetup: Bool) -> Void

    /// apps/analyzer/views.py ignores prompts longer than this.
    static let maximumPromptLength = 500

    init(api: AIClassifierAPI? = nil,
         userProfile: (() -> [AnyHashable: Any]?)? = nil,
         storeCredits: (([String: Any]) -> Void)? = nil,
         openUpgrade: (() -> Void)? = nil,
         openCredits: ((Bool) -> Void)? = nil,
         signedInAccount: (() -> (username: String, host: String))? = nil) {
        self.api = api ?? AIClassifierAPI()
        self.userProfile = userProfile ?? { NewsBlurAppDelegate.shared?.dictUserProfile as? [AnyHashable: Any] }
        self.storeCredits = storeCredits ?? { AICreditsStore.save($0) }
        self.signedInAccount = signedInAccount ?? {
            (NewsBlurAppDelegate.shared?.activeUsername ?? "", NewsBlurAppDelegate.shared?.url ?? "")
        }
        self.openUpgrade = openUpgrade ?? { NewsBlurAppDelegate.shared?.showPremiumDialog() }
        self.openCredits = openCredits ?? { NewsBlurAppDelegate.shared?.showAICreditsDialogStartingSetup($0) }
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

    /// Clears drafts and results when the trainer opens for another site or story, or for another account, and loads
    /// the reader's credits again every time, so the meter never stays as an earlier visit left it.
    func prepare(feedId: String?, storyHash: String?) {
        let account = signedInAccount()
        let context = Context(account: account.username, host: account.host, feedId: feedId ?? "",
                              storyHash: storyHash ?? "")
        if context != self.context {
            start(context)
        }
        fetchUsage(feedId: feedId)
    }

    /// TrainerViewController.swift clears the trainer when the reader signs in to another account.
    func resetForAccountChange() {
        start(nil)
    }

    private func start(_ context: Context?) {
        self.context = context
        contextGeneration += 1
        usageFetchGeneration = nil
        drafts = [:]
        draftScores = [:]
        tests = [:]
        scopeOverrides = [:]
        usage = nil
        mode = .content
    }

    private func fetchUsage(feedId: String?) {
        // A server that counts no credits has nothing for the trainer to show.
        guard credits?.isUnlimited != true, usageFetchGeneration != contextGeneration else { return }
        let generation = contextGeneration
        usageFetchGeneration = generation
        api.fetchUsage(feedId: feedId) { [weak self] usage in
            guard let self, self.contextGeneration == generation else { return }
            self.usageFetchGeneration = nil
            guard let usage else { return }
            self.usage = usage
            if let json = usage.creditsJSON, usage.credits != nil { self.storeCredits(json) }
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
    /// is a global prompt that runs on every site. So a site outside any folder can't scope to its folder.
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

    /// Runs one AI classification of the story against the draft prompt, on any account.
    func runTest(_ kind: PromptClassifierKind, storyHash: String?, feedId: String?) {
        let prompt = trimmedDraft(kind)
        guard !prompt.isEmpty, let storyHash, !storyHash.isEmpty, test(kind) != .testing else { return }
        tests[kind] = .testing
        let generation = contextGeneration
        let classifierType = testClassifierType(kind)
        api.testPrompt(prompt, kind: kind, storyHash: storyHash, feedId: feedId ?? "0",
                       classifierType: classifierType) { [weak self] result in
            guard let self, self.contextGeneration == generation else { return }
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

    // MARK: AI credits

    /// This moment's credits from the usage fetch, or the profile's until it answers.
    var credits: AICredits? {
        usage?.credits ?? AICredits(profile: userProfile())
    }

    /// The credits row at the bottom of the AI filter card: the month's meter and what it means, for plans with credits.
    /// A server that counts no credits shows nothing.
    var creditsNotice: AICreditsNotice? {
        guard let credits, credits.status != .free else { return nil }
        return AICreditsNotice.make(credits, offersBilling: UsageBillingFeature.isEnabled)
    }

    /// A plan without credits is told so, with a way to upgrade, once it has an AI filter saved or is writing one,
    /// since those won't score stories. Every account can still write, save and test filters.
    func freeNotice(saved: [PromptClassifier]) -> AICreditsNotice? {
        guard let credits, credits.status == .free else { return nil }
        let hasFilter = saved.contains { $0.score != 0 } || PromptClassifierKind.allCases.contains { !trimmedDraft($0).isEmpty }
        guard hasFilter else { return nil }
        return AICreditsNotice.make(credits, offersBilling: UsageBillingFeature.isEnabled)
    }

    /// About what a filter of this kind on this site spends a month, while the reader's filters run. A blurblog or
    /// river has no site of its own to estimate.
    func estimateText(_ kind: PromptClassifierKind) -> String? {
        guard let usage, let credits, [.running, .warning, .usageBilling].contains(credits.status),
              (Int(context?.feedId ?? "") ?? 0) > 0 else { return nil }
        return AIClassifierUsage.estimateText(usage.creditsPerMonth(for: kind), kind: kind)
    }

    func perform(_ action: AICreditsNotice.Action) {
        switch action {
        case .upgrade: openUpgrade()
        case .setUpBilling: openCredits(true)
        case .manageBilling, .openCredits: openCredits(false)
        }
    }
}

// MARK: - AI filter card

/// TrainerAIPromptSection.swift draws the trainer's one AI filter card: the filter being written, read as text or as
/// images by the header's switch (TrainerAIFilterHeader), every AI filter saved on the site whatever the switch
/// says, and the month's credits. It replaced separate text and image classifier sections.
struct TrainerAIFilterCard: View {
    @ObservedObject var model: TrainerAIPromptModel
    let feed: Feed?
    /// The story being trained, or nil in the site trainer, which has no prompt tests.
    let story: Story?
    let isPremiumArchive: Bool
    let currentFolderName: String
    let fontBuilder: (String, CGFloat) -> Font

    @FocusState private var isFieldFocused: Bool

    /// What the filter being written reads. Each mode keeps its own draft, so a filter saves as the kind it was
    /// typed in.
    var kind: PromptClassifierKind { model.mode }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind == .image, !imageURLs.isEmpty {
                imageGrid
            }

            inputRow

            if let status = model.testStatus(kind, imageCount: imageURLs.count) {
                statusBadge(status.text, isMatch: status.isMatch, isError: status.isError)
            }

            if !model.trimmedDraft(kind).isEmpty {
                draftCapsule
            }

            if let free = model.freeNotice(saved: savedPrompts) {
                TrainerAIFreeBanner(notice: free, fontBuilder: fontBuilder, perform: model.perform)
            } else if let estimate = model.estimateText(kind) {
                Text(estimate)
                    .font(fontBuilder("WhitneySSm-Medium", 11))
                    .foregroundColor(TrainerAIPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("trainer-ai-estimate")
            }

            if !savedPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(savedPrompts) { prompt in
                        savedCapsule(prompt)
                    }
                }
                .padding(.top, 2)
            }

            if let notice = model.creditsNotice {
                Rectangle()
                    .fill(TrainerAIPalette.fieldBorder.opacity(0.5))
                    .frame(height: 1)
                    .padding(.top, 2)
                TrainerAICreditsRow(notice: notice, fontBuilder: fontBuilder, perform: model.perform)
            }

            Spacer().frame(height: 2)
        }
        .padding(.top, 8)
    }

    // MARK: Data

    /// Every AI filter on the site, text first, each with its kind tag.
    var savedPrompts: [PromptClassifier] {
        PromptClassifierKind.allCases.flatMap { PromptClassifier.saved(in: feed?.classifiers, kind: $0) }
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

    var placeholder: String {
        kind == .image
            ? NBLocalization.text("e.g., \"food photography\" or \"charts and graphs\"")
            : NBLocalization.text("e.g., \"AI and machine learning\" or \"local politics\"")
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
                TrainerAIPalette.subtleBackground
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
                .accessibilityIdentifier("trainer-ai-input-\(kind.rawValue)")

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
            .background(Capsule().fill(isError ? TrainerAIPalette.errorBackground : isMatch ? TrainerAIPalette.matchBackground : TrainerAIPalette.subtleBackground))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Capsules

    /// The live preview of what's typed: tap it to add the filter, or flip it between focus and hide first.
    var draftCapsule: some View {
        Button {
            isFieldFocused = false
            model.addDraft(kind, feedId: feed?.id)
        } label: {
            TrainerPromptCapsule(kind: kind, text: model.trimmedDraft(kind), score: model.draftScore(kind), isDraft: true,
                                 onDislike: { model.toggleDraftDirection(kind) })
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityIdentifier("trainer-ai-draft-\(kind.rawValue)")
    }

    func savedCapsule(_ prompt: PromptClassifier) -> some View {
        Button {
            model.tap(prompt, feedId: feed?.id, currentFolderName: currentFolderName)
        } label: {
            TrainerPromptCapsule(kind: prompt.kind, text: prompt.prompt, score: prompt.score, showsScope: true,
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
}

// MARK: - Header

/// TrainerAIPromptSection.swift's card title, with the Text / Images switch that picks what the filter being written
/// reads.
struct TrainerAIFilterHeader: View {
    @ObservedObject var model: TrainerAIPromptModel
    let font: Font
    let color: Color
    let fontBuilder: (String, CGFloat) -> Font

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(TrainerAIPalette.accent)
            Text(NBLocalization.text("AI filters"))
                .font(font)
                .foregroundColor(color)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                segment(.content, title: NBLocalization.text("Text"))
                segment(.image, title: NBLocalization.text("Images"))
            }
            .padding(2)
            .background(TrainerAIPalette.switchTrack)
            .cornerRadius(6)
        }
        .textCase(nil)
    }

    func segment(_ kind: PromptClassifierKind, title: String) -> some View {
        let isSelected = model.mode == kind
        return Button { model.mode = kind } label: {
            Text(title)
                .font(fontBuilder("WhitneySSm-Medium", 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .foregroundColor(isSelected ? .white : TrainerAIPalette.secondaryText)
                .background(isSelected ? TrainerAIPalette.accent : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("trainer-ai-mode-\(kind.rawValue)")
    }
}

// MARK: - Credits

/// TrainerAIPromptSection.swift's credits row at the bottom of the AI filter card (AIClassifiers.swift
/// AICreditsNotice): the month's summary with a chevron to the AI credits screen, a thin meter, and at most one short
/// state line in the meter's color, with its action under it while UsageBillingFeature.swift offers one.
struct TrainerAICreditsRow: View {
    let notice: AICreditsNotice
    let fontBuilder: (String, CGFloat) -> Font
    let perform: (AICreditsNotice.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { perform(.openCredits) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(notice.meter?.usedText ?? NBLocalization.text("AI Credits"))
                            .font(fontBuilder("WhitneySSm-Medium", 12))
                            .foregroundColor(TrainerAIPalette.text)
                            // A button label centers wrapped lines; the summary reads from the leading edge.
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(TrainerAIPalette.secondaryText)
                    }
                    if let meter = notice.meter {
                        AICreditsMeter(fraction: meter.fraction, fill: meterFill, height: 4)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            .accessibilityIdentifier("trainer-ai-credits-meter")

            ForEach(Array(notice.messages.enumerated()), id: \.offset) { _, message in
                Text(message)
                    .font(fontBuilder("WhitneySSm-Medium", 11))
                    .foregroundColor(stateColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let button = notice.button {
                TrainerAIActionButton(button: button, fontBuilder: fontBuilder, perform: perform)
                    .padding(.top, 2)
            }

            if let footnote = notice.footnote {
                Text(footnote)
                    .font(fontBuilder("WhitneySSm-Medium", 11))
                    .foregroundColor(TrainerAIPalette.secondaryText)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trainer-ai-credits")
    }

    /// Green while credits last, amber running low, red paused, over the meter's gray track.
    var meterFill: Color {
        switch notice.tone {
        case .paused: return AICreditsPalette.red
        case .warning: return AICreditsPalette.amber
        case .normal, .upgrade: return AICreditsPalette.green
        }
    }

    var stateColor: Color {
        switch notice.tone {
        case .paused: return TrainerAIPalette.pausedText
        case .warning: return AICreditsPalette.warningText
        case .normal, .upgrade: return TrainerAIPalette.secondaryText
        }
    }
}

/// TrainerAIPromptSection.swift's notice for a plan without credits, shown in place of the estimate.
struct TrainerAIFreeBanner: View {
    let notice: AICreditsNotice
    let fontBuilder: (String, CGFloat) -> Font
    let perform: (AICreditsNotice.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(notice.messages.enumerated()), id: \.offset) { _, message in
                Text(message)
                    .font(fontBuilder("WhitneySSm-Medium", 12))
                    .foregroundColor(TrainerAIPalette.bannerText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let button = notice.button {
                TrainerAIActionButton(button: button, fontBuilder: fontBuilder, perform: perform)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(TrainerAIPalette.bannerBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trainer-ai-free")
    }
}

/// A small button for a credit notice's action. With a description, such as what usage billing would cost, it spans
/// the card so the cost reads before the tap.
struct TrainerAIActionButton: View {
    let button: AICreditsNotice.ActionButton
    let fontBuilder: (String, CGFloat) -> Font
    let perform: (AICreditsNotice.Action) -> Void

    var body: some View {
        let isPrimary = button.action == .upgrade || button.action == .setUpBilling
        Button { perform(button.action) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(button.title)
                        .font(fontBuilder("WhitneySSm-Semibold", 12))
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 9, weight: .bold))
                }
                if let detail = button.detail {
                    Text(detail)
                        .font(fontBuilder("WhitneySSm-Medium", 11))
                        .opacity(0.92)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundColor(isPrimary ? .white : TrainerAIPalette.link)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: button.detail == nil ? nil : .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(isPrimary ? TrainerAIPalette.green : TrainerAIPalette.fieldBackground))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isPrimary ? Color.clear : TrainerAIPalette.fieldBorder, lineWidth: 1))
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityIdentifier("trainer-ai-credits-action")
    }
}

// MARK: - Prompt capsule

/// A natural language prompt in the trainer: like (focus) or dislike (hidden), with the scope toggles of the other
/// classifier capsules in TrainerCapsule.swift. Prompts wrap instead of growing past the trainer's width.
struct TrainerPromptCapsule: View {
    let kind: PromptClassifierKind
    let text: String
    let score: Int
    var isDraft = false
    var showsScope = false
    @Binding var scope: ClassifierScope
    var isPremiumArchive = false
    var isFolderAvailable = true
    var onScopeChanged: ((ClassifierScope) -> Void)?
    var onDislike: (() -> Void)?

    init(kind: PromptClassifierKind, text: String, score: Int, isDraft: Bool = false,
         showsScope: Bool = false, scope: Binding<ClassifierScope> = .constant(.feed), isPremiumArchive: Bool = false,
         isFolderAvailable: Bool = true, onScopeChanged: ((ClassifierScope) -> Void)? = nil,
         onDislike: (() -> Void)? = nil) {
        self.kind = kind
        self.text = text
        self.score = score
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
                    .foregroundColor(isActive ? .white : TrainerAIPalette.text)
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
            if isDraft {
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
    static var subtleBackground: Color { Color.themed([0xF2F4EF, 0xF3E9DA, 0x2C2C2E, 0x1C1C1E]) }
    static var matchText: Color { Color.themed([0x2E7D32, 0x2E7D32, 0x9DE58D, 0x9DE58D]) }
    static var matchBackground: Color { Color.themed([0xE8F5E9, 0xE6EFD9, 0x29442B, 0x1F3A21]) }
    static var errorText: Color { Color.themed([0xC62828, 0xB0352B, 0xFFA3A5, 0xFFA3A5]) }
    static var errorBackground: Color { Color.themed([0xFFEBEE, 0xF8E1DA, 0x512D31, 0x3E2226]) }
    static var bannerText: Color { Color.themed([0x5D4A1F, 0x5D4A1F, 0xF0DDA8, 0xF0DDA8]) }
    static var bannerBackground: Color { Color.themed([0xFFF4D6, 0xF7E6C4, 0x4A3F22, 0x3A3119]) }
    static var pausedText: Color { Color.themed([0x8A1F1F, 0x8A1F1F, 0xFFC2C2, 0xFFC2C2]) }
    static var link: Color { Color.themed([0x2F6FB3, 0x8A5A1E, 0x8CC4FF, 0x8CC4FF]) }
    static var switchTrack: Color { Color.themed([0xE8E8E8, 0xE0D8C8, 0x2C2C2E, 0x2C2C2E]) }
}
