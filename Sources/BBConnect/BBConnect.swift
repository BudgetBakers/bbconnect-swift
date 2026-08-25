// BBConnect.start — hosted connect-flow launcher (DESIGN.md §9.2).
//
// Opens the hostedUrl in ASWebAuthenticationSession — NEVER an embedded
// WebView: banks block WebViews and RFC 8252 mandates the system browser for
// third-party authentication. No network calls, no API key: the partner
// backend creates the session (server SDK `connectSessions.create`) and hands
// the opaque hostedUrl to the app.
//
// Return paths:
//  - Custom scheme (e.g. acmewallet://bb-callback): pass `callbackURLScheme`
//    and the session completes by itself.
//  - Universal link (https app link): iOS delivers the link to the app, not
//    the session — forward it from `onOpenURL` / the AppDelegate to
//    `BBConnect.handle(_:)`.

import AuthenticationServices
import Foundation

public final class BBConnect: NSObject {
    /// The active flow (one at a time — the hosted flow is modal by nature).
    private static var current: BBConnect?

    private let completion: (BBConnectOutcome) -> Void
    private var session: ASWebAuthenticationSession?
    private let presentationAnchor: ASPresentationAnchor?

    private init(
        completion: @escaping (BBConnectOutcome) -> Void,
        presentationAnchor: ASPresentationAnchor?
    ) {
        self.completion = completion
        self.presentationAnchor = presentationAnchor
    }

    /// Launch the hosted connect flow.
    ///
    /// - Parameters:
    ///   - hostedUrl: the opaque URL from `POST /v1/connect-sessions`.
    ///   - callbackURLScheme: the app's custom scheme when the registered
    ///     returnUrl uses one (`acmewallet`); nil for https universal links
    ///     (forward those to ``handle(_:)``).
    ///   - presentationAnchor: window to present from; defaults to the key
    ///     window resolved at presentation time.
    ///   - prefersEphemeralSession: true isolates cookies (forces bank
    ///     re-login); default false.
    ///   - onOutcome: exactly one callback per flow — success, failure or
    ///     cancelled (including the user dismissing the browser sheet).
    @MainActor
    public static func start(
        hostedUrl: URL,
        callbackURLScheme: String? = nil,
        presentationAnchor: ASPresentationAnchor? = nil,
        prefersEphemeralSession: Bool = false,
        onOutcome: @escaping (BBConnectOutcome) -> Void
    ) {
        let flow = BBConnect(completion: onOutcome, presentationAnchor: presentationAnchor)
        current = flow

        let session = ASWebAuthenticationSession(
            url: hostedUrl,
            callbackURLScheme: callbackURLScheme
        ) { callbackURL, error in
            flow.finish(callbackURL: callbackURL, error: error)
        }
        session.prefersEphemeralWebBrowserSession = prefersEphemeralSession
        session.presentationContextProvider = flow
        flow.session = session
        session.start()
    }

    /// Forward a universal-link return URL (from `onOpenURL` /
    /// `application(_:continue:)`) into the active flow. Returns true when the
    /// URL was a BudgetBakers return link and the flow was completed.
    @MainActor
    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        guard let flow = current, let parsed = BBConnectReturnURL.parse(url) else { return false }
        flow.session?.cancel()
        flow.deliver(.from(parsed))
        return true
    }

    /// Cancel the active flow programmatically (delivers `.cancelled`).
    @MainActor
    public static func cancel() {
        guard let flow = current else { return }
        flow.session?.cancel()
        flow.deliver(.cancelled(sessionId: nil))
    }

    private func finish(callbackURL: URL?, error: Error?) {
        if let callbackURL, let parsed = BBConnectReturnURL.parse(callbackURL) {
            deliver(.from(parsed))
            return
        }
        // User dismissed the sheet (canceledLogin) or the callback was not a
        // BB return link — both surface as a cancellation.
        deliver(.cancelled(sessionId: nil))
    }

    private func deliver(_ outcome: BBConnectOutcome) {
        guard Self.current === self else { return } // already completed
        Self.current = nil
        session = nil
        completion(outcome)
    }
}

extension BBConnect: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let anchor = presentationAnchor { return anchor }
        return ASPresentationAnchor()
    }
}
