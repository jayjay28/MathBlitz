//
//  OnboardingFlowUITests.swift
//  MathBlitzUITests
//
//  Created by Codex on 11/10/25.
//

import XCTest

final class OnboardingFlowUITests: XCTestCase {
    func testEmojitarSelectionFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Advance to name entry.
        if app.buttons["Next"].exists {
            app.buttons["Next"].tap()
        }
        
        let nameField = app.textFields["Type your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Snapshot Pilot")
        app.buttons["Next"].tap()
        
        // Mode selection
        XCTAssertTrue(app.buttons["Kids"].waitForExistence(timeout: 2))
        app.buttons["Kids"].tap()
        app.buttons["Next"].tap()
        
        // Emojitar picker
        let emojiButton = app.buttons["Emoji 🚀"]
        XCTAssertTrue(emojiButton.waitForExistence(timeout: 2))
        emojiButton.tap()
        
        let colorButton = app.buttons["Color #3B82F6"]
        XCTAssertTrue(colorButton.waitForExistence(timeout: 2))
        colorButton.tap()
        
        let saveButton = app.buttons["Save my vibe"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()
    }
}
