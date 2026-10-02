// OnboardingAccountViewController.swift owns native Apple and browser-based Google authentication.
import AuthenticationServices
import CryptoKit
import SwiftUI

@objc final class OnboardingAccountViewController: LoginViewController {
    private var account = OnboardingAccountModel()

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
    override func viewDidAppear(_ animated: Bool) {}
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews() }
    override func viewDidDisappear(_ animated: Bool) { setLoginBackgroundActive(false) }
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
        provider = name
        needsLink = false
        needsUsername = false
        // OnboardingAccountViewController.swift binds the callback ticket to this app session.
        verifier = UUID().uuidString + UUID().uuidString
        let challenge = SHA256.hash(data: Data(verifier.utf8)).map { String(format: "%02x", $0) }.joined()
        Task {
            do {
                let result = try await OnboardingAPI.request("/api/social/start", body: ["provider": name, "challenge": challenge])
                guard let state = result["state"] as? String else { throw OnboardingAPI.error("Unable to start sign-in.") }
                self.state = state
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
                    webSession = session
                    if !session.start() { throw OnboardingAPI.error("Unable to open Google sign-in. Please try again.") }
                }
            } catch { message = error.localizedDescription; busy = false }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            defer { busy = false; appleController = nil }
            do {
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else { throw OnboardingAPI.error("Apple did not return an identity token.") }
                let result = try await OnboardingAPI.request("/api/social/apple", body: ["state": state, "id_token": token])
                guard let ticket = result["ticket"] as? String else { throw OnboardingAPI.error("Apple sign-in failed.") }
                self.ticket = ticket
                try await complete()
            } catch { message = error.localizedDescription }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        busy = false
        appleController = nil
        if (error as? ASAuthorizationError)?.code != .canceled { message = error.localizedDescription }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { self.controller?.view.window ?? ASPresentationAnchor() }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { controller?.view.window ?? ASPresentationAnchor() }

    private func complete() async throws {
        let result = try await OnboardingAPI.request("/api/social/complete", body: ["ticket": ticket, "verifier": verifier,
            "username": needsUsername || needsLink ? username : "", "password": needsLink ? password : ""])
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
                        field(model.signup || model.needsUsername ? "Username" : "Username or email", text: $model.username).textContentType(.username)
                        if !model.needsUsername {
                            SecureField("Password", text: $model.password, prompt: Text("Password").foregroundColor(.white.opacity(0.65))).textContentType(model.signup && !continuation ? .newPassword : .password)
                                .padding(15).background(.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if !continuation && model.lastUsed == "email" { HStack { Spacer(); badge } }
                        if let message = model.message { Text(message).font(.subheadline).foregroundColor(Color(red: 1, green: 0.84, blue: 0.60)).fixedSize(horizontal: false, vertical: true) }
                        Button(continuation ? "Continue" : model.signup ? "Create account" : "Sign in") { model.emailSignIn() }
                            .buttonStyle(OnboardingAccountButtonStyle())
                        if model.busy { ProgressView("Signing in…").tint(.white).frame(maxWidth: .infinity) }
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
