import Testing
@testable import ActivityForecast

/// The geocoding language picked for a query (specs/007 FR-003…FR-005): English unless the
/// query has non-ASCII characters. Candidates are fixed
/// here; in the app they are the user's preferred languages, then their keyboards.
@MainActor
@Suite("QueryLanguage: geocoding language from the query")
struct QueryLanguageTests {
    @Test("a non-Latin query uses the recognised language if it is the user's, else the user's in that script",
          arguments: [
              ("Мінск", ["en", "be"], "be"),
              ("Минск", ["en", "ru"], "ru"),
              ("Київ", ["en", "ru", "uk"], "uk"),
              ("Москва", ["de", "ru"], "ru"),
              ("北京", ["en", "zh"], "zh")
          ] as [(String, [String], String)])
    func nonLatinQuery(query: String, candidates: [String], expected: String) {
        #expect(QueryLanguage.fixed(candidates).code(for: query) == expected)
    }

    @Test("with none of the user's languages in that script, the script's likely language is used",
          arguments: [("Минск", "ru"), ("Москва", "ru"), ("Αθήνα", "el")])
    func scriptWithoutCandidate(query: String, expected: String) {
        // NaturalLanguage reads these as Kazakh or Bulgarian, where Open-Meteo finds nothing.
        #expect(QueryLanguage.fixed(["en"]).code(for: query) == expected)
    }

    @Test("a plain ASCII query is searched in English, the API default, whatever the user's languages",
          arguments: [
              ("Paris", ["de", "en"]),
              ("Wien", ["de"]),
              ("Paris", [])
          ] as [(String, [String])])
    func asciiQuery(query: String, candidates: [String]) {
        #expect(QueryLanguage.fixed(candidates).code(for: query) == nil)
    }

    @Test("an accented Latin query uses the user's first Latin-script language",
          arguments: [
              ("Kraków", ["pl", "en"], "pl"),
              ("Zürich", ["de", "en"], "de"),
              ("München", ["en"], nil)
          ] as [(String, [String], String?)])
    func accentedLatinQuery(query: String, candidates: [String], expected: String?) {
        #expect(QueryLanguage.fixed(candidates).code(for: query) == expected)
    }

    @Test("a query with no recognisable script is searched in English")
    func unrecognised() {
        #expect(QueryLanguage.fixed(["fr", "en"]).code(for: "12345") == nil)
    }

    @Test("candidates are language codes only, preferred first, without duplicates (FR-005)")
    func candidates() {
        #expect(QueryLanguage.languageCodes(
            from: ["en-GB", "be-BY", "emoji", "en-US", "dictation", "zh-Hans-CN", "uk"])
                == ["en", "be", "zh", "uk"])
    }
}
