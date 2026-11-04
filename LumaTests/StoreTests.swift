import XCTest
@testable import Luma

@MainActor
final class StoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() async throws {
        try await super.setUp()
        suite = "LumaTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
    }
    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        try await super.tearDown()
    }

    func testDraftAndFavoritesSurviveRelaunchWithoutPretendingToConnect() {
        let store = LumaStore(defaults: defaults)
        store.draft.message = "SALUT"
        store.toggleFavorite()
        store.draft.brightness = 75
        store.session = .ready(.rgb)
        let restored = LumaStore(defaults: defaults)
        XCTAssertEqual(restored.draft.message, "SALUT")
        XCTAssertEqual(restored.draft.brightness, 75)
        XCTAssertTrue(restored.draft.favorites.contains("SALUT"))
        XCTAssertEqual(restored.session, .selection)
    }

    func testClearPreservesDraftAndDisconnectPreservesSettings() {
        let store = LumaStore(defaults: defaults)
        store.session = .ready(.rgb)
        store.display()
        XCTAssertNotNil(store.displayedDraft)
        store.clear()
        XCTAssertNil(store.displayedDraft)
        XCTAssertEqual(store.draft.message, "MERCI")
        XCTAssertFalse(store.draft.isOn)
        store.disconnect()
        XCTAssertEqual(store.draft.favorites.count, 3)
        XCTAssertEqual(store.session, .selection)
    }

    func testInvalidOrOfflineMessageCannotBeSent() {
        let store = LumaStore(defaults: defaults)
        store.display()
        XCTAssertNil(store.displayedDraft)
        store.session = .ready(.rgb)
        store.draft.message = "🦊"
        store.display()
        XCTAssertNil(store.displayedDraft)
        store.tab = .icons
        store.display()
        XCTAssertNotNil(store.displayedDraft)
        XCTAssertTrue(store.displayedIcon)
    }

    func testCorruptStorageReportsFailure() {
        defaults.set(Data("broken".utf8), forKey: "luma.draft.v1")
        let store = LumaStore(defaults: defaults)
        XCTAssertNotNil(store.storageError)
        XCTAssertEqual(store.draft, Draft())
    }
    func testDrawingPersistsAndDisplayedContentIsIndependent() {
        let store = LumaStore(defaults: defaults)
        store.session = .ready(.rgb); store.tab = .icons; store.isDrawing = true
        store.drawing[63] = true
        store.display()
        XCTAssertEqual(store.displayedDrawing?[63], true)
        XCTAssertEqual(LumaStore(defaults: defaults).drawing[63], true)
        store.clearDrawing()
        XCTAssertFalse(store.drawing.contains(true))
        XCTAssertEqual(store.displayedDrawing?[63], true)
        store.disconnect()
        XCTAssertEqual(store.displayedDrawing?[63], true)
        XCTAssertEqual(store.session, .selection)
        store.clear()
        XCTAssertNil(store.displayedDrawing)
    }

    func testInvalidDrawingStorageDoesNotLoseExistingDraft() {
        let store = LumaStore(defaults: defaults)
        store.draft.message = "SALUT"
        defaults.set([true], forKey: "luma.drawing.v1")
        let restored = LumaStore(defaults: defaults)
        XCTAssertEqual(restored.draft.message, "SALUT")
        XCTAssertEqual(restored.drawing.count, 256)
        XCTAssertFalse(restored.drawing.contains(true))
        XCTAssertNotNil(restored.storageError)
    }

    func testDrawingValidationFavoritesAndRecallPreserveSnapshots() {
        let store = LumaStore(defaults: defaults)
        store.isDrawing = true
        store.validateDrawing()
        XCTAssertTrue(store.isDrawing)
        XCTAssertNil(store.selectedDrawing)
        store.toggleDrawingFavorite()
        XCTAssertTrue(store.drawingFavorites.isEmpty)
        store.drawing[0] = true; store.draft.color = .blue
        store.toggleDrawingFavorite()
        store.validateDrawing()
        XCTAssertFalse(store.isDrawing)
        XCTAssertEqual(store.selectedDrawing?.id, store.drawingFavorites.first?.id)
        store.drawing[0] = false
        XCTAssertEqual(store.selectedDrawing?.pixels[0], true)
        let restored = LumaStore(defaults: defaults)
        let favorite = restored.drawingFavorites[0]
        restored.selectDrawing(favorite)
        XCTAssertTrue(restored.drawing[0])
        XCTAssertEqual(restored.draft.color, .blue)
        restored.session = .ready(.rgb); restored.tab = .icons
        restored.display()
        XCTAssertEqual(restored.displayedDrawing, favorite.pixels)
        restored.toggleDrawingFavorite()
        XCTAssertTrue(LumaStore(defaults: defaults).drawingFavorites.isEmpty)
    }

    func testDrawingFavoriteLimitAndCorruptData() {
        let store = LumaStore(defaults: defaults)
        for index in 0..<21 {
            store.drawing = Array(repeating: false, count: 256)
            store.drawing[index] = true
            store.toggleDrawingFavorite()
        }
        XCTAssertEqual(store.drawingFavorites.count, 20)
        store.selectDrawing(store.drawingFavorites[0])
        store.toggleDrawingFavorite()
        XCTAssertEqual(store.drawingFavorites.count, 19)
        defaults.set(Data("broken".utf8), forKey: "luma.drawingFavorites.v2")
        let restored = LumaStore(defaults: defaults)
        XCTAssertTrue(restored.drawingFavorites.isEmpty)
        XCTAssertNotNil(restored.storageError)
        XCTAssertTrue(restored.drawing[0])
    }

    func testLegacyDrawingsRemainCenteredAndCanBeSavedWithoutOverwritingOriginal() throws {
        var old = Array(repeating: false, count: 64)
        old[0] = true; old[63] = true
        defaults.set(old, forKey: "luma.drawing.v1")
        let favorite = DrawingFavorite(pixels: old, color: .blue)
        defaults.set(try JSONEncoder().encode([favorite]), forKey: "luma.drawingFavorites.v1")
        let store = LumaStore(defaults: defaults)
        XCTAssertTrue(store.drawing[12]); XCTAssertTrue(store.drawing[7 * 32 + 19])
        XCTAssertEqual(store.drawingFavorites[0].pixels, store.drawing)
        store.drawing[0] = true
        store.toggleDrawingFavorite()
        XCTAssertEqual(defaults.array(forKey: "luma.drawing.v1") as? [Bool], old)
        XCTAssertTrue(LumaStore(defaults: defaults).drawing[0])
        XCTAssertEqual(LumaStore(defaults: defaults).drawingFavorites.count, 2)
    }

    func testWeatherMessageFromCurrentConditions() throws {
        let json = Data("{\"current\":{\"temperature_2m\":-1.6,\"weather_code\":71}}".utf8)
        let weather = try JSONDecoder().decode(WeatherResponse.self, from: json)
        XCTAssertEqual(weather.current.message, "NEIGE -2C")
        XCTAssertEqual(WeatherResponse.Current(temperature_2m: 20.2, weather_code: 0).message, "SOLEIL 20C")
        XCTAssertNil(WeatherResponse.Current(temperature_2m: 101, weather_code: 0).message)
    }

    func testOBDRPMDecoderHandlesEchoHeadersAndInvalidResponses() {
        XCTAssertEqual(OBDClient.parseRPM("41 0C 2E E0\r>"), 3000)
        XCTAssertEqual(OBDClient.parseRPM("010C\rSEARCHING...\r7E8 04 41 0C 0E 10\r>"), 900)
        XCTAssertEqual(OBDClient.parseRPM("410cffff"), 16383)
        XCTAssertNil(OBDClient.parseRPM("NO DATA\r>"))
        XCTAssertNil(OBDClient.parseRPM("41 0C 2E\r>"))
        XCTAssertNil(OBDClient.parseRPM("41 0D 2E E0\r>"))
    }

}
