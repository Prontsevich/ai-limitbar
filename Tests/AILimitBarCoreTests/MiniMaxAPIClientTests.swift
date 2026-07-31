import Foundation
import XCTest
@testable import AILimitBarCore

final class MiniMaxAPIClientTests: XCTestCase {
    private let observedAt = Date(timeIntervalSince1970: 1_893_456_000)

    override func tearDown() {
        MiniMaxURLProtocolStub.clearHandler()
        super.tearDown()
    }

    func testFixedGlobalRequestMapsIndependentReviewedWindows() async throws {
        let recorder = MiniMaxRequestRecorder()
        let data = try fixture("synthetic-success")
        MiniMaxURLProtocolStub.setHandler { request, stub in
            recorder.append(request)
            stub.respond(statusCode: 200, data: data)
        }

        let result = try await makeClient().fetchTokenPlanCapacity(
            credential: try credential("synthetic-subscription-key")
        )

        XCTAssertEqual(recorder.requests.count, 1)
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.url, URLSessionMiniMaxAPIClient.remainsURL)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer synthetic-subscription-key"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.url?.query)
        XCTAssertFalse(request.httpShouldHandleCookies)

        XCTAssertEqual(result.observedAt, observedAt)
        XCTAssertEqual(result.metrics.map(\.metricID), [
            "row-a.current", "row-a.weekly", "row-b.current", "row-b.weekly"
        ])
        XCTAssertEqual(result.diagnostics, [.init(code: .unknownModelRow)])

        let currentA = try metric("row-a.current", in: result)
        XCTAssertEqual(currentA.window.kind, .rolling)
        XCTAssertEqual(currentA.availability, .known)
        XCTAssertEqual(currentA.values?.remaining?.value, 7)
        XCTAssertEqual(currentA.values?.remaining?.origin, .derived)
        XCTAssertEqual(currentA.accountContextID, "synthetic-team")
        XCTAssertEqual(currentA.unit, CapacityUnit(
            kind: .providerDefined,
            providerUnitID: MiniMaxProviderContract.providerUnitID
        ))

        let weeklyA = try metric("row-a.weekly", in: result)
        XCTAssertEqual(weeklyA.window.kind, .fixed)
        XCTAssertEqual(weeklyA.availability, .known)
        XCTAssertEqual(weeklyA.values?.remaining?.value, 0)

        let currentB = try metric("row-b.current", in: result)
        XCTAssertEqual(currentB.availability, .unlimited)
        XCTAssertNil(currentB.values?.limit)
        XCTAssertNil(currentB.values?.remaining)

        let weeklyB = try metric("row-b.weekly", in: result)
        XCTAssertEqual(weeklyB.conditions, [.boost])
        XCTAssertEqual(weeklyB.values?.remaining?.value, 18)
    }

    func testBusinessStatusIsValidatedBeforeRowsAndProjectsSanitizedErrors() async throws {
        installJSON(
            #"{"base_resp":{"status_code":1004,"status_msg":""},"model_remains":null}"#
        )
        await assertError(.authenticationFailure)

        installJSON(
            #"{"base_resp":{"status_code":1004,"status_msg":""},"model_remains":{"unexpected":"shape"}}"#
        )
        await assertError(.authenticationFailure)

        installJSON(
            #"{"base_resp":{"status_code":2045,"status_msg":""},"model_remains":null}"#,
            headers: ["Retry-After": "17"]
        )
        await assertError(.throttled(retryAfter: .seconds(17)))

        installJSON(
            #"{"base_resp":{"status_code":2045,"status_msg":""},"model_remains":["malformed"]}"#,
            headers: ["Retry-After": "17"]
        )
        await assertError(.throttled(retryAfter: .seconds(17)))

        installJSON(
            #"{"base_resp":{"status_code":2062,"status_msg":""},"model_remains":null}"#
        )
        await assertError(.unavailableSubscription)

        installJSON(
            #"{"base_resp":{"status_code":2056,"status_msg":""},"model_remains":null}"#
        )
        await assertError(.usageExhausted)
    }

    func testHTTPRetryAfterAndTransportErrorsRemainDistinct() async throws {
        MiniMaxURLProtocolStub.setHandler { _, stub in
            stub.respond(
                statusCode: 429,
                headers: ["Retry-After": "Wed, 01 Jan 2031 00:00:00 GMT"],
                data: Data()
            )
        }
        await assertError(
            .throttled(retryAfter: .date(Date(timeIntervalSince1970: 1_924_992_000)))
        )

        MiniMaxURLProtocolStub.setHandler { _, stub in
            stub.fail(with: URLError(.notConnectedToInternet))
        }
        await assertError(.transportFailure)
    }

    func testResponseLimitIsStreamingAndDoesNotMaskHTTPError() async throws {
        MiniMaxURLProtocolStub.setHandler { _, stub in
            stub.respond(
                statusCode: 429,
                headers: ["Retry-After": "17"],
                data: Data(repeating: 0, count: 4_096)
            )
        }
        await assertError(
            .throttled(retryAfter: .seconds(17)),
            client: makeClient(responseLimit: 1)
        )

        MiniMaxURLProtocolStub.setHandler { _, stub in
            stub.respond(statusCode: 200, data: Data(repeating: 0, count: 2))
        }
        await assertError(.responseTooLarge, client: makeClient(responseLimit: 1))
    }

    func testMalformedAndUnknownFieldsFailClosed() async throws {
        installJSON(
            #"{"base_resp":{"status_code":0,"status_msg":""},"model_remains":[]}"#
        )
        await assertError(.decodingFailure)

        installJSON(
            #"{"base_resp":{"status_code":0,"status_msg":"","unexpected":"value"},"model_remains":[]}"#
        )
        await assertError(.decodingFailure)

        installJSON(
            #"{"base_resp":{"status_code":0,"status_msg":""},"model_remains":[{"model_name":"synthetic-row-a"}]}"#
        )
        await assertError(.decodingFailure)
    }

    func testTimeoutAndCancellationRemainDistinct() async throws {
        MiniMaxURLProtocolStub.setHandler { _, _ in }
        await assertError(.timedOut, client: makeClient(timeout: 0.01))

        MiniMaxURLProtocolStub.setHandler { _, _ in }
        let client = makeClient(timeout: 5)
        let subscriptionKey = try credential("synthetic-subscription-key")
        let task = Task {
            try await client.fetchTokenPlanCapacity(credential: subscriptionKey)
        }
        try await Task.sleep(for: .milliseconds(20))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation.")
        } catch {
            XCTAssertEqual(error as? MiniMaxAPIClientError, .cancelled)
        }
    }

    func testCredentialWrapperRejectsWrongSlotAndDoesNotRenderSecret() throws {
        let secret = try CredentialSecret("synthetic-secret")
        let valid = try MiniMaxSubscriptionKey(
            slot: credentialSlot(),
            secret: secret
        )
        XCTAssertFalse(String(reflecting: valid).contains("synthetic-secret"))

        XCTAssertThrowsError(
            try MiniMaxSubscriptionKey(
                slot: credentialSlot(providerID: "other"),
                secret: secret
            )
        ) { XCTAssertEqual($0 as? MiniMaxCredentialError, .providerMismatch) }
        XCTAssertThrowsError(
            try MiniMaxSubscriptionKey(
                slot: credentialSlot(role: .management),
                secret: secret
            )
        ) { XCTAssertEqual($0 as? MiniMaxCredentialError, .roleMismatch) }
    }

    func testSyntheticFixtureContainsNoCredentialOrOpaqueIdentifierShape() throws {
        let object = try JSONSerialization.jsonObject(with: fixture("synthetic-success"))
        let text = String(describing: object).lowercased()
        for forbidden in ["bearer ", "sk-", "token", "email", "user_id", "team_id"] {
            XCTAssertFalse(text.contains(forbidden))
        }
        XCTAssertNil(text.range(
            of: #"\b(?=[0-9a-f]{32,}\b)(?=[0-9a-f]*[a-f])[0-9a-f]+\b"#,
            options: .regularExpression
        ))
    }

    private func makeClient(
        timeout: TimeInterval = 1,
        responseLimit: Int = 1_048_576
    ) -> URLSessionMiniMaxAPIClient {
        let fixedObservedAt = observedAt
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MiniMaxURLProtocolStub.self]
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSessionMiniMaxAPIClient(
            session: URLSession(configuration: configuration),
            reviewedRows: try! MiniMaxModelRowMapping(rows: [
                try! MiniMaxReviewedModelRow(
                    providerName: "synthetic-row-a",
                    stableID: "row-a",
                    displayName: "Synthetic row A"
                ),
                try! MiniMaxReviewedModelRow(
                    providerName: "synthetic-row-b",
                    stableID: "row-b",
                    displayName: "Synthetic row B"
                )
            ]),
            timeout: timeout,
            responseLimit: responseLimit,
            now: { fixedObservedAt }
        )
    }

    private func credential(_ value: String) throws -> MiniMaxSubscriptionKey {
        try MiniMaxSubscriptionKey(
            slot: credentialSlot(),
            secret: CredentialSecret(value)
        )
    }

    private func credentialSlot(
        providerID: String = "minimax",
        role: ProviderCredentialRole = .ordinary
    ) -> ProviderCredentialSlot {
        ProviderCredentialSlot(
            providerID: providerID,
            accountID: "synthetic-account",
            slotID: "synthetic-slot",
            contextID: "synthetic-team",
            role: role,
            isEnabled: true,
            keychainReference: "synthetic-reference"
        )
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures/MiniMax"
        ))
        return try Data(contentsOf: url)
    }

    private func installJSON(
        _ json: String,
        headers: [String: String] = [:]
    ) {
        MiniMaxURLProtocolStub.setHandler { _, stub in
            stub.respond(statusCode: 200, headers: headers, data: Data(json.utf8))
        }
    }

    private func metric(_ id: String, in result: MiniMaxCapacityResult) throws -> CapacityMetric {
        try XCTUnwrap(result.metrics.first { $0.metricID == id })
    }

    private func assertError(
        _ expected: MiniMaxAPIClientError,
        client: URLSessionMiniMaxAPIClient? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await (client ?? makeClient()).fetchTokenPlanCapacity(
                credential: try credential("synthetic-subscription-key")
            )
            XCTFail("Expected MiniMax request to fail.", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? MiniMaxAPIClientError, expected, file: file, line: line)
        }
    }
}

private final class MiniMaxURLProtocolStub: URLProtocol, @unchecked Sendable {
    typealias Handler = (URLRequest, MiniMaxURLProtocolStub) -> Void
    private static let storage = MiniMaxURLProtocolHandlerStorage()

    static func setHandler(_ handler: @escaping Handler) { storage.set(handler) }
    static func clearHandler() { storage.set(nil) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.storage.handler else {
            fail(with: URLError(.resourceUnavailable))
            return
        }
        handler(request, self)
    }

    override func stopLoading() {}

    func respond(statusCode: Int, headers: [String: String] = [:], data: Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
              )
        else {
            fail(with: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    func fail(with error: Error) { client?.urlProtocol(self, didFailWithError: error) }
}

private final class MiniMaxURLProtocolHandlerStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var storedHandler: MiniMaxURLProtocolStub.Handler?
    var handler: MiniMaxURLProtocolStub.Handler? { lock.withLock { storedHandler } }
    func set(_ handler: MiniMaxURLProtocolStub.Handler?) { lock.withLock { storedHandler = handler } }
}

private final class MiniMaxRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { storedRequests } }
    func append(_ request: URLRequest) { lock.withLock { storedRequests.append(request) } }
}
