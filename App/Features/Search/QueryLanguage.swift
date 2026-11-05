import Foundation
import NaturalLanguage
import UIKit

/// Picks the geocoding language for a search query (specs/007). Open-Meteo matches a query only
/// against names in that language and English, so "Мінск" must be searched in Belarusian.
///
/// - Queries made only of Latin letters match in any language, so they use the user's first
///   preferred language: it only sets the language of the results (FR-003, research R2).
/// - Other queries need the exact language (Минск finds nothing in `be`, Київ nothing in `ru`), so
///   the script decides (FR-004, research R3): the language `NLLanguageRecognizer` finds if it is
///   one of the user's; else the user's first language written in that script (NaturalLanguage
///   has no Belarusian, and short Cyrillic names often read as Kazakh or Bulgarian); else the
///   script's most likely language from CLDR (Cyrillic → Russian). With no language recognised at
///   all, the first preferred one.
///
/// English is the service default, so it is returned as `nil`.
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

    /// The language code to search `query` in, or `nil` for the service default (English).
    func code(for query: String) -> String? {
        let candidates = candidates()
        let code = Self.isLatin(query) ? candidates.first : Self.nonLatin(query, candidates: candidates)
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
        let code = identifier.split(separator: "-").first.map { $0.lowercased() } ?? ""
        return (2...3).contains(code.count) && code.allSatisfy(\.isLetter) ? code : nil
    }

    private static func nonLatin(_ query: String, candidates: [String]) -> String? {
        guard let recognised = recognised(query, hints: candidates) else { return candidates.first }
        if candidates.contains(languageCode(recognised) ?? "") { return languageCode(recognised) }
        let script = script(of: recognised)
        if let sameScript = candidates.first(where: { self.script(of: $0) == script }) { return sameScript }
        return script.flatMap { languageCode(Locale.Language(identifier: "und-\($0)").maximalIdentifier) }
    }

    /// ISO 15924 script of a language, e.g. `Cyrl` for `be`, `Hans` for `zh-Hans`.
    private static func script(of language: String) -> String? {
        Locale.Language(identifier: Locale.Language(identifier: language).maximalIdentifier).script?.identifier
    }

    /// The recognised language identifier, e.g. `uk` or `zh-Hans`.
    private static func recognised(_ query: String, hints: [String]) -> String? {
        let recognizer = NLLanguageRecognizer()
        if !hints.isEmpty {
            recognizer.languageHints = Dictionary(
                hints.map { (NLLanguage(rawValue: $0), 1.0 / Double(hints.count)) },
                uniquingKeysWith: max)
        }
        recognizer.processString(query)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
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
