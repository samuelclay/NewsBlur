//
//  AddSiteView.swift
//  NewsBlur
//
//  Created by Claude on 2026-02-23.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

// MARK: - Theme Colors

@available(iOS 15.0, *)
private struct AddSiteColors {
    static var background: Color {
        themedColor(light: 0xEAECE6, sepia: 0xF3E2CB, medium: 0x3D3D3D, dark: 0x1A1A1A)
    }

    static var cardBackground: Color {
        themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x4A4A4A, dark: 0x2A2A2A)
    }

    static var border: Color {
        themedColor(light: 0xD0D2CC, sepia: 0xD4C8B8, medium: 0x5A5A5A, dark: 0x404040)
    }

    static var textPrimary: Color {
        themedColor(light: 0x5E6267, sepia: 0x5C4A3D, medium: 0xE0E0E0, dark: 0xE8E8E8)
    }

    static var textSecondary: Color {
        themedColor(light: 0x90928B, sepia: 0x8B7B6B, medium: 0xA0A0A0, dark: 0xB0B0B0)
    }

    static var textFieldBackground: Color {
        themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x555555, dark: 0x333333)
    }

    static var errorText: Color {
        themedColor(light: 0xCC0000, sepia: 0xCC0000, medium: 0xFF4444, dark: 0xFF4444)
    }

    static let accent = Color(red: 0.416, green: 0.659, blue: 0.310) // #6AA84F

    static var addButtonBackground: Color {
        themedColor(light: 0x6F8299, sepia: 0x6F8299, medium: 0x5A7090, dark: 0x4A6080)
    }

    static var linkColor: Color {
        themedColor(light: 0x405BA8, sepia: 0x405BA8, medium: 0x3B7CC5, dark: 0x3B7CC5)
    }

    static var staleColor: Color {
        Color.orange
    }

    static var freshColor: Color {
        Color.green
    }

    private static func themedColor(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
        guard let themeManager = ThemeManager.shared else {
            return colorFromHex(light)
        }

        let effectiveTheme = themeManager.effectiveTheme

        let hex: Int
        if effectiveTheme == ThemeStyleMedium || effectiveTheme == "medium" {
            hex = medium
        } else if effectiveTheme == ThemeStyleDark || effectiveTheme == "dark" {
            hex = dark
        } else if effectiveTheme == ThemeStyleSepia || effectiveTheme == "sepia" {
            hex = sepia
        } else {
            hex = light
        }
        return colorFromHex(hex)
    }

    private static func colorFromHex(_ hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - Main View

@available(iOS 15.0, *)
struct AddSiteView: View {
    @ObservedObject var viewModel: AddSiteViewModel
    @StateObject private var themeObserver = AskAIThemeObserver()
    var onDismiss: () -> Void

    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView

            urlInputRow
                .padding(.horizontal, 12)
                .padding(.top, 4)

            folderRow
                .padding(.horizontal, 12)
                .padding(.top, 4)

            if viewModel.showAddFolder {
                addFolderRow
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }

            if let error = viewModel.errorMessage {
                errorView(error)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }

            if viewModel.isAdding {
                addingView
                    .padding(.top, 4)
            }

            if !viewModel.autocompleteResults.isEmpty && !viewModel.isAdding {
                autocompleteList
            }

            Spacer(minLength: 0)
        }
        .background(AddSiteColors.background)
        .id(themeObserver.themeVersion)
        .onAppear {
            isURLFieldFocused = true
        }
        .onChange(of: viewModel.searchText) { _ in
            viewModel.onSearchTextChanged()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(uiImage: Utilities.imageNamed("world", sized: 16))
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(AddSiteColors.textSecondary)

            Text("Add site")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AddSiteColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AddSiteColors.cardBackground)
    }

    // MARK: - URL Input Row (bottom)

    private var urlInputRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(uiImage: Utilities.imageNamed("world", sized: 16))
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(AddSiteColors.textSecondary)

                TextField("https:// or search", text: $viewModel.searchText)
                    .font(.system(size: 15))
                    .foregroundColor(AddSiteColors.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .focused($isURLFieldFocused)
                    .submitLabel(viewModel.searchText.contains(".") ? .done : .search)
                    .onSubmit {
                        if viewModel.searchText.contains(".") {
                            viewModel.addSite()
                        } else {
                            viewModel.onSearchTextChanged()
                        }
                    }

                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AddSiteColors.textSecondary))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AddSiteColors.textFieldBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AddSiteColors.border, lineWidth: 1)
            )

            Button(action: { viewModel.addSite() }) {
                Text("Add site")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.searchText.isEmpty || viewModel.isAdding
                            ? Color.gray.opacity(0.5)
                            : AddSiteColors.addButtonBackground
                    )
                    .cornerRadius(8)
            }
            .disabled(viewModel.searchText.isEmpty || viewModel.isAdding)
        }
    }

    // MARK: - Folder Row

    private var folderRow: some View {
        HStack(spacing: 0) {
            Menu {
                Button(action: { viewModel.selectedFolder = "" }) {
                    Label("Top Level", systemImage: viewModel.selectedFolder.isEmpty ? "checkmark" : "folder")
                }

                ForEach(viewModel.folders, id: \.self) { folder in
                    Button(action: { viewModel.selectedFolder = folder }) {
                        let name = viewModel.folderDisplayName(folder)
                        Label(name, systemImage: viewModel.selectedFolder == folder ? "checkmark" : "folder")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(uiImage: Utilities.imageNamed("g_icn_folder_sm", sized: 16))
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(AddSiteColors.textSecondary)

                    Text(viewModel.displayFolder)
                        .font(.system(size: 14))
                        .foregroundColor(AddSiteColors.textPrimary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AddSiteColors.textSecondary)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AddSiteColors.textFieldBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AddSiteColors.border, lineWidth: 1)
                )
            }

            Spacer().frame(width: 8)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.showAddFolder.toggle()
                }
            }) {
                Image(systemName: viewModel.showAddFolder ? "folder.badge.minus" : "folder.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.showAddFolder ? AddSiteColors.accent : AddSiteColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AddSiteColors.textFieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.showAddFolder ? AddSiteColors.accent : AddSiteColors.border, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Add Folder Row

    private var addFolderRow: some View {
        HStack(spacing: 6) {
            Image(uiImage: Utilities.imageNamed("g_icn_folder_rss_sm", sized: 16))
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(AddSiteColors.textSecondary)

            TextField("New folder name", text: $viewModel.newFolderName)
                .font(.system(size: 14))
                .foregroundColor(AddSiteColors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AddSiteColors.textFieldBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AddSiteColors.border, lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(AddSiteColors.errorText)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(AddSiteColors.errorText)
                .lineLimit(2)

            Spacer()
        }
        .padding(10)
        .background(AddSiteColors.errorText.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Adding View

    private var addingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AddSiteColors.accent))

            Text("Adding site...")
                .font(.system(size: 14))
                .foregroundColor(AddSiteColors.textSecondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Autocomplete List

    private var autocompleteList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.autocompleteResults) { result in
                    autocompleteRow(result)
                }
            }
        }
        .padding(.top, 8)
    }

    private func autocompleteRow(_ result: AutocompleteResult) -> some View {
        Button(action: { viewModel.selectAutocompleteResult(result) }) {
            HStack(spacing: 10) {
                faviconImage(result.favicon)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AddSiteColors.textPrimary)
                        .lineLimit(1)

                    Text(result.value)
                        .font(.system(size: 12))
                        .foregroundColor(AddSiteColors.linkColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    let subs = result.numSubscribers
                    Text("\(formatNumber(subs)) subscriber\(subs == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(AddSiteColors.textSecondary)

                    lastUpdateView(result.lastStorySecondsAgo)
                }
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .background(AddSiteColors.cardBackground)
        .overlay(
            Rectangle()
                .fill(AddSiteColors.border.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Last Update View

    @ViewBuilder
    private func lastUpdateView(_ secondsAgo: Int?) -> some View {
        let info = formatLastUpdate(secondsAgo)
        if !info.text.isEmpty {
            HStack(spacing: 4) {
                Circle()
                    .fill(info.isStale ? AddSiteColors.staleColor : AddSiteColors.freshColor)
                    .frame(width: 6, height: 6)

                Text(info.text)
                    .font(.system(size: 11))
                    .foregroundColor(info.isStale ? AddSiteColors.staleColor : AddSiteColors.freshColor)
            }
        }
    }

    private func formatLastUpdate(_ secondsAgo: Int?) -> (text: String, isStale: Bool) {
        guard let seconds = secondsAgo, seconds > 0 else {
            return ("", false)
        }

        let staleThreshold = 365 * 24 * 60 * 60
        let isStale = seconds > staleThreshold

        if isStale {
            let date = Date().addingTimeInterval(-Double(seconds))
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return ("Stale \(formatter.string(from: date))", true)
        } else {
            let days = seconds / 86400
            if days < 1 {
                let hours = max(1, seconds / 3600)
                return ("\(hours)h ago", false)
            } else if days < 7 {
                return ("\(days)d ago", false)
            } else if days < 30 {
                return ("\(days / 7)w ago", false)
            } else {
                return ("\(days / 30)mo ago", false)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func faviconImage(_ base64: String?) -> some View {
        if let base64 = base64,
           !base64.isEmpty,
           let data = Data(base64Encoded: base64),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(uiImage: Utilities.imageNamed("world", sized: 16))
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(AddSiteColors.textSecondary)
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
