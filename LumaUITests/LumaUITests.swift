import XCTest

final class LumaUITests: XCTestCase {
    @MainActor
    func testCompleteDemoFlow() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["connect-rgb"].waitForExistence(timeout: 5))
        screenshot("01-Accueil")
        app.buttons["connect-rgb"].tap()
        XCTAssertTrue(app.buttons["send"].waitForExistence(timeout: 5))
        screenshot("02-Message")
        app.buttons["Azur"].tap()
        app.buttons["send"].tap()
        XCTAssertTrue(app.staticTexts["Aperçu affiché"].waitForExistence(timeout: 3))
        app.buttons["OK"].tap()
        app.tabBars.buttons["Icônes"].tap()
        app.buttons["Cœur"].tap()
        screenshot("03-Icones")
        app.buttons["＋ Créer un dessin"].tap()
        XCTAssertTrue(app.buttons["pixel-0"].waitForExistence(timeout: 3))
        app.buttons["Effacer le dessin"].tap()
        app.buttons["confirm-clear-drawing"].tap()
        XCTAssertFalse(app.buttons["validate-drawing"].isEnabled)
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.65))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.4)))
        app.buttons["pixel-7"].tap()
        app.buttons["pixel-0"].press(forDuration: 0.05, thenDragTo: app.buttons["pixel-7"])
        for index in 0..<8 { XCTAssertEqual(app.buttons["pixel-\(index)"].value as? String, "Allumé") }
        app.buttons["pixel-0"].press(forDuration: 0.05, thenDragTo: app.buttons["pixel-7"])
        for index in 0..<8 { XCTAssertEqual(app.buttons["pixel-\(index)"].value as? String, "Éteint") }
        app.buttons["pixel-0"].tap()
        app.segmentedControls.buttons["4"].tap()
        app.buttons["pixel-255"].tap()
        app.segmentedControls.buttons["1"].tap()
        if app.buttons["favorite-drawing"].label.contains("Retirer") { app.buttons["favorite-drawing"].tap() }
        app.buttons["favorite-drawing"].tap()
        XCTAssertTrue(app.buttons["favorite-drawing"].label.contains("Retirer"))
        screenshot("05-Dessin")
        app.buttons["validate-drawing"].tap()
        XCTAssertTrue(app.buttons["send"].waitForExistence(timeout: 3))
        app.buttons["send"].tap()
        XCTAssertTrue(app.staticTexts["Aperçu affiché"].waitForExistence(timeout: 3))
        app.buttons["OK"].tap()
        app.buttons["＋ Créer un dessin"].tap()
        app.buttons["favorite-drawing"].tap()
        app.buttons["Effacer le dessin"].tap()
        app.buttons["confirm-clear-drawing"].tap()
        XCTAssertFalse(app.buttons["validate-drawing"].isEnabled)
        app.buttons["Retour aux icônes"].tap()
        app.tabBars.buttons["Panneau"].tap()
        app.buttons["Mode d’affichage"].tap()
        app.buttons["Toujours"].tap()
        app.segmentedControls.buttons["Rapide"].tap()
        screenshot("04-Reglages")
        app.buttons["apply"].tap()
        XCTAssertTrue(app.staticTexts["Réglages appliqués"].waitForExistence(timeout: 3))
        app.buttons["OK"].tap()
        app.buttons["Déconnecter"].tap()
        app.buttons["confirm-disconnect"].tap()
        XCTAssertTrue(app.buttons["connect-rgb"].waitForExistence(timeout: 3))

    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
