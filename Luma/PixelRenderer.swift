import Foundation

enum PixelRenderer {
    static func normalize(_ message: String) -> String {
        message.precomposedStringWithCanonicalMapping.uppercased()
    }

    static func validationError(_ message: String) -> String? {
        let text = normalize(message)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Écris un message avant de l’afficher."
        }
        if text.count > 60 { return "Ton message peut contenir 60 caractères maximum." }
        let unsupported = Set(text.filter { PixelFont.glyphs[String($0)] == nil }).sorted()
        if !unsupported.isEmpty {
            return "Caractères non pris en charge : " + String(unsupported)
        }
        return nil
    }

    static func appearancePages(_ message: String) -> [String] {
        normalize(message).split(separator: " ").flatMap { word -> [String] in
            let characters = Array(word)
            return stride(from: 0, to: characters.count, by: 5).map {
                String(characters[$0..<min($0 + 5, characters.count)])
            }
        }
    }

    static func shouldScroll(_ text: String, panel: Panel, mode: ScrollMode) -> Bool {
        mode == .always || (mode == .auto && normalize(text).count * 6 - 1 > panel.columns)
    }

    static func grid(draft: Draft, panel: Panel, icon: Bool, offset: Int = 0, drawing: [Bool]? = nil) -> [[Bool]] {
        var grid = Array(repeating: Array(repeating: false, count: panel.columns), count: panel.rows)
        guard draft.isOn else { return grid }
        if icon {
            if let drawing, drawing.count == panel.columns * panel.rows {
                for index in drawing.indices { grid[index / panel.columns][index % panel.columns] = drawing[index] }
                return grid
            }
            stamp(draft.pictogram.bits, into: &grid, left: (panel.columns - 8) / 2, top: 0)
            return grid
        }
        let pages = draft.scrollMode == .appearance ? appearancePages(draft.message) : []
        let text = pages.isEmpty ? normalize(draft.message) : pages[max(0, offset) % pages.count]
        let width = max(0, text.count * 6 - 1)
        let moving = shouldScroll(text, panel: panel, mode: draft.scrollMode)
        let left = moving ? panel.columns - max(0, offset) % (panel.columns + width + 6)
            : max(0, (panel.columns - width) / 2)
        for (index, character) in text.enumerated() {
            let bits = PixelFont.glyphs[String(character)] ?? PixelFont.glyphs["?"]!
            stamp(bits, into: &grid, left: left + index * 6, top: 0)
        }
        return grid
    }

    static func scrollPackets(_ message: String, speed: Speed) -> [Data] {
        let characters = Array(normalize(message))
        var columns = [UInt8]()
        for (index, character) in characters.enumerated() {
            let rows = PixelFont.glyphs[String(character)]!.split(separator: "/").map(Array.init)
            for column in 0..<5 {
                var value: UInt8 = 0
                for row in rows.indices where rows[row][column] == "1" { value |= 0x80 >> row }
                columns.append(value)
            }
            if index + 1 < characters.count { columns.append(0) }
        }
        return columnPackets(columns, speed: speed)
    }

    static func appearancePackets(_ message: String, panel: Panel, speed: Speed) -> [Data] {
        let pages = appearancePages(message)
        var columns = [UInt8]()
        for page in pages {
            var draft = Draft(); draft.message = page; draft.scrollMode = .fixed
            let pageGrid = grid(draft: draft, panel: panel, icon: false)
            for x in 0..<panel.columns {
                var column: UInt8 = 0
                for y in 0..<panel.rows where pageGrid[y][x] { column |= 0x80 >> y }
                columns.append(column)
            }
        }
        return [Data([0x47, UInt8(pages.count)])] + columnPackets(columns, speed: speed)
    }

    private static func columnPackets(_ columns: [UInt8], speed: Speed) -> [Data] {
        let length = columns.count
        var packets = [Data([0x30, UInt8(length & 0xff), UInt8(length >> 8), UInt8((speed.interval * 1000).rounded())])]
        for start in stride(from: 0, to: length, by: 17) {
            var packet = [UInt8(0x31), UInt8(start & 0xff), UInt8(start >> 8)]
            packet.append(contentsOf: columns[start..<min(start + 17, length)])
            packets.append(Data(packet))
        }
        packets.append(Data([0x32]))
        return packets
    }

    static func displaySettingsPacket(_ draft: Draft) -> Data {
        let rgb = draft.color.rgb
        return Data([0x0A, UInt8(draft.brightness.rounded()), rgb.red, rgb.green, rgb.blue])
    }

    static func framePackets(_ grid: [[Bool]]) -> [Data] {
        (0..<2).map { part in
            var packet: [UInt8] = [UInt8(0x20 + part)]
            for row in (part * 4)..<(part * 4 + 4) {
                for matrix in 0..<4 {
                    var value: UInt8 = 0
                    for column in 0..<8 where grid[row][matrix * 8 + column] {
                        value |= 0x80 >> column
                    }
                    packet.append(value)
                }
            }
            return Data(packet)
        }
    }

    private static func stamp(_ bits: String, into grid: inout [[Bool]], left: Int, top: Int) {
        for (y, row) in bits.split(separator: "/").enumerated() {
            for (x, bit) in row.enumerated() {
                let px = x + left, py = y + top
                if grid.indices.contains(py), grid[py].indices.contains(px) {
                    grid[py][px] = bit == "1"
                }
            }
        }
    }
}
