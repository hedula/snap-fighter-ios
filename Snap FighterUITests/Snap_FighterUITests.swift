//
//  Snap_FighterUITests.swift
//  Snap FighterUITests
//
//  Created by Hedula Lee on 2026/5/4.
//

import XCTest

final class Snap_FighterUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLobbyQuickBattleAndDeckNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let quickBattle = app.buttons["快速開戰, 推薦"]
        XCTAssertTrue(quickBattle.waitForExistence(timeout: 3))
        quickBattle.tap()

        XCTAssertTrue(app.staticTexts["準備對戰！"].waitForExistence(timeout: 3))

        app.terminate()
        app.launch()

        let deckButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "開啟牌組")
        ).firstMatch
        XCTAssertTrue(deckButton.waitForExistence(timeout: 3))
        deckButton.tap()

        XCTAssertTrue(app.navigationBars["戰鬥編成"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
