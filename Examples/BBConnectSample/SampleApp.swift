// Minimal SwiftUI sample for the BBConnect Link SDK (WP4.3).
//
// Drop into an Xcode iOS app project with the BBConnect package added.
// Quickstart step 0 (docs/quickstart-ios.md): register your return URL —
// either a universal link (apple-app-site-association on your domain +
// Associated Domains entitlement) or a custom scheme (Info.plist URL type).
//
// The hostedUrl comes from YOUR backend: it calls the server SDK's
// `connectSessions.create({ returnUrl })` with the partner API key — the API
// key never ships in the app.

import BBConnect
import SwiftUI

struct ContentView: View {
    @State private var status = "Not connected"

    var body: some View {
        VStack(spacing: 16) {
            Text(status)
            Button("Connect a bank") { startFlow() }
        }
        .padding()
        // Universal-link returns arrive here, not in the browser session:
        .onOpenURL { url in
            BBConnect.handle(url)
        }
    }

    private func startFlow() {
        Task {
            // 1) Ask YOUR backend for a session (never call the partner API
            //    from the app).
            let hostedUrl = try await fetchHostedUrlFromMyBackend()

            // 2) Launch the hosted flow in the system browser session.
            await BBConnect.start(
                hostedUrl: hostedUrl,
                // Custom-scheme return (matches the registered returnUrl,
                // e.g. acmewallet://bb-callback). Use nil + onOpenURL above
                // for https universal links.
                callbackURLScheme: "acmewallet"
            ) { outcome in
                switch outcome {
                case .success(let sessionId, _):
                    // 3) The authoritative result lives server-side: have the
                    //    backend poll GET /v1/connect-sessions/{sessionId}.
                    status = "Connected (session \(sessionId))"
                case .failure(_, let error):
                    status = "Failed: \(error ?? "unknown")"
                case .cancelled:
                    status = "Cancelled"
                }
            }
        }
    }

    private func fetchHostedUrlFromMyBackend() async throws -> URL {
        // Placeholder: GET https://api.my-app.example/bb/connect-session
        URL(string: "https://aisp-connect.test.bbapi.dev/s/example")!
    }
}
