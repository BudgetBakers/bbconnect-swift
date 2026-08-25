// Return-URL parsing pinned by the language-neutral vector set shared with
// the Kotlin Link SDK: contract-tests/fixtures/return-url.json.

import Foundation
import XCTest

@testable import BBConnect

private struct Fixture: Decodable {
    let vectors: [Vector]
}

private struct Vector: Decodable {
    let name: String
    let url: String
    let expect: Expect
}

private struct Expect: Decodable {
    let invalid: Bool?
    let sessionId: String?
    let connectionId: String?
    let resultCode: String?
    let error: String?
}

final class ReturnURLTests: XCTestCase {
    private func loadVectors() throws -> [Vector] {
        // Tests/BBConnectTests/ → sdks/swift-link → repo root.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // BBConnectTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // swift-link
            .deletingLastPathComponent()  // sdks
            .deletingLastPathComponent()  // repo root
        let file = root.appendingPathComponent("contract-tests/fixtures/return-url.json")
        let data = try Data(contentsOf: file)
        return try JSONDecoder().decode(Fixture.self, from: data).vectors
    }

    func testAllVectors() throws {
        let vectors = try loadVectors()
        XCTAssertGreaterThanOrEqual(vectors.count, 10)

        for vector in vectors {
            guard let url = URL(string: vector.url) else {
                XCTFail("\(vector.name): unparseable URL")
                continue
            }
            let parsed = BBConnectReturnURL.parse(url)
            if vector.expect.invalid == true {
                XCTAssertNil(parsed, "\(vector.name): expected invalid, got \(String(describing: parsed))")
                continue
            }
            guard let parsed else {
                XCTFail("\(vector.name): expected a parsed return URL, got nil")
                continue
            }
            XCTAssertEqual(parsed.sessionId, vector.expect.sessionId, vector.name)
            XCTAssertEqual(parsed.connectionId, vector.expect.connectionId, vector.name)
            XCTAssertEqual(parsed.resultCode.rawValue, vector.expect.resultCode, vector.name)
            XCTAssertEqual(parsed.error, vector.expect.error, vector.name)
        }
    }

    func testOutcomeMapping() {
        let ok = BBConnectReturnURL(
            sessionId: "cs_1", connectionId: "conn_1", resultCode: .ok, error: nil)
        XCTAssertEqual(
            BBConnectOutcome.from(ok), .success(sessionId: "cs_1", connectionId: "conn_1"))

        let failed = BBConnectReturnURL(
            sessionId: "cs_1", connectionId: nil, resultCode: .error, error: "authentication_failed")
        XCTAssertEqual(
            BBConnectOutcome.from(failed),
            .failure(sessionId: "cs_1", error: "authentication_failed"))

        let cancelled = BBConnectReturnURL(
            sessionId: "cs_1", connectionId: nil, resultCode: .cancelled, error: nil)
        XCTAssertEqual(BBConnectOutcome.from(cancelled), .cancelled(sessionId: "cs_1"))
    }
}
