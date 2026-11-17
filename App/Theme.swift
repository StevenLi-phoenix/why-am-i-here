import SwiftUI

/// Colors and metrics taken from the Figma prototype (dark appearance only).
enum Theme {
    static let accent = Color(red: 0, green: 145 / 255, blue: 1)
    static let card = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let secondary = Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.7)
    static let tertiary = Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.3)
    static let track = Color.white.opacity(0.13)
    static let hairline = Color.white.opacity(0.28)
    static let disabledFill = Color(red: 118 / 255, green: 118 / 255, blue: 128 / 255).opacity(0.24)

    static let cardRadius: CGFloat = 26
    static let screenPadding: CGFloat = 16
}
