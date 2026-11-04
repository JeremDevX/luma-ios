import Foundation

enum Panel: String, Codable, CaseIterable, Identifiable {
    case rgb
    var id: Self { self }
    var name: String { "Luma" }
    var columns: Int { 32 }
    var rows: Int { 8 }
    var capacity: Int { 5 }
    var specification: String { "32 × 8 · 256 LED" }
}

enum ScrollMode: String, Codable, CaseIterable, Identifiable {
    case auto = "Auto", fixed = "Fixe", always = "Toujours", appearance = "Apparition"
    var id: Self { self }
}

enum Speed: String, Codable, CaseIterable, Identifiable {
    case slow = "Lente", normal = "Normale", fast = "Rapide"
    var id: Self { self }
    var appearanceInterval: Double {
        switch self { case .slow: 4; case .normal: 3; case .fast: 2.4 }
    }
    var interval: Double {
        switch self { case .slow: 0.10; case .normal: 0.05; case .fast: 0.02 }
    }
}

enum LEDColor: String, Codable, CaseIterable, Identifiable {
    case citron = "Citron", white = "Blanc", amber = "Ambre"
    case coral = "Corail", blue = "Azur", lavender = "Lavande"
    var id: Self { self }
    var asset: String {
        switch self {
        case .citron: "accent"
        case .white: "text"
        case .amber: "amber"
        case .coral: "red"
        case .blue: "blue"
        case .lavender: "purple"
        }
    }
    var swatch: String {
        switch self {
        case .citron: "53a51"
        case .white: "f6520"
        case .amber: "e47a4"
        case .coral: "e1918"
        case .blue: "b189e"
        case .lavender: "1f333"
        }
    }
}

enum Pictogram: String, Codable, CaseIterable, Identifiable {
    case smile = "Sourire", heart = "Cœur", arrow = "Flèche"
    case sun = "Soleil", wink = "Clin d’œil", pause = "Pause"
    var id: Self { self }
    var bits: String {
        switch self {
        case .smile: "00111100/01000010/10100101/10000001/10100101/10011001/01000010/00111100"
        case .heart: "00000000/01100110/11111111/11111111/01111110/00111100/00011000/00000000"
        case .arrow: "00010000/00011000/11111100/11111110/11111100/00011000/00010000/00000000"
        case .sun: "00011000/01011010/00111100/11111111/11111111/00111100/01011010/00011000"
        case .wink: "00111100/01000010/10101101/10000001/10100101/10011001/01000010/00111100"
        case .pause: "01100110/01100110/01100110/01100110/01100110/01100110/01100110/00000000"
        }
    }
    var asset: String {
        switch self {
        case .smile: "ba891"
        case .heart: "e8a74"
        case .arrow: "ebb46"
        case .sun: "f955a"
        case .wink: "05874"
        case .pause: "fbe81"
        }
    }
}

struct Draft: Codable, Equatable {
    var message = "MERCI"
    var color: LEDColor = .citron
    var pictogram: Pictogram = .smile
    var brightness = 40.0
    var scrollMode: ScrollMode = .auto
    var speed: Speed = .normal
    var isOn = true
    var favorites = ["MERCI", "BONJOUR", "À BIENTÔT"]
}

struct DrawingFavorite: Codable, Equatable, Identifiable {
    var id = UUID()
    let pixels: [Bool]
    let color: LEDColor
}

enum EditorTab: String, Hashable { case message, icons, tools, settings }
enum Session: Equatable { case selection, pairing(Panel), ready(Panel), offline(Panel) }
enum LumaSheet: String, Identifiable {
    case help, clear, clearDrawing, disconnect, sent, applied, feature
    var id: String { rawValue }
}
