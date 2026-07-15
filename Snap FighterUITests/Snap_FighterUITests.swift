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
    func testSummonAndBattleResultActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--show-capture-result"]
        app.launch()

        XCTAssertTrue(app.staticTexts["召喚成功"].waitForExistence(timeout: 3))
        let cutoutChoice = app.buttons["主體卡圖，未選擇"]
        XCTAssertTrue(cutoutChoice.waitForExistence(timeout: 3))
        cutoutChoice.tap()
        XCTAssertTrue(app.buttons["主體卡圖，已選擇"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["召喚第二張卡"].exists)

        app.terminate()
        app.launchArguments = ["--show-battle-result"]
        app.launch()

        XCTAssertTrue(app.staticTexts["勝者誕生"].waitForExistence(timeout: 3))
        let collectButton = app.buttons["收入卡牌收藏"]
        XCTAssertTrue(collectButton.waitForExistence(timeout: 3))
        collectButton.tap()
        XCTAssertTrue(app.buttons["已收藏這張卡"].waitForExistence(timeout: 2))

        app.buttons["返回冒險大廳"].tap()
        XCTAssertTrue(app.staticTexts["冒險大廳"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testKeyOutAndBattleAssemblyFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--show-manual-cutout"]
        app.launch()

        XCTAssertTrue(app.staticTexts["手動選取主體"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["稍後處理"].waitForExistence(timeout: 3))
        app.buttons["稍後處理"].tap()
        XCTAssertTrue(app.staticTexts["正在召喚怪物"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["manual-cutout-button"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["重新嘗試"].waitForExistence(timeout: 12))
        app.buttons["取消召喚"].tap()
        XCTAssertTrue(app.staticTexts["冒險大廳"].waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = ["--show-ready-battle"]
        app.launch()

        XCTAssertTrue(app.staticTexts["決鬥編成"].waitForExistence(timeout: 3))
        let battleButton = app.buttons["進入魔法競技場"]
        XCTAssertTrue(battleButton.waitForExistence(timeout: 3))
        battleButton.tap()
        XCTAssertTrue(app.staticTexts["你的回合"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
