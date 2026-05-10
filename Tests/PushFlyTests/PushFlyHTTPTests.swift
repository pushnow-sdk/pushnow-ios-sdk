//
//  PushFlyHTTPTests.swift
//  PushFlyTests
//
//  Tests for the error-envelope parser — the one piece of the HTTP
//  layer with interesting logic independent of networking.
//

import XCTest
@testable import PushFly

final class PushFlyHTTPTests: XCTestCase {

    func testParseStandardErrorEnvelope() {
        let body = #"{"code":"invalid_credentials","message":"bad auth"}"#.data(using: .utf8)!
        let err = PushFlyHTTPClient.parseError(status: 401, headers: [:], data: body)
        XCTAssertEqual(err.code, .invalidCredentials)
        XCTAssertEqual(err.message, "bad auth")
        XCTAssertEqual(err.httpStatus, 401)
        XCTAssertNil(err.retryAfterSeconds)
    }

    func testParseRateLimitEnvelopeWithDetails() {
        let body = #"{"code":"rate_limited","message":"too many","details":{"retryAfterSeconds":3}}"#.data(using: .utf8)!
        let err = PushFlyHTTPClient.parseError(status: 429, headers: [:], data: body)
        XCTAssertEqual(err.code, .rateLimited)
        XCTAssertEqual(err.retryAfterSeconds, 3)
    }

    func testRetryAfterHeaderFallback() {
        let err = PushFlyHTTPClient.parseError(status: 429, headers: ["Retry-After": "5"], data: Data())
        XCTAssertEqual(err.retryAfterSeconds, 5)
        XCTAssertEqual(err.httpStatus, 429)
    }

    func testUnknownBodyFallsBackToHttpCode() {
        let body = "<html>".data(using: .utf8)!
        let err = PushFlyHTTPClient.parseError(status: 500, headers: [:], data: body)
        XCTAssertEqual(err.code, PushFlyErrorCode(rawValue: "http_500"))
        XCTAssertEqual(err.httpStatus, 500)
    }

    func testUnknownServerCodePassesThrough() {
        let body = #"{"code":"brand_new_code","message":"something"}"#.data(using: .utf8)!
        let err = PushFlyHTTPClient.parseError(status: 400, headers: [:], data: body)
        XCTAssertEqual(err.code.rawValue, "brand_new_code")
        XCTAssertEqual(err.message, "something")
    }

    /// Pins that the backend's `field` envelope key surfaces on the
    /// parsed error (needed for the host app to highlight invalid
    /// form fields in dashboards that reuse these types).
    func testParseErrorIncludesFieldWhenPresent() {
        let body = #"{"code":"invalid_apns_token","message":"bad","field":"apnsToken"}"#.data(using: .utf8)!
        let err = PushFlyHTTPClient.parseError(status: 400, headers: [:], data: body)
        XCTAssertEqual(err.code, .invalidApnsToken)
        XCTAssertEqual(err.field, "apnsToken")
    }
}
