// OnboardingAccountViewController.swift owns native Apple and browser-based Google authentication.
import AuthenticationServices
import CryptoKit
import SwiftUI

@objc final class OnboardingAccountViewController: LoginViewController {
    private var account = OnboardingAccountModel()
    private var pendingAppleRevocationNotice = false

    override func loadView() {
        let host = UIHostingController(rootView: OnboardingAccountView(model: account))
        view = UIView()
        setupLoginBackground()
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
        account.controller = self
    }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {
        setLoginBackgroundActive(true)
        account.lastUsed = UserDefaults.standard.string(forKey: "last_auth_method")
        if !account.needsUsername && !account.needsLink { account.signup = account.lastUsed == nil }
    }
    override func viewDidAppear(_ animated: Bool) {
        if pendingAppleRevocationNotice { showAppleRevocationNoticeWhenVisible() }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews() }
    override func viewDidDisappear(_ animated: Bool) { setLoginBackgroundActive(false) }

    func showAppleRevocationNoticeWhenVisible() {
        guard viewIfLoaded?.window != nil else {
            pendingAppleRevocationNotice = true
            return
        }
        pendingAppleRevocationNotice = false
        let alert = UIAlertController(title: "Finish disconnecting Apple",
                                      message: "Your NewsBlur account has been deleted. Remove NewsBlur from Sign in with Apple in your Apple Account settings to finish disconnecting it.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "View instructions", style: .default) { _ in
            UIApplication.shared.open(URL(string: "https://support.apple.com/en-us/102571")!)
        })
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        present(alert, animated: true)
    }
}

@MainActor final class OnboardingAccountModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, ASWebAuthenticationPresentationContextProviding {
    @Published var signup = UserDefaults.standard.string(forKey: "last_auth_method") == nil
    @Published var email = ""
    @Published var username = ""
    @Published var password = ""
    @Published var lastUsed = UserDefaults.standard.string(forKey: "last_auth_method")
    @Published var busy = false
    @Published var message: String?
    @Published var needsUsername = false
    @Published var needsLink = false
    weak var controller: UIViewController?
    private var provider = ""
    private var verifier = ""
    private var state = ""
    private var ticket = ""
    private var webSession: ASWebAuthenticationSession?
    private var appleController: ASAuthorizationController?
    var deletionSession: AccountDeletionSession?
    var onReauthenticated: ((String) -> Void)?

    func emailSignIn() {
        guard !busy else { return }
        busy = true
        message = nil
        Task {
            defer { busy = false }
            do {
                if needsUsername || needsLink { try await complete() }
                else {
                    guard !username.isEmpty, !password.isEmpty, !signup || !email.isEmpty else {
                        throw OnboardingAPI.error("Fill in the fields to continue.")
                    }
                    _ = try await OnboardingAPI.request(signup ? "/api/signup" : "/api/login", body: [
                        "username": username, "password": password, "email": email, "api": "1"
                    ])
                    finish(method: "email", created: signup)
                }
            } catch { message = error.localizedDescription }
        }
    }

    func social(_ name: String) {
        guard !busy else { return }
        busy = true
        message = nil
        Task {
            do {
                let result = try await prepareSocial(name)
                if name == "apple" {
                    let request = ASAuthorizationAppleIDProvider().createRequest()
                    request.requestedScopes = [.email]
                    request.nonce = result["nonce"] as? String
                    let authorization = ASAuthorizationController(authorizationRequests: [request])
                    authorization.delegate = self
                    authorization.presentationContextProvider = self
                    appleController = authorization
                    authorization.performRequests()
                } else {
                    guard let address = result["url"] as? String, let url = URL(string: address) else { throw OnboardingAPI.error("Unable to start Google sign-in.") }
                    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "newsblur-auth") { [weak self] url, error in
                        Task { @MainActor in
                            guard let self else { return }
                            defer { self.busy = false; self.webSession = nil }
                            guard let url else {
                                if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin { self.message = error?.localizedDescription }
                                return
                            }
                            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                            guard url.scheme == "newsblur-auth", url.host == "complete",
                                  let ticket = items.first(where: { $0.name == "ticket" })?.value else {
                                self.message = items.first(where: { $0.name == "error" })?.value ?? "Google sign-in failed. Please try again."
                                return
                            }
                            self.ticket = ticket
                            do { try await self.complete() } catch { self.message = error.localizedDescription }
                        }
                    }
                    session.presentationContextProvider = self
                    session.prefersEphemeralWebBrowserSession = deletionSession != nil
                    webSession = session
                    if !session.start() { throw OnboardingAPI.error("Unable to open Google sign-in. Please try again.") }
                }
            } catch { message = error.localizedDescription; busy = false }
        }
    }

    func prepareSocial(_ name: String) async throws -> [String: Any] {
        try deletionSession?.validate()
        provider = name
        needsLink = false
        needsUsername = false
        // OnboardingAccountViewController.swift binds the callback ticket to this app session.
        verifier = UUID().uuidString + UUID().uuidString
        let challenge = SHA256.hash(data: Data(verifier.utf8)).map { String(format: "%02x", $0) }.joined()
        var body = ["provider": name, "challenge": challenge]
        if deletionSession != nil { body["purpose"] = "delete_account" }
        let result = try await OnboardingAPI.request("/api/social/start", body: body)
        try deletionSession?.validate()
        guard let state = result["state"] as? String else { throw OnboardingAPI.error("Unable to start sign-in.") }
        self.state = state
        return result
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            defer { busy = false; appleController = nil }
            do {
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    throw OnboardingAPI.error("Apple did not return an identity token.")
                }
                ticket = try await exchangeAppleCredential(identityToken: credential.identityToken, authorizationCode: credential.authorizationCode)
                try await complete()
            } catch { message = error.localizedDescription }
        }
    }

    func exchangeAppleCredential(identityToken: Data?, authorizationCode: Data?) async throws -> String {
        try deletionSession?.validate()
        guard let identityToken, let token = String(data: identityToken, encoding: .utf8) else {
            throw OnboardingAPI.error("Apple did not return an identity token.")
        }
        var body = ["state": state, "id_token": token]
        // OnboardingAccountViewController.swift supplies Apple's one-time code for revocation only during account deletion.
        if deletionSession != nil, let authorizationCode,
           let code = String(data: authorizationCode, encoding: .utf8), !code.isEmpty {
            body["authorization_code"] = code
        }
        let result = try await OnboardingAPI.request("/api/social/apple", body: body)
        try deletionSession?.validate()
        guard let ticket = result["ticket"] as? String else { throw OnboardingAPI.error("Apple sign-in failed.") }
        return ticket
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        busy = false
        appleController = nil
        if (error as? ASAuthorizationError)?.code != .canceled { message = error.localizedDescription }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { self.controller?.view.window ?? ASPresentationAnchor() }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { controller?.view.window ?? ASPresentationAnchor() }

    func complete(ticket: String) async throws {
        self.ticket = ticket
        try await complete()
    }

    func connectExistingAccount() {
        guard needsUsername, !busy else { return }
        needsUsername = false
        needsLink = true
        password = ""
        message = nil
    }

    func createNewAccountInstead() {
        guard needsLink, !busy else { return }
        needsLink = false
        needsUsername = true
        username = ""
        password = ""
        message = nil
    }

    private func complete() async throws {
        try deletionSession?.validate()
        var body = ["ticket": ticket, "verifier": verifier,
                    "username": needsUsername || needsLink ? username : "", "password": needsLink ? password : ""]
        if needsLink { body["action"] = "link" }
        let result = try await OnboardingAPI.request("/api/social/complete", body: body)
        if let deletionSession {
            try deletionSession.validate()
            guard let token = result["delete_token"] as? String, !token.isEmpty else {
                throw OnboardingAPI.error("Unable to verify your account. Please try again.")
            }
            self.ticket = ""
            onReauthenticated?(token)
            return
        }
        if result["link_required"] as? Bool == true || result["username_required"] as? Bool == true {
            ticket = result["ticket"] as? String ?? ""
            needsLink = result["link_required"] as? Bool == true
            needsUsername = result["username_required"] as? Bool == true
            message = result["message"] as? String
            password = ""
            return
        }
        finish(method: provider, created: result["created"] as? Bool == true)
    }

    func cancelAuthentication() {
        deletionSession?.cancelled = true
        webSession?.cancel()
        webSession = nil
        appleController = nil
        busy = false
        cancelContinuation()
    }

    func cancelContinuation() {
        needsLink = false
        needsUsername = false
        ticket = ""
        password = ""
        message = nil
    }

    private func finish(method: String, created: Bool) {
        UserDefaults.standard.set(method, forKey: "last_auth_method")
        lastUsed = method
        password = ""
        cancelContinuation()
        NewsBlurAppDelegate.shared()?.finishAuthentication()
        controller?.dismiss(animated: true)
    }
}

// OnboardingAccountViewController.swift binds deletion to the existing authenticated browsing session.
@MainActor final class AccountDeletionSession {
    let username = NewsBlurAppDelegate.shared()?.activeUsername
    let server = NewsBlurAppDelegate.shared()?.url
    private let generation = NewsBlurAppDelegate.shared()?.feedsViewController.feedListAccountGeneration
    var cancelled = false

    func validate() throws {
        let app = NewsBlurAppDelegate.shared()
        guard !cancelled, let username, !username.isEmpty, username == app?.activeUsername,
              server == app?.url, generation == app?.feedsViewController.feedListAccountGeneration else {
            throw OnboardingAPI.error("Your account session changed. Close this dialog and try again.")
        }
    }
}

@MainActor final class AccountDeletionModel: ObservableObject {
    @Published var providers: [String] = []
    @Published var loading = true
    @Published var deleting = false
    @Published var confirmation = ""
    @Published var message: String?
    @Published private(set) var isVerified = false
    @Published private(set) var useLegacyDeletion = false
    let authentication = OnboardingAccountModel()
    let session = AccountDeletionSession()
    private var deleteToken: String?
    private let onDeleted: (Bool) -> Void
    var onLegacy: (() -> Void)?

    init(onDeleted: @escaping (Bool) -> Void) {
        self.onDeleted = onDeleted
        authentication.deletionSession = session
        authentication.onReauthenticated = { [weak self] token in
            self?.deleteToken = token
            self?.isVerified = true
            self?.message = nil
        }
    }

    func load() async {
        loading = true
        message = nil
        defer { loading = false }
        do {
            try session.validate()
            guard let server = session.server, let url = URL(string: server + "/api/social/account") else {
                throw OnboardingAPI.error("Invalid server address.")
            }
            let (data, response) = try await OnboardingAPI.session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
            try session.validate()
            guard let http = response as? HTTPURLResponse else { throw OnboardingAPI.error("Unable to load your account. Please try again.") }
            if http.statusCode == 404 || ((200...299).contains(http.statusCode) && http.mimeType == "text/html") {
                useLegacyDeletion = true
            } else {
                guard (200...299).contains(http.statusCode),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["code"] as? Int == 1, let linked = json["providers"] as? [String] else {
                    throw OnboardingAPI.error("Unable to load your account. Please try again.")
                }
                providers = linked.contains("apple") ? ["apple"] : linked.filter { $0 == "google" }
                useLegacyDeletion = providers.isEmpty
            }
            if useLegacyDeletion { onLegacy?() }
        } catch { message = error.localizedDescription }
    }

    func deleteAccount() async {
        guard !deleting, isVerified, let deleteToken, confirmation == "Delete" else { return }
        deleting = true
        message = nil
        defer { deleting = false }
        do {
            try session.validate()
            let result = try await OnboardingAPI.request("/api/social/delete_account", body: ["delete_token": deleteToken, "confirm": "Delete"])
            try session.validate()
            self.deleteToken = nil
            isVerified = false
            onDeleted(result["apple_revocation_required"] as? Bool == true)
        } catch {
            self.deleteToken = nil
            isVerified = false
            confirmation = ""
            message = error.localizedDescription
        }
    }

    func cancel() {
        session.cancelled = true
        deleteToken = nil
        isVerified = false
        authentication.cancelAuthentication()
    }
}

@objc final class AccountDeletionController: UIViewController {
    private(set) var model: AccountDeletionModel!

    @objc(presentFromController:) static func present(from controller: UIViewController) {
        let deletion = AccountDeletionController()
        deletion.modalPresentationStyle = .formSheet
        deletion.preferredContentSize = CGSize(width: 520, height: 560)
        deletion.isModalInPresentation = true
        controller.present(deletion, animated: true)
    }

    override func loadView() {
        model = AccountDeletionModel { [weak self] needsAppleRevocation in
            guard let self else { return }
            self.dismiss(animated: true) {
                guard (try? self.model.session.validate()) != nil, let app = NewsBlurAppDelegate.shared() else { return }
                // OnboardingAccountViewController.swift invalidates queued account work before returning to login after deletion.
                app.cancelOfflineQueue()
                app.feedsViewController.resetForAccountChange()
                app.feedDetailViewController.resetForAccountChange()
                app.activeUsername = nil
                app.activeStory = nil
                UserDefaults.standard.removeObject(forKey: "active_username")
                app.showLogin()
                if needsAppleRevocation {
                    (app.loginViewController as? OnboardingAccountViewController)?.showAppleRevocationNoticeWhenVisible()
                }
            }
        }
        model.onLegacy = { [weak self] in
            guard let self, let server = self.model.session.server else { return }
            self.dismiss(animated: true) {
                guard (try? self.model.session.validate()) != nil, let url = URL(string: server + "/profile/delete_account") else { return }
                NewsBlurAppDelegate.shared()?.show(inAppBrowser: url, withCustomTitle: "Delete Account", fromSender: nil)
            }
        }
        model.authentication.controller = self
        let host = UIHostingController(rootView: AccountDeletionView(model: model, cancel: { [weak self] in
            self?.model.cancel()
            self?.dismiss(animated: true)
        }))
        view = UIView()
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }
}

private struct AccountDeletionView: View {
    @ObservedObject var model: AccountDeletionModel
    @ObservedObject var authentication: OnboardingAccountModel
    let cancel: () -> Void

    init(model: AccountDeletionModel, cancel: @escaping () -> Void) {
        self.model = model
        self.authentication = model.authentication
        self.cancel = cancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Delete account").font(.title2.weight(.semibold))
                Spacer()
                Button("Cancel", action: cancel).disabled(model.deleting)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: model.isVerified ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.minus")
                        .font(.system(size: 42, weight: .light)).foregroundStyle(DiscoverColors.textSecondary).accessibilityHidden(true)
                    Text(model.isVerified ? "Your identity is verified" : "Verify your identity first")
                        .font(.title3.weight(.semibold))
                    Text("Deleting your account permanently removes your feeds, saved stories, and account data. This cannot be undone.")
                        .foregroundStyle(DiscoverColors.textSecondary)
                    if model.loading { ProgressView("Loading account…").frame(maxWidth: .infinity).padding() }
                    else if model.isVerified {
                        Text("Type Delete to permanently delete \(model.session.username ?? "your account").").font(.subheadline)
                        TextField("Delete", text: $model.confirmation)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(14).background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("account-deletion.confirmation")
                        Button(role: .destructive) { Task { await model.deleteAccount() } } label: {
                            Text("Permanently delete account").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).tint(.red)
                            .disabled(model.confirmation != "Delete" || model.deleting)
                            .accessibilityIdentifier("account-deletion.submit")
                        if model.deleting { ProgressView("Deleting account…") }
                    } else {
                        ForEach(model.providers, id: \.self) { provider in
                            Button { authentication.social(provider) } label: {
                                HStack(spacing: 12) {
                                    if provider == "apple" { Image(systemName: "apple.logo").font(.title2) }
                                    else { Image("google-signin").resizable().frame(width: 22, height: 22) }
                                    Text(provider == "apple" ? "Verify with Apple" : "Verify with Google").fontWeight(.semibold)
                                    Spacer()
                                }.padding(16).background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).disabled(authentication.busy)
                        }
                        if authentication.busy { ProgressView("Verifying your identity…") }
                        if model.providers.isEmpty && model.message != nil {
                            Button("Try again") { Task { await model.load() } }
                        }
                    }
                    if let message = model.message ?? authentication.message {
                        Text(message).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("account-deletion.error")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(28).foregroundStyle(DiscoverColors.textPrimary)
            .background(DiscoverColors.background.ignoresSafeArea())
            .task { await model.load() }
    }
}

private struct OnboardingAccountView: View {
    @ObservedObject var model: OnboardingAccountModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let gold = Color(red: 251 / 255, green: 219 / 255, blue: 155 / 255)
    private var continuation: Bool { model.needsUsername || model.needsLink }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image(uiImage: UIImage(named: "logo_512.png") ?? UIImage(systemName: "sun.max.fill")!)
                            .resizable().scaledToFit().frame(width: 120, height: 120)
                            .shadow(color: gold.opacity(0.4), radius: 30)
                            .accessibilityHidden(true)
                        Text("NewsBlur")
                            .font(.custom("GothamNarrow-Medium", size: 38, relativeTo: .largeTitle))
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        Text("A personal news reader bringing\npeople together to talk about the world.")
                            .font(.custom("ChronicleSSm-BookItalic", size: 16, relativeTo: .subheadline))
                            .multilineTextAlignment(.center).foregroundColor(gold)
                            .shadow(color: .black.opacity(0.3), radius: 0, y: 1)
                    }.padding(.top, 16)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(continuation ? (model.needsLink ? "Connect your account" : "Choose your username") : (model.signup ? "Create an account" : "Welcome back"))
                            .font(.custom("GothamNarrow-Medium", size: 24, relativeTo: .title2))
                        if !continuation {
                            VStack(alignment: .trailing, spacing: 6) {
                                SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
                                    .signInWithAppleButtonStyle(.white).frame(height: 50)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                                    .overlay { Button { model.social("apple") } label: { Color.clear.contentShape(Rectangle()) }.accessibilityLabel("Sign in with Apple") }
                                if model.lastUsed == "apple" { badge }
                            }
                            VStack(alignment: .trailing, spacing: 6) {
                                Button { model.social("google") } label: {
                                    HStack(spacing: 12) { Image("google-signin").resizable().frame(width: 20, height: 20); Text("Sign in with Google").font(.system(size: 17, weight: .medium)) }.frame(maxWidth: .infinity).frame(height: 50)
                                        .foregroundColor(.black).background(.white).clipShape(RoundedRectangle(cornerRadius: 7))
                                }
                                if model.lastUsed == "google" { badge }
                            }
                            HStack { Rectangle().frame(height: 1); Text("or").font(.caption); Rectangle().frame(height: 1) }.foregroundColor(.white.opacity(0.35))
                        }
                        if model.signup && !continuation {
                            field("Email", text: $model.email).keyboardType(.emailAddress).textContentType(.emailAddress)
                        }
                        if model.needsLink {
                            Text("Enter your existing NewsBlur username or email and NewsBlur password.")
                                .font(.subheadline)
                        }
                        field(model.needsUsername || (model.signup && !continuation) ? "Username" : "Username or email", text: $model.username).textContentType(.username)
                        if !model.needsUsername {
                            SecureField(model.needsLink ? "NewsBlur password" : "Password", text: $model.password,
                                        prompt: Text(model.needsLink ? "NewsBlur password" : "Password").foregroundColor(.white.opacity(0.65))).textContentType(model.signup && !continuation ? .newPassword : .password)
                                .padding(15).background(.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if !continuation && model.lastUsed == "email" { HStack { Spacer(); badge } }
                        if let message = model.message { Text(message).font(.subheadline).foregroundColor(Color(red: 1, green: 0.84, blue: 0.60)).fixedSize(horizontal: false, vertical: true) }
                        Button(continuation ? "Continue" : model.signup ? "Create account" : "Sign in") { model.emailSignIn() }
                            .buttonStyle(OnboardingAccountButtonStyle())
                        if model.busy { ProgressView("Signing in…").tint(.white).frame(maxWidth: .infinity) }
                        if model.needsUsername {
                            Button("Connect an existing account") { model.connectExistingAccount() }
                                .accessibilityIdentifier("onboarding.connect-existing-account")
                        }
                        if model.needsLink {
                            Button("Create a new account instead") { model.createNewAccountInstead() }
                                .accessibilityIdentifier("onboarding.create-new-account")
                        }
                        if continuation { Button("Use another sign-in method") { model.cancelContinuation() } }
                        if model.needsLink || (!continuation && !model.signup) {
                            Link("Forgot your password?", destination: URL(string: (NewsBlurAppDelegate.shared()?.url ?? "https://www.newsblur.com") + "/profile/forgot_password")!)
                        }
                    }.padding(22)
                        .background {
                            if reduceTransparency { Color(red: 0.12, green: 0.16, blue: 0.16) }
                            else { OnboardingAccountGlass() }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                        .disabled(model.busy)
                    if !continuation {
                        Button(model.signup ? "Already have an account? Sign in" : "New to NewsBlur? Create an account") {
                            model.signup.toggle(); model.message = nil
                        }.disabled(model.busy)
                    }
                }.padding(24).frame(maxWidth: 520).frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }.font(.custom("WhitneySSm-Book", size: 16, relativeTo: .body)).foregroundColor(.white).tint(gold).preferredColorScheme(.dark)
    }
    private var badge: some View { Text("Last used").font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3).background(.white.opacity(0.15)).clipShape(Capsule()) }
    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text, prompt: Text(title).foregroundColor(.white.opacity(0.65))).textInputAutocapitalization(.never).autocorrectionDisabled()
            .padding(15).background(.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// OnboardingAccountViewController.swift preserves the original UIKit glass treatment.
private struct OnboardingAccountGlass: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    }
    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}

private struct OnboardingAccountButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("GothamNarrow-Medium", size: 17, relativeTo: .headline))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(LinearGradient(colors: [Color(red: 217 / 255, green: 166 / 255, blue: 33 / 255),
                                                Color(red: 184 / 255, green: 137 / 255, blue: 11 / 255)],
                                       startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
    }
}
