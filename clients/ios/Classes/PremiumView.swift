//
//  PremiumView.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-09.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI
import StoreKit

// MARK: - Premium Colors (Theme-aware)

@available(iOS 15.0, *)
private struct PremiumColors {
    static var background: Color {
        themedColor(light: 0xF0F2ED, sepia: 0xF3E2CB, medium: 0x2C2C2E, dark: 0x1C1C1E)
    }

    static var cardBackground: Color {
        themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x3A3A3C, dark: 0x2C2C2E)
    }

    static var secondaryBackground: Color {
        themedColor(light: 0xF7F7F5, sepia: 0xFAF5ED, medium: 0x48484A, dark: 0x38383A)
    }

    static var textPrimary: Color {
        themedColor(light: 0x1C1C1E, sepia: 0x3C3226, medium: 0xF2F2F7, dark: 0xF2F2F7)
    }

    static var textSecondary: Color {
        themedColor(light: 0x6E6E73, sepia: 0x8B7B6B, medium: 0xAEAEB2, dark: 0x98989D)
    }

    static var border: Color {
        themedColor(light: 0xD1D1D6, sepia: 0xD4C8B8, medium: 0x545458, dark: 0x48484A)
    }

    static var premiumGold: Color { Color(red: 0.85, green: 0.65, blue: 0.13) }
    static var premiumGoldLight: Color { Color(red: 0.98, green: 0.84, blue: 0.35) }

    static var archivePurple: Color { Color(red: 0.55, green: 0.35, blue: 0.85) }
    static var archivePurpleLight: Color { Color(red: 0.75, green: 0.55, blue: 0.95) }

    static var proOrange: Color { Color(red: 0.96, green: 0.62, blue: 0.04) }
    static var proOrangeLight: Color { Color(red: 0.85, green: 0.47, blue: 0.04) }

    static var newsblurGreen: Color { Color(red: 0.439, green: 0.620, blue: 0.365) }

    private static func themedColor(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
        guard let themeManager = ThemeManager.shared else {
            return colorFromHex(light)
        }

        let hex: Int
        if themeManager.isDarkTheme {
            let theme = themeManager.theme
            if theme == ThemeStyleMedium || theme == "medium" {
                hex = medium
            } else {
                hex = dark
            }
        } else {
            let theme = themeManager.theme
            if theme == ThemeStyleSepia || theme == "sepia" {
                hex = sepia
            } else {
                hex = light
            }
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

// MARK: - Premium Feature Model

struct PremiumFeature: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let iconColor: Color
    let isCustomImage: Bool
    let isUpcoming: Bool

    init(title: String, icon: String, iconColor: Color, isCustomImage: Bool = false, isUpcoming: Bool = false) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.isCustomImage = isCustomImage
        self.isUpcoming = isUpcoming
    }
}

// MARK: - Premium View

@available(iOS 15.0, *)
struct PremiumView: View {
    @ObservedObject var viewModel: PremiumViewModel
    var onDismiss: () -> Void
    var onRestore: () -> Void
    var scrollToArchive: Bool = false
    var scrollToPro: Bool = false

    private let premiumFeatures: [PremiumFeature] = [
        PremiumFeature(title: "Follow up to 1,024 sites", icon: "square.stack.3d.up.fill", iconColor: .blue),
        PremiumFeature(title: "Sites updated up to 5x more often", icon: "bolt.fill", iconColor: .yellow),
        PremiumFeature(title: "River of News (reading by folder)", icon: "newspaper.fill", iconColor: .orange),
        PremiumFeature(title: "Search sites and folders", icon: "magnifyingglass", iconColor: .purple),
        PremiumFeature(title: "Save stories with searchable tags", icon: "tag.fill", iconColor: .pink),
        PremiumFeature(title: "Privacy options for your blurblog", icon: "lock.shield.fill", iconColor: .green),
        PremiumFeature(title: "Custom RSS feeds for saved stories", icon: "dot.radiowaves.up.forward", iconColor: .orange),
        PremiumFeature(title: "Text view conveniently extracts the story", icon: "doc.text.fill", iconColor: .cyan),
        PremiumFeature(title: "You feed Lyric, NewsBlur's hungry hound, for 6 days", icon: "fork.knife", iconColor: .brown)
    ]

    private let archiveFeatures: [PremiumFeature] = [
        PremiumFeature(title: "Everything in the premium subscription, of course", icon: "sparkles", iconColor: .yellow),
        PremiumFeature(title: "Choose when stories are automatically marked as read", icon: "book.fill", iconColor: .blue),
        PremiumFeature(title: "Every story from every site is archived and searchable forever", icon: "archivebox.fill", iconColor: .purple),
        PremiumFeature(title: "Feeds that support paging are back-filled in for a complete archive", icon: "arrow.clockwise.circle.fill", iconColor: .teal),
        PremiumFeature(title: "Export trained stories from folders as RSS feeds", icon: "square.and.arrow.up.fill", iconColor: .orange),
        PremiumFeature(title: "Stories can stay unread forever", icon: "calendar.badge.clock", iconColor: .red),
        PremiumFeature(title: "Ask AI questions about stories", icon: "icons8-prompt-100", iconColor: Color(red: 0.85, green: 0.45, blue: 0.37), isCustomImage: true)
    ]

    @available(iOS 15.0, *)
    private var proFeatures: [PremiumFeature] {
        [
            PremiumFeature(title: "Everything in the archive subscription, of course", icon: "sparkles", iconColor: .yellow),
            PremiumFeature(title: "Follow up to 10,000 sites", icon: "square.stack.3d.up.fill", iconColor: .green),
            PremiumFeature(title: "All feeds fetched every 5-15 minutes", icon: "bolt.fill", iconColor: PremiumColors.proOrange),
            PremiumFeature(title: "Train stories with regular expressions", icon: "textformat.abc", iconColor: .yellow),
            PremiumFeature(title: "Priority support", icon: "headphones", iconColor: .yellow),
            PremiumFeature(title: "Natural language filters", icon: "text.magnifyingglass", iconColor: .gray, isUpcoming: true),
            PremiumFeature(title: "Natural language search", icon: "magnifyingglass.circle", iconColor: .gray, isUpcoming: true)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done") {
                    onDismiss()
                }
                .foregroundColor(PremiumColors.newsblurGreen)
                Spacer()
                Text("NewsBlur Premium")
                    .font(.headline)
                    .foregroundColor(PremiumColors.textPrimary)
                Spacer()
                Button("Restore") {
                    onRestore()
                }
                .foregroundColor(PremiumColors.newsblurGreen)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // Premium Section
                        premiumSection

                        // Archive Section
                        archiveSection
                            .id("archiveSection")

                        // Pro Section
                        proSection
                            .id("proSection")

                        // Footer links
                        footerSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .onAppear {
                    if scrollToArchive {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo("archiveSection", anchor: .top)
                            }
                        }
                    } else if scrollToPro {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo("proSection", anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .background(PremiumColors.background.ignoresSafeArea())
    }

    // MARK: - Premium Section

    private var premiumSection: some View {
        VStack(spacing: 0) {
            // Header with gradient
            sectionHeader(
                title: "Premium Subscription",
                gradient: [PremiumColors.premiumGold, PremiumColors.premiumGoldLight],
                icon: "star.fill"
            )

            // Features list
            VStack(spacing: 0) {
                ForEach(premiumFeatures) { feature in
                    featureRow(feature)

                    if feature.id != premiumFeatures.last?.id {
                        Divider()
                            .background(PremiumColors.border)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(PremiumColors.cardBackground)

            // Dog image
            dogImageSection

            // Subscription status/button
            premiumStatusSection
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Archive Section

    private var archiveSection: some View {
        VStack(spacing: 0) {
            // Header with gradient
            sectionHeader(
                title: "Premium Archive",
                gradient: [PremiumColors.archivePurple, PremiumColors.archivePurpleLight],
                icon: "archivebox.fill"
            )

            // Features list
            VStack(spacing: 0) {
                ForEach(archiveFeatures) { feature in
                    featureRow(feature)

                    if feature.id != archiveFeatures.last?.id {
                        Divider()
                            .background(PremiumColors.border)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(PremiumColors.cardBackground)

            // Subscription status/button
            archiveStatusSection
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Pro Section

    private var proSection: some View {
        VStack(spacing: 0) {
            // Header with gradient
            sectionHeader(
                title: "Premium Pro",
                gradient: [PremiumColors.proOrange, PremiumColors.proOrangeLight],
                icon: "crown.fill"
            )

            // Features list
            VStack(spacing: 0) {
                let features = proFeatures
                ForEach(features) { feature in
                    featureRow(feature)

                    if feature.id != features.last?.id {
                        Divider()
                            .background(PremiumColors.border)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(PremiumColors.cardBackground)

            // Subscription status/button
            proStatusSection
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, gradient: [Color], icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: gradient,
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Feature Row

    private func featureRow(_ feature: PremiumFeature) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(feature.iconColor.opacity(feature.isUpcoming ? 0.08 : 0.15))
                    .frame(width: 36, height: 36)

                if feature.isCustomImage {
                    if let uiImage = UIImage(named: feature.icon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundColor(feature.iconColor)
                    }
                } else {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(feature.iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(feature.isUpcoming ? PremiumColors.textSecondary : PremiumColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if feature.isUpcoming {
                    Text("Coming soon")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(PremiumColors.textSecondary)
                        .opacity(0.7)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(feature.isUpcoming ? 0.6 : 1.0)
    }

    // MARK: - Dog Image Section

    private var dogImageSection: some View {
        VStack(spacing: 12) {
            if let uiImage = UIImage(named: "Lyric.jpg") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(PremiumColors.premiumGold, lineWidth: 3)
                    )
                    .shadow(color: PremiumColors.premiumGold.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(PremiumColors.secondaryBackground)
    }

    // MARK: - Premium Status Section

    private var premiumStatusSection: some View {
        Group {
            if viewModel.isPremium {
                let message: String = {
                    if viewModel.isPremiumPro {
                        return "Your premium pro subscription includes everything above"
                    } else if viewModel.isPremiumArchive {
                        return "Your premium archive subscription includes everything above"
                    } else {
                        return "Your premium subscription is active"
                    }
                }()
                subscribedView(
                    message: message,
                    gradientColors: [PremiumColors.premiumGold, PremiumColors.premiumGoldLight],
                    showManage: !viewModel.isPremiumArchive && !viewModel.isPremiumPro
                )
            } else {
                purchaseButton(
                    product: viewModel.premiumProduct,
                    gradientColors: [PremiumColors.premiumGold, PremiumColors.premiumGoldLight]
                )
            }
        }
    }

    // MARK: - Archive Status Section

    private var archiveStatusSection: some View {
        Group {
            if viewModel.isPremiumPro {
                subscribedView(
                    message: "Your premium pro subscription includes everything above",
                    gradientColors: [PremiumColors.archivePurple, PremiumColors.archivePurpleLight],
                    showManage: false
                )
            } else if viewModel.isPremiumArchive {
                subscribedView(
                    message: "Your premium archive subscription is active",
                    gradientColors: [PremiumColors.archivePurple, PremiumColors.archivePurpleLight],
                    showManage: true
                )
            } else if viewModel.isPremium {
                purchaseButton(
                    product: viewModel.archiveProduct,
                    gradientColors: [PremiumColors.archivePurple, PremiumColors.archivePurpleLight],
                    subtitle: "Upgrade from Premium"
                )
            } else {
                purchaseButton(
                    product: viewModel.archiveProduct,
                    gradientColors: [PremiumColors.archivePurple, PremiumColors.archivePurpleLight]
                )
            }
        }
    }

    // MARK: - Pro Status Section

    private var proStatusSection: some View {
        Group {
            if viewModel.isPremiumPro {
                subscribedView(
                    message: "Your premium pro subscription is active",
                    gradientColors: [PremiumColors.proOrange, PremiumColors.proOrangeLight],
                    showManage: true
                )
            } else if viewModel.isPremiumArchive {
                purchaseButton(
                    product: viewModel.proProduct,
                    gradientColors: [PremiumColors.proOrange, PremiumColors.proOrangeLight],
                    subtitle: "Upgrade from Archive",
                    isMonthly: true
                )
            } else if viewModel.isPremium {
                purchaseButton(
                    product: viewModel.proProduct,
                    gradientColors: [PremiumColors.proOrange, PremiumColors.proOrangeLight],
                    subtitle: "Upgrade from Premium",
                    isMonthly: true
                )
            } else {
                purchaseButton(
                    product: viewModel.proProduct,
                    gradientColors: [PremiumColors.proOrange, PremiumColors.proOrangeLight],
                    isMonthly: true
                )
            }
        }
    }

    // MARK: - Subscribed View

    private func subscribedView(message: String, gradientColors: [Color], showManage: Bool) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PremiumColors.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showManage {
                Button(action: openSubscriptionManagement) {
                    Text("Manage Subscription")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(PremiumColors.textSecondary)
                        )
                }
            }

            if viewModel.premiumExpireDate != nil {
                Text(expirationText)
                    .font(.system(size: 13))
                    .foregroundColor(PremiumColors.textSecondary)
            }
        }
        .padding(20)
        .background(PremiumColors.secondaryBackground)
    }

    // MARK: - Purchase Button

    private func purchaseButton(product: SKProduct?, gradientColors: [Color], subtitle: String? = nil, isMonthly: Bool = false) -> some View {
        VStack(spacing: 12) {
            if let product = product {
                Button(action: { viewModel.purchase(product) }) {
                    VStack(spacing: 4) {
                        Text(product.localizedTitle.isEmpty ? "NewsBlur Premium" : product.localizedTitle)
                            .font(.system(size: 17, weight: .bold))

                        Text(isMonthly ? priceTextMonthly(for: product) : priceText(for: product))
                            .font(.system(size: 14, weight: .medium))
                            .opacity(0.9)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.8)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: gradientColors[0].opacity(0.4), radius: 8, x: 0, y: 4)
                }
            } else {
                Text("Loading...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(PremiumColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PremiumColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .background(PremiumColors.secondaryBackground)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 12) {
            linkButton(title: "Privacy Policy", url: "https://newsblur.com/privacy/")
            linkButton(title: "Terms of Use", url: "https://newsblur.com/tos/")
        }
    }

    private func linkButton(title: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(PremiumColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PremiumColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private var expirationText: String {
        if let date = viewModel.premiumExpireDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return "Your subscription will renew on \(formatter.string(from: date))"
        } else {
            return "Your subscription is set to never expire. Whoa!"
        }
    }

    private func priceText(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale

        let yearlyPrice = formatter.string(from: product.price) ?? ""
        let monthlyPrice = formatter.string(from: NSNumber(value: product.price.doubleValue / 12.0)) ?? ""

        return "\(yearlyPrice)/year (\(monthlyPrice)/month)"
    }

    private func priceTextMonthly(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale

        let monthlyPrice = formatter.string(from: product.price) ?? ""

        return "\(monthlyPrice)/month"
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Premium View Model

@available(iOS 15.0, *)
class PremiumViewModel: ObservableObject {
    @Published var premiumProduct: SKProduct?
    @Published var archiveProduct: SKProduct?
    @Published var proProduct: SKProduct?
    @Published var isPremium: Bool = false
    @Published var isPremiumArchive: Bool = false
    @Published var isPremiumPro: Bool = false
    @Published var premiumExpireDate: Date?

    weak var appDelegate: NewsBlurAppDelegate?

    init() {
        updateFromAppDelegate()
    }

    func updateFromAppDelegate() {
        guard let appDelegate = NewsBlurAppDelegate.shared() else { return }
        self.appDelegate = appDelegate

        isPremium = appDelegate.isPremium
        isPremiumArchive = appDelegate.isPremiumArchive
        isPremiumPro = appDelegate.isPremiumPro

        if appDelegate.premiumExpire != 0 {
            premiumExpireDate = Date(timeIntervalSince1970: TimeInterval(appDelegate.premiumExpire))
        }

        premiumProduct = appDelegate.premiumManager.premiumProduct
        archiveProduct = appDelegate.premiumManager.premiumArchiveProduct
        proProduct = appDelegate.premiumManager.premiumProProduct
    }

    func loadProducts() {
        appDelegate?.premiumManager.loadProducts()
    }

    func purchase(_ product: SKProduct) {
        appDelegate?.premiumManager.purchase(product)
    }

    func restore() {
        appDelegate?.premiumManager.restorePurchase()
    }
}

// MARK: - UIKit Hosting Controller

@available(iOS 15.0, *)
@objc class PremiumViewHostingController: UIViewController {
    private let viewModel = PremiumViewModel()
    private var hostingController: UIHostingController<PremiumView>?
    @objc var scrollToArchive: Bool = false
    @objc var scrollToPro: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let premiumView = PremiumView(
            viewModel: viewModel,
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            },
            onRestore: { [weak self] in
                self?.viewModel.restore()
            },
            scrollToArchive: scrollToArchive,
            scrollToPro: scrollToPro
        )

        let hosting = UIHostingController(rootView: premiumView)
        hostingController = hosting

        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadProducts()
        viewModel.updateFromAppDelegate()
    }

    @objc func loadedProducts() {
        viewModel.updateFromAppDelegate()
    }

    @objc func finishedTransaction() {
        viewModel.updateFromAppDelegate()
    }
}
