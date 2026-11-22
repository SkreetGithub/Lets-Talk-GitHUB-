import SwiftUI
import UIKit

/// Draws a country flag from the bundled PNGs (Flags/flag-xx@3x.png, from the MIT-licensed
/// flag-icons set). Flag emoji are two "regional indicator" characters that not every font
/// draws: the iOS 26.3 simulator showed them as "??" boxes. Images look the same everywhere.
struct FlagView: View {
    /// The flag emoji stored on the language, e.g. "🇺🇸".
    let flag: String
    /// Flag height in points; width is 4:3.
    var height: CGFloat = 20

    var body: some View {
        Group {
            if let code = Self.isoCode(from: flag), let image = UIImage(named: "flag-\(code)") {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(4.0 / 3.0, contentMode: .fill)
                    .frame(width: height * 4 / 3, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: height * 0.18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                    )
            } else {
                // Unknown region: fall back to the emoji itself.
                Text(flag)
                    .font(.system(size: height))
            }
        }
        .accessibilityHidden(true)   // the language name next to it is what VoiceOver should read
    }

    /// "🇺🇸" -> "us". Returns nil if the string is not exactly two regional-indicator letters.
    static func isoCode(from flag: String) -> String? {
        let base: UInt32 = 0x1F1E6
        let letters = flag.unicodeScalars.compactMap { scalar -> Character? in
            guard (base...0x1F1FF).contains(scalar.value),
                  let ascii = UnicodeScalar(scalar.value - base + 97) else { return nil }
            return Character(ascii)
        }
        return letters.count == 2 ? String(letters) : nil
    }
}
