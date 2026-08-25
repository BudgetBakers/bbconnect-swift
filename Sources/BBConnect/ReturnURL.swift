// Return-link parsing (DESIGN.md §8.2): the hosted flow's final redirect
// appends `connectionId`, `resultCode` (Ok|Error|Cancelled), `sessionId` and
// `error` (on failure) to the partner's returnUrl — an https app/universal
// link or a custom scheme. Pinned by the language-neutral vectors in
// contract-tests/fixtures/return-url.json (shared with the Kotlin Link SDK).

import Foundation

/// Result code of a finished hosted connect flow.
public enum BBConnectResultCode: String, Sendable {
    case ok = "Ok"
    case error = "Error"
    case cancelled = "Cancelled"
}

/// A parsed BudgetBakers return link.
public struct BBConnectReturnURL: Equatable, Sendable {
    /// The connect session this result belongs to (opaque — never parse).
    public let sessionId: String
    /// Present when a connection materialized (resultCode == .ok).
    public let connectionId: String?
    public let resultCode: BBConnectResultCode
    /// Machine-readable failure reason (present on resultCode == .error).
    public let error: String?

    /// Parse a candidate URL. Returns nil when the URL is not a BudgetBakers
    /// return link: `sessionId` and a valid `resultCode` are mandatory, any
    /// scheme/host/path is accepted (https app links and custom schemes),
    /// and unrelated partner query params are ignored.
    public static func parse(_ url: URL) -> BBConnectReturnURL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return nil }

        var params: [String: String] = [:]
        for item in items {
            // First occurrence wins; percent-decoding is done by URLComponents.
            if params[item.name] == nil { params[item.name] = item.value }
        }

        guard let sessionId = params["sessionId"], !sessionId.isEmpty,
              let rawResult = params["resultCode"],
              let resultCode = BBConnectResultCode(rawValue: rawResult)
        else { return nil }

        return BBConnectReturnURL(
            sessionId: sessionId,
            connectionId: params["connectionId"],
            resultCode: resultCode,
            error: params["error"]
        )
    }
}

/// Outcome delivered to the partner app's callbacks.
public enum BBConnectOutcome: Equatable, Sendable {
    /// The user connected a bank; poll `GET /v1/connect-sessions/{sessionId}`
    /// server-side for the authoritative state.
    case success(sessionId: String, connectionId: String?)
    /// The flow failed (`error` is the machine-readable reason).
    case failure(sessionId: String, error: String?)
    /// The user cancelled — in the flow, or by dismissing the browser sheet
    /// (sessionId is nil in the dismissal case).
    case cancelled(sessionId: String?)

    /// Map a parsed return link onto the outcome callbacks.
    public static func from(_ returnURL: BBConnectReturnURL) -> BBConnectOutcome {
        switch returnURL.resultCode {
        case .ok:
            return .success(sessionId: returnURL.sessionId, connectionId: returnURL.connectionId)
        case .error:
            return .failure(sessionId: returnURL.sessionId, error: returnURL.error)
        case .cancelled:
            return .cancelled(sessionId: returnURL.sessionId)
        }
    }
}
