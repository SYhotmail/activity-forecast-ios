import Foundation
import NaturalLanguage
import UIKit

/// Picks the geocoding language for a search query (specs/007): English, the service default
/// (`nil`), unless the query is written in another script. Open-Meteo matches a query only
/// against names in the requested language and English, so "Мінск" must be searched in
/// Belarusian, while Latin names match in any language.
///
/// For a non-Latin query, in order (FR-004, research R3):
/// 1. the language `NLLanguageRecognizer` finds, if it is one of the user's (Київ → `uk`);
/// 2. else the user's first language written in that script (Мінск → `be`: NaturalLanguage has
///    no Belarusian and often reads short Cyrillic names as Kazakh or Bulgarian);
/// 3. else the script's most likely language from CLDR (Cyrillic → `ru`, Greek → `el`).
struct QueryLanguage {
    /// Lower-case language codes the user reads or types, most preferred first.
    let candidates: () -> [String]

    /// The device's preferred languages, then its enabled keyboards (FR-005). Read on each search,
    /// so a keyboard added while the app runs counts.
    static let user = QueryLanguage {
        languageCodes(from: Locale.preferredLanguages
                      + UITextInputMode.activeInputModes.compactMap(\.primaryLanguage))
    }

    /// Fixed candidates, for tests and previews.
    static func fixed(_ codes: [String]) -> QueryLanguage {
        QueryLanguage { codes }
    }

    /// The language code to search `query` in, or `nil` for English.
    func code(for query: String) -> String? {
        guard !Self.isLatin(query), let recognised = Self.recognised(query),
              let script = Self.script(of: recognised) else { return nil }
        let candidates = candidates()
        let code = candidates.first { $0 == Self.languageCode(recognised) }
            ?? candidates.first { Self.script(of: $0) == script }
            ?? Self.languageCode(Locale.Language(identifier: "und-\(script)").maximalIdentifier)
        return code == "en" ? nil : code
    }

    /// Language codes of identifiers like `en-GB`, `zh-Hans-CN` or `uk`, in order and without
    /// duplicates. Keyboard modes that are not languages (`emoji`, `dictation`) are dropped.
    static func languageCodes(from identifiers: [String]) -> [String] {
        var codes: [String] = []
        for identifier in identifiers {
            guard let code = languageCode(identifier), !codes.contains(code) else { continue }
            codes.append(code)
        }
        return codes
    }

    private static func languageCode(_ identifier: String) -> String? {
        let code = identifier.split(separator: "-").first.map { $0.lowercased() }
        guard let code else {
            return nil
        }
        return (2...3).contains(code.count) && code.allSatisfy(\.isLetter) ? code : nil
    }

    /// ISO 15924 script of a language, e.g. `Cyrl` for `be`, `Hans` for `zh-Hans`.
    private static func script(of language: String) -> String? {
        Locale.Language(identifier: Locale.Language(identifier: language).maximalIdentifier).script?.identifier
    }

    /// The recognised language identifier, e.g. `uk` or `zh-Hans`; `nil` when there is none.
    private static func recognised(_ query: String) -> String? {
        guard let language = NLLanguageRecognizer.dominantLanguage(for: query), language != .undetermined
        else { return nil }
        return language.rawValue
    }

    /// True when every letter is Latin (Basic Latin to Latin Extended, with combining accents).
    private static func isLatin(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { scalar in
            guard scalar.properties.isAlphabetic else { return true }
            switch scalar.value {
            case 0x0041...0x024F, 0x0300...0x036F, 0x1E00...0x1EFF, 0x2C60...0x2C7F, 0xA720...0xA7FF: return true
            default: return false
            }
        }
    }
}
