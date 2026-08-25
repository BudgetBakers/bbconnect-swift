# BBConnect Link SDK (Swift)

Mobile Link SDK for iOS (WP4.3, SPM). Design: `DESIGN.md` §9.2.

Pure browser orchestration — **no network calls, no API key in the app**: your
backend creates the connect session with the server SDK
(`connectSessions.create`) and hands the opaque `hostedUrl` to the app.

```swift
import BBConnect

BBConnect.start(
    hostedUrl: hostedUrl,
    callbackURLScheme: "acmewallet"      // custom-scheme return; nil for universal links
) { outcome in
    switch outcome {
    case .success(let sessionId, let connectionId): ...
    case .failure(let sessionId, let error):        ...  // machine-readable reason
    case .cancelled:                                 ...  // incl. dismissed sheet
    }
}

// Universal-link (https) returns arrive via the app, not the browser session:
.onOpenURL { url in BBConnect.handle(url) }
```

- `ASWebAuthenticationSession` — **never an embedded WebView** (banks block
  them; RFC 8252). Bank cookies persist unless `prefersEphemeralSession`.
- Return-link parsing (`BBConnectReturnURL.parse`) is pinned by the shared
  vector set `contract-tests/fixtures/return-url.json` (same vectors as the
  Kotlin Link SDK): `sessionId` + valid `resultCode` mandatory; `connectionId`
  and `error` optional; partner query params ignored.
- **Step 0** of the quickstart (docs/quickstart-ios.md): host
  `apple-app-site-association` for universal links + the Associated Domains
  entitlement, or register a custom URL scheme as the fallback; the returnUrl
  must be registered for the app in the partner portal.

Sample: `Examples/BBConnectSample/SampleApp.swift` (SwiftUI; copy into an
Xcode project with this package added).

## Development

```sh
make build   # swift build (macOS-compilable: platform-guarded API surface)
make test    # swift test — return-URL vectors + outcome mapping
```

XCUITest of the sample app against the live sandbox happy path is deferred
until the test cluster serves the hosted flow (WP4.3 AC note); the parsing
logic is covered by the shared vectors meanwhile.
