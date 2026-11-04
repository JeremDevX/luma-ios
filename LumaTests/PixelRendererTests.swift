import XCTest
@testable import Luma

final class PixelRendererTests: XCTestCase {
    func testSpectrumRespondsToFrequencyAndSilence() throws {
        let low = try XCTUnwrap(SpectrumAnalyzer())
        XCTAssertEqual(low.analyze(Array(repeating: 0, count: 512), sampleRate: 48000), Array(repeating: 0, count: 32))
        let lowTone = (0..<512).map { Float(sin(2 * Double.pi * 375 * Double($0) / 48000)) * 0.5 }
        let lowBands = low.analyze(lowTone, sampleRate: 48000)
        XCTAssertGreaterThan(lowBands.prefix(16).map(Int.init).reduce(0, +), lowBands.suffix(16).map(Int.init).reduce(0, +))
        let high = try XCTUnwrap(SpectrumAnalyzer())
        let highTone = (0..<512).map { Float(sin(2 * Double.pi * 6000 * Double($0) / 48000)) * 0.5 }
        let highBands = high.analyze(highTone, sampleRate: 48000)
        XCTAssertGreaterThan(highBands.suffix(16).map(Int.init).reduce(0, +), highBands.prefix(16).map(Int.init).reduce(0, +))
        XCTAssertTrue(highBands.allSatisfy { $0 <= 8 })
        for _ in 0..<12 { _ = high.analyze(Array(repeating: 0, count: 512), sampleRate: 48000) }
        XCTAssertEqual(high.analyze(Array(repeating: 0, count: 512), sampleRate: 48000), Array(repeating: 0, count: 32))
        XCTAssertEqual(high.analyze([.nan] + Array(repeating: 0, count: 511), sampleRate: 48000), Array(repeating: 0, count: 32))
    }

    func testValidationNormalizesAccentsAndRejectsUnsupportedCharacters() {
        XCTAssertEqual(PixelRenderer.normalize("a\u{0300} bientôt"), "À BIENTÔT")
        XCTAssertNil(PixelRenderer.validationError("À BIENTÔT (A)=B-C_D"))
        XCTAssertNotNil(PixelRenderer.validationError("Bonjour 🐈"))
        XCTAssertNotNil(PixelRenderer.validationError(" \n"))
        XCTAssertNil(PixelRenderer.validationError(String(repeating: "A", count: 60)))
        XCTAssertNotNil(PixelRenderer.validationError(String(repeating: "A", count: 61)))
    }

    func testScrollingRespectsEachPanelsCapacityAndMode() {
        for panel in Panel.allCases {
            let fits = String(repeating: "A", count: panel.capacity)
            XCTAssertFalse(PixelRenderer.shouldScroll(fits, panel: panel, mode: .auto))
            XCTAssertTrue(PixelRenderer.shouldScroll(fits + "A", panel: panel, mode: .auto))
            XCTAssertFalse(PixelRenderer.shouldScroll(fits + "A", panel: panel, mode: .fixed))
            XCTAssertTrue(PixelRenderer.shouldScroll("A", panel: panel, mode: .always))
        }
    }

    func testGridHasCorrectDimensionsAndCentersMerci() {
        XCTAssertEqual(Panel.rgb.columns * Panel.rgb.rows, 256)
        XCTAssertEqual(Panel.rgb.capacity, 5)
        for panel in Panel.allCases {
            let grid = PixelRenderer.grid(draft: Draft(), panel: panel, icon: false)
            XCTAssertEqual(grid.count, panel.rows)
            XCTAssertTrue(grid.allSatisfy { $0.count == panel.columns })
            let litColumns = (0..<panel.columns).filter { x in grid.contains { $0[x] } }
            XCTAssertEqual(litColumns.first, (panel.columns - 29) / 2)
            XCTAssertEqual(litColumns.last, (panel.columns - 29) / 2 + 28)
        }
    }

    func testEveryIconPreservesItsEightByEightBitmap() {
        for panel in Panel.allCases {
            for icon in Pictogram.allCases {
                var draft = Draft(); draft.pictogram = icon
                let grid = PixelRenderer.grid(draft: draft, panel: panel, icon: true)
                let left = (panel.columns - 8) / 2
                for (y, row) in icon.bits.split(separator: "/").enumerated() {
                    XCTAssertEqual(Array(grid[y][left..<left + 8]), row.map { $0 == "1" })
                }
            }
        }
    }

    func testPowerOffAndScrollingWrap() {
        var draft = Draft(); draft.isOn = false
        XCTAssertFalse(PixelRenderer.grid(draft: draft, panel: .rgb, icon: true).joined().contains(true))
        draft.isOn = true; draft.scrollMode = .always
        let first = PixelRenderer.grid(draft: draft, panel: .rgb, icon: false, offset: 0)
        let wrapped = PixelRenderer.grid(draft: draft, panel: .rgb, icon: false, offset: 32 + 29 + 6)
        XCTAssertEqual(first, wrapped)
        XCTAssertFalse(first.joined().contains(true))
        XCTAssertTrue(PixelRenderer.grid(draft: draft, panel: .rgb, icon: false, offset: 12).joined().contains(true))
    }
    func testCustomDrawingCoversAllFourSquares() {
        var pixels = Array(repeating: false, count: 256)
        for column in [0, 8, 16, 24, 31] { pixels[column] = true }
        pixels[255] = true
        let grid = PixelRenderer.grid(draft: Draft(), panel: .rgb, icon: true, drawing: pixels)
        for column in [0, 8, 16, 24, 31] { XCTAssertTrue(grid[0][column]) }
        XCTAssertTrue(grid[7][31])
        XCTAssertEqual(grid.joined().filter { $0 }.count, 6)
        var off = Draft(); off.isOn = false
        XCTAssertFalse(PixelRenderer.grid(draft: off, panel: .rgb, icon: true, drawing: pixels).joined().contains(true))
    }

    func testScrollPacketsMatchPreviewAndRespectPacketLimits() {
        for message in ["A(B)=C_D", String(repeating: "A", count: 60)] {
            let packets = PixelRenderer.scrollPackets(message, speed: .fast).map { Array($0) }
            let width = message.count * 6 - 1
            XCTAssertEqual(packets.first, [0x30, UInt8(width & 0xff), UInt8(width >> 8), 20])
            XCTAssertEqual(packets.last, [0x32])
            var columns = [UInt8]()
            for packet in packets.dropFirst().dropLast() {
                XCTAssertLessThanOrEqual(packet.count, 20)
                XCTAssertEqual(Int(packet[1]) + 256 * Int(packet[2]), columns.count)
                columns.append(contentsOf: packet.dropFirst(3))
            }
            XCTAssertEqual(columns.count, width)
            var draft = Draft(); draft.message = message; draft.scrollMode = .always
            for offset in [0, 20, 32, 40, 32 + width + 5] {
                let grid = PixelRenderer.grid(draft: draft, panel: .rgb, icon: false, offset: offset)
                let left = 32 - offset % (32 + width + 6)
                for x in 0..<32 {
                    let source = x - left
                    for y in 0..<8 {
                        let expected = source >= 0 && source < width && (columns[source] & (0x80 >> y)) != 0
                        XCTAssertEqual(grid[y][x], expected)
                    }
                }
            }
        }
    }

    func testAppearancePagesSplitWordsAndPreserveAccents() {
        XCTAssertEqual(PixelRenderer.appearancePages("salut bonjour été"), ["SALUT", "BONJO", "UR", "ÉTÉ"])
        XCTAssertEqual(PixelRenderer.appearancePages("  A   B "), ["A", "B"])
        XCTAssertTrue(PixelRenderer.appearancePages("   ").isEmpty)
        var draft = Draft(); draft.message = "SALUT MONDE"; draft.scrollMode = .appearance
        let first = PixelRenderer.grid(draft: draft, panel: .rgb, icon: false, offset: 0)
        let second = PixelRenderer.grid(draft: draft, panel: .rgb, icon: false, offset: 1)
        draft.scrollMode = .fixed; draft.message = "SALUT"
        XCTAssertEqual(first, PixelRenderer.grid(draft: draft, panel: .rgb, icon: false))
        draft.message = "MONDE"
        XCTAssertEqual(second, PixelRenderer.grid(draft: draft, panel: .rgb, icon: false))
    }

    func testAppearancePacketsEncodeEveryWordAndLongestMessage() {
        let message = Array(repeating: "A", count: 30).joined(separator: " ")
        let pages = PixelRenderer.appearancePages(message)
        XCTAssertEqual(pages.count, 30)
        let packets = PixelRenderer.appearancePackets(message, panel: .rgb, speed: .normal).map { Array($0) }
        XCTAssertEqual(packets[0], [0x47, 30])
        XCTAssertEqual(packets[1], [0x30, 0xC0, 0x03, 50])
        XCTAssertEqual(packets.last, [0x32])
        var columns = [UInt8]()
        for packet in packets.dropFirst(2).dropLast() {
            XCTAssertLessThanOrEqual(packet.count, 20)
            XCTAssertEqual(Int(packet[1]) + 256 * Int(packet[2]), columns.count)
            columns.append(contentsOf: packet.dropFirst(3))
        }
        XCTAssertEqual(columns.count, 960)
        var draft = Draft(); draft.message = "A"; draft.scrollMode = .fixed
        let expected = PixelRenderer.grid(draft: draft, panel: .rgb, icon: false)
        for page in 0..<30 { for x in 0..<32 { for y in 0..<8 {
            XCTAssertEqual(columns[page * 32 + x] & (0x80 >> y) != 0, expected[y][x])
        } } }
    }

    func testFramePacketsContainCompleteRowsInMatrixOrder() {
        var grid = Array(repeating: Array(repeating: false, count: 32), count: 8)
        grid[0][0] = true
        grid[3][31] = true
        grid[4][8] = true
        grid[7][23] = true
        let packets = PixelRenderer.framePackets(grid).map { Array($0) }
        XCTAssertEqual(packets.map(\.count), [17, 17])
        XCTAssertEqual(packets[0][0], 0x20)
        XCTAssertEqual(packets[0][1], 0x80)
        XCTAssertEqual(packets[0][16], 0x01)
        XCTAssertEqual(packets[1][0], 0x21)
        XCTAssertEqual(packets[1][2], 0x80)
        XCTAssertEqual(packets[1][15], 0x01)
        XCTAssertEqual(packets.flatMap { $0.dropFirst() }.filter { $0 != 0 }.count, 4)
    }

    func testStrokeLocksModeAndFillsPixelsBetweenSamples() {
        let size = CGSize(width: 320, height: 320)
        var pixels = Array(repeating: false, count: 256)
        pixels[7] = true
        var stroke = DrawingStroke()
        stroke.paint(at: CGPoint(x: 20, y: 20), size: size, pixels: &pixels)
        stroke.paint(at: CGPoint(x: 300, y: 20), size: size, pixels: &pixels)
        stroke.paint(at: CGPoint(x: 20, y: 20), size: size, pixels: &pixels)
        XCTAssertTrue(pixels[0..<8].allSatisfy { $0 })
        XCTAssertEqual(pixels.filter { $0 }.count, 8)
        stroke = DrawingStroke()
        stroke.paint(at: CGPoint(x: 20, y: 20), size: size, pixels: &pixels)
        stroke.paint(at: CGPoint(x: 300, y: 20), size: size, pixels: &pixels)
        XCTAssertFalse(pixels.contains(true))
    }

    func testStrokePaintsEachSquareWithoutChangingOthers() {
        var pixels = Array(repeating: false, count: 256)
        for square in 0..<4 {
            var stroke = DrawingStroke()
            stroke.paint(at: CGPoint(x: 5, y: 5), size: CGSize(width: 80, height: 80), pixels: &pixels, columnOffset: square * 8)
        }
        XCTAssertEqual(pixels.enumerated().filter { $0.element }.map(\.offset), [0, 8, 16, 24])
    }

    func testStrokeIgnoresOutsidePointsAndKeepsModeOnReentry() {
        let size = CGSize(width: 320, height: 320)
        var pixels = Array(repeating: false, count: 256)
        var stroke = DrawingStroke()
        stroke.paint(at: CGPoint(x: -10, y: 20), size: size, pixels: &pixels)
        XCTAssertNil(stroke.mode)
        stroke.paint(at: CGPoint(x: 20, y: 20), size: size, pixels: &pixels)
        stroke.paint(at: CGPoint(x: 400, y: 20), size: size, pixels: &pixels)
        stroke.paint(at: CGPoint(x: 300, y: 300), size: size, pixels: &pixels)
        XCTAssertEqual(pixels.filter { $0 }.count, 2)
        XCTAssertTrue(pixels[0]); XCTAssertTrue(pixels[231])
    }

}
