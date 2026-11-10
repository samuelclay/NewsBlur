//
//  ListenVoiceSettingsView.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

/// ListenVoiceSettingsView.swift is the voice picker, laid out like the web's Listen settings popover
/// (media/js/newsblur/views/listen_settings_popover.js): the voice header with a language menu, search, one row
/// of filters, one voice list (Recommended, then More voices from the library), then delivery, speed,
/// auto-continue, follow along, a collapsed fine-tune section and the listening allowance.
struct ListenVoiceSettingsView: View {
    let showsDoneButton: Bool

    @StateObject private var model = ListenVoiceSettingsModel()
    @ObservedObject private var player = ListenPlayer.shared
    @ObservedObject private var theme = ListenThemeObserver.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showsFineTune = false
    @State private var autoContinue = ListenPreferences.autoContinue
    @State private var highlight = ListenPreferences.highlight

    private static let listHeight: CGFloat = 300
    private static let listTop = "listen-voice-list-top"

    var body: some View {
        let _ = theme.version
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                voiceHeader
                searchField
                filterRow
                voiceList
                if let message = statusMessage {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(model.preview.errorMessage != nil ? ListenColors.error : ListenColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                settingsCard
                usageFooter
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ListenColors.sheetBackground.ignoresSafeArea())
        .navigationTitle(NBLocalization.text("Listen Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NBLocalization.text("Done")) {
                        model.preview.stop()
                        dismiss()
                    }
                }
            }
        }
        // ListenVoiceSettingsView.swift keeps controls neutral; the chosen voice's row is the only accent color.
        .tint(ListenColors.textPrimary)
        .onAppear {
            model.load()
            showsFineTune = false
        }
        .onDisappear {
            model.preview.stop()
        }
        .environment(\.colorScheme, ListenColors.colorScheme)
        .environment(\.layoutDirection, NBLocalization.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    // MARK: - Voice header, search and filters

    private var voiceHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NBLocalization.text("Voice"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ListenColors.textPrimary)
                Text(String(format: NBLocalization.text("Reads your %@ stories"), model.languageName))
                    .font(.system(size: 13))
                    .foregroundColor(ListenColors.textSecondary)
            }
            Spacer(minLength: 8)
            Menu {
                Picker(NBLocalization.text("Story language"), selection: Binding(get: { model.language },
                                                                                set: { model.setLanguage($0) })) {
                    ForEach(model.languages) { language in
                        Text(language.name).tag(language.code)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(model.languageName)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ListenColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(ListenColors.card))
                .overlay(Capsule().stroke(ListenColors.border.opacity(0.7), lineWidth: 0.5))
            }
            // ListenVoiceSettingsView.swift draws its own chevrons; the Mac would add a second indicator.
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .accessibilityLabel(NBLocalization.text("Story language"))
        }
        .padding(.horizontal, 4)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ListenColors.textSecondary)
            TextField(NBLocalization.text("Search voices"), text: $model.search)
                .font(.system(size: 15))
                .foregroundColor(ListenColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: model.search) { _, _ in model.searchChanged() }
            if !model.search.isEmpty {
                Button {
                    model.search = ""
                    model.searchChanged()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ListenColors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NBLocalization.text("Clear"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ListenColors.card))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(ListenColors.border.opacity(0.7), lineWidth: 0.5))
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ListenVoiceFilter.allCases) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func filterChip(_ filter: ListenVoiceFilter) -> some View {
        let value = model.filters[filter]
        let options = model.options(for: filter)
        return HStack(spacing: 2) {
            Menu {
                ForEach(options) { option in
                    Button {
                        model.setFilter(filter, to: option.value)
                    } label: {
                        if value == option.value {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(value.map { model.label(for: filter, value: $0) } ?? filter.title)
                        .lineLimit(1)
                    if value == nil {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .font(.system(size: 13, weight: value == nil ? .regular : .semibold))
                .foregroundColor(value == nil ? ListenColors.textSecondary : ListenColors.textPrimary)
                .padding(.leading, 11)
                .padding(.trailing, value == nil ? 11 : 2)
                .padding(.vertical, 6)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .disabled(options.isEmpty)
            .accessibilityLabel(filter.title)
            .accessibilityValue(value.map { model.label(for: filter, value: $0) } ?? "")
            if value != nil {
                Button {
                    model.setFilter(filter, to: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ListenColors.textSecondary)
                        .frame(width: 22, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .accessibilityLabel(String(format: NBLocalization.text("Clear %@"), filter.title))
            }
        }
        .background(Capsule().fill(ListenColors.card))
        .overlay(Capsule().stroke(value == nil ? ListenColors.border.opacity(0.7) : ListenColors.textSecondary.opacity(0.6),
                                  lineWidth: value == nil ? 0.5 : 1))
    }

    // MARK: - Voice list

    private var voiceList: some View {
        let recommended = model.recommended
        let more = model.moreVoices
        let selected = model.selectedVoiceId
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Color.clear
                        .frame(height: 0)
                        .id(Self.listTop)
                    if recommended.isEmpty && more.isEmpty {
                        if model.isLoadingVoices {
                            loadingRow
                        } else if let error = model.loadError ?? model.libraryError {
                            emptyState(message: error, showsClear: false, showsRetry: true)
                        } else {
                            emptyState(message: NBLocalization.text("No voices match these filters"),
                                       showsClear: model.hasFilters, showsRetry: false)
                        }
                    } else {
                        if !recommended.isEmpty {
                            Section {
                                ForEach(recommended) { voice in
                                    voiceRow(voice, selected: voice.id == selected)
                                }
                            } header: {
                                listHeader(String(format: NBLocalization.text("Recommended for %@"), model.languageName),
                                           count: model.hasFilters
                                            ? NBLocalization.plural("%@ match", groupedCount: recommended.count) : nil)
                            }
                        }
                        if !more.isEmpty || model.isLoadingLibrary {
                            Section {
                                ForEach(more) { voice in
                                    voiceRow(voice, selected: voice.id == selected)
                                        .onAppear { model.loadMoreIfNeeded(after: voice) }
                                }
                                if model.isLoadingLibrary {
                                    loadingRow
                                }
                            } header: {
                                listHeader(NBLocalization.text("More voices"), count: nil)
                            }
                        }
                    }
                }
            }
            .onChange(of: model.listGeneration) { _, _ in
                proxy.scrollTo(Self.listTop, anchor: .top)
            }
        }
        .frame(height: Self.listHeight)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ListenColors.card))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ListenColors.border.opacity(0.6), lineWidth: 0.5))
        .accessibilityIdentifier("listen-voice-list")
    }

    private func listHeader(_ title: String, count: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundColor(ListenColors.textSecondary)
            Spacer()
            if let count {
                Text(count)
                    .font(.system(size: 11))
                    .foregroundColor(ListenColors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 5)
        .background(ListenColors.card)
    }

    private func voiceRow(_ voice: ListenVoice, selected: Bool) -> some View {
        ListenVoiceRow(voice: voice, traits: model.traits(for: voice), isSelected: selected,
                       preview: model.preview,
                       onSelect: { model.select(voice) },
                       onPreview: { model.togglePreview(voice) })
    }

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(NBLocalization.text("Loading voices…"))
                .font(.system(size: 13))
                .foregroundColor(ListenColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private func emptyState(message: String, showsClear: Bool, showsRetry: Bool) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(ListenColors.textSecondary)
                .multilineTextAlignment(.center)
            if showsClear {
                Button(NBLocalization.text("Clear filters")) {
                    model.clearFilters()
                }
                .font(.system(size: 14, weight: .semibold))
            }
            if showsRetry {
                Button(NBLocalization.text("Retry")) {
                    model.load()
                }
                .font(.system(size: 14, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 40)
    }

    private var statusMessage: String? {
        if let error = model.preview.errorMessage {
            return error
        }
        if let name = model.fallbackVoiceName {
            return String(format: NBLocalization.text("Your chosen voice isn't available right now, so %@ is reading this story."), name)
        }
        return nil
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingRow(NBLocalization.text("Delivery"), NBLocalization.text("How much emotion")) {
                Picker(NBLocalization.text("Delivery"), selection: Binding(get: { model.delivery.delivery },
                                                                          set: { model.choosePreset($0) })) {
                    ForEach(model.deliveryChoices, id: \.self) { choice in
                        Text(model.deliveryTitle(choice)).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("listen-delivery")
            }
            divider
            settingRow(NBLocalization.text("Speed"), NBLocalization.text("Playback speed")) {
                ListenSpeedControl()
            }
            divider
            toggleRow(NBLocalization.text("Auto-continue"), NBLocalization.text("Play the next unread story"),
                      isOn: Binding(get: { autoContinue }, set: { value in
                autoContinue = value
                ListenPreferences.setAutoContinue(value)
            }))
            divider
            toggleRow(NBLocalization.text("Follow along"), NBLocalization.text("Highlight the paragraph being read"),
                      isOn: Binding(get: { highlight }, set: { value in
                highlight = value
                ListenPreferences.setHighlight(value)
            }))
            divider
            fineTune
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ListenColors.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ListenColors.border.opacity(0.6), lineWidth: 0.5))
    }

    private var divider: some View {
        Divider()
            .overlay(ListenColors.border.opacity(0.5))
            .padding(.leading, 14)
    }

    private func label(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(ListenColors.textPrimary)
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(ListenColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingRow<Control: View>(_ title: String, _ description: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label(title, description)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    /// On/Off as a segmented control, like the web popover (listen_settings_popover.js).
    private func toggleRow(_ title: String, _ description: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            label(title, description)
            Spacer(minLength: 8)
            Picker(title, selection: isOn) {
                Text(NBLocalization.text("On")).tag(true)
                Text(NBLocalization.text("Off")).tag(false)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var fineTune: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsFineTune.toggle()
                }
            } label: {
                HStack {
                    label(NBLocalization.text("Fine-tune voice"), NBLocalization.text("Stability, similarity and style"))
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ListenColors.textSecondary)
                        .rotationEffect(.degrees(showsFineTune ? 90 : 0))
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("listen-fine-tune")
            if showsFineTune {
                VStack(spacing: 0) {
                    slider(NBLocalization.text("Stability"), NBLocalization.text("Steadier or more varied"),
                           value: $model.delivery.stability)
                    slider(NBLocalization.text("Similarity"), NBLocalization.text("Closeness to the original voice"),
                           value: $model.delivery.similarity)
                    slider(NBLocalization.text("Style"), NBLocalization.text("Exaggerates the voice's style"),
                           value: $model.delivery.style)
                    toggleRow(NBLocalization.text("Speaker boost"), NBLocalization.text("A clearer, closer sound"),
                              isOn: Binding(get: { model.delivery.speakerBoost }, set: { value in
                        model.delivery.speakerBoost = value
                        model.fineTuneChanged()
                        model.commitDelivery()
                    }))
                }
                .transition(.opacity)
            }
        }
    }

    private func slider(_ title: String, _ description: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                label(title, description)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundColor(ListenColors.textSecondary)
            }
            Slider(value: value, in: 0...1, step: 0.05, onEditingChanged: { editing in
                if editing {
                    model.fineTuneChanged()
                } else {
                    model.commitDelivery()
                }
            })
            .accessibilityLabel(title)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - Usage

    @ViewBuilder
    private var usageFooter: some View {
        if let usage = model.usageText {
            HStack(spacing: 6) {
                Text(usage)
                    .font(.system(size: 12))
                    .foregroundColor(ListenColors.textSecondary)
                if model.showsUpgrade {
                    Button(NBLocalization.text("Upgrade")) {
                        model.preview.stop()
                        ListenPresenter.showUpgrade(.archive)
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
    }
}

/// One voice in the picker: a checkmark when chosen, the name and short description on one line, a quiet trait
/// line, and a round preview button. The chosen row's soft background is the picker's only accent color
/// (ListenVoiceSettingsView.swift).
struct ListenVoiceRow: View {
    let voice: ListenVoice
    let traits: String
    let isSelected: Bool
    @ObservedObject var preview: ListenVoicePreviewPlayer
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ListenColors.textPrimary)
                .frame(width: 16)
                .opacity(isSelected ? 1 : 0)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(nameText)\(descriptionText)")
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !traits.isEmpty {
                    Text(traits)
                        .font(.system(size: 11))
                        .foregroundColor(ListenColors.textSecondary.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            previewButton
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(isSelected ? ListenColors.accent.opacity(ListenColors.isDark ? 0.17 : 0.14) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
        .accessibilityAction(named: Text(isPlaying ? NBLocalization.text("Stop preview")
                                                   : NBLocalization.text("Preview this voice")), onPreview)
    }

    private var isPlaying: Bool { preview.playingVoiceId == voice.id }

    private var nameText: Text {
        Text(verbatim: voice.displayName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(ListenColors.textPrimary)
    }

    private var descriptionText: Text {
        Text(verbatim: voice.description.isEmpty ? "" : "  " + voice.description)
            .font(.system(size: 13))
            .foregroundColor(ListenColors.textSecondary)
    }

    private var previewButton: some View {
        Button(action: onPreview) {
            ZStack {
                Circle()
                    .stroke(ListenColors.border, lineWidth: 1)
                if preview.loadingVoiceId == voice.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ListenColors.textPrimary)
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? NBLocalization.text("Stop preview") : NBLocalization.text("Preview this voice"))
    }
}
