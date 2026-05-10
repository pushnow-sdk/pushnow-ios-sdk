//
//  PushFlyStorageTests.swift
//  PushFlyTests
//

import XCTest
@testable import PushFly

final class PushFlyStorageTests: XCTestCase {

    func testInMemoryRoundTrip() {
        let s = InMemoryPushFlyStorage()
        XCTAssertNil(s.string(forKey: "k"))
        s.setString("hello", forKey: "k")
        XCTAssertEqual(s.string(forKey: "k"), "hello")
        s.setString(nil, forKey: "k")
        XCTAssertNil(s.string(forKey: "k"))
    }
}
