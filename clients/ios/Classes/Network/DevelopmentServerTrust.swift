// DevelopmentServerTrust.swift: lets a simulator build pointed at a local NewsBlur stack (the custom_domain preference
// set to https://localhost:<port>, see NewsBlurAppDelegate.m url) accept that stack's self-signed certificate, for the
// AFNetworking manager and the URLSession-based view models alike. The gate is targetEnvironment(simulator), not DEBUG:
// NewsBlur.xcodeproj sets no SWIFT_ACTIVE_COMPILATION_CONDITIONS for the app, so `#if DEBUG` is never true there (the
// socket client's Debug trust in NewsBlurSocketClient.swift is dead for the same reason). Device and Mac builds keep
// full certificate validation: the host check always answers no and the session is URLSession.shared.
import Foundation

@objcMembers final class DevelopmentServerTrust: NSObject, URLSessionDelegate {
    static let shared = DevelopmentServerTrust()

    /// Whether `host` names a local development server whose certificate may be self-signed or expired.
    static func allowsUntrustedCertificates(forHost host: String?) -> Bool {
        #if targetEnvironment(simulator)
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return host == "localhost" || host == "127.0.0.1" || host.hasSuffix(".localhost")
        #else
        return false
        #endif
    }

    /// The session Swift view models use for API calls. Simulator builds trust local development servers; otherwise
    /// it is URLSession.shared, which the view models used before.
    static let session: URLSession = {
        #if targetEnvironment(simulator)
        return URLSession(configuration: .default, delegate: DevelopmentServerTrust.shared, delegateQueue: nil)
        #else
        return URLSession.shared
        #endif
    }()

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           Self.allowsUntrustedCertificates(forHost: challenge.protectionSpace.host),
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
