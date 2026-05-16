//
//  PushNowStorageTests.swift
//  PushNowTests
//

import XCTest
@testable import PushNow

final class PushNowStorageTests: XCTestCase {

    func testInMemoryRoundTrip() {
        let s = InMemoryPushNowStorage()
        XCTAssertNil(s.string(forKey: "k"))
        s.setString("hello", forKey: "k")
        XCTAssertEqual(s.string(forKey: "k"), "hello")
        s.setString(nil, forKey: "k")
        XCTAssertNil(s.string(forKey: "k"))
    }
}
