import Testing
@testable import ActivityForecast

/// The geocoding language picked for a query (specs/007 FR-003…FR-005). Candidates are fixed
/// here; in the app they are the user's preferred languages, then their keyboards.
@MainActor
@Suite("QueryLanguage: geocoding language from the query")
struct QueryLanguageTests {
    @Test("a non-Latin query uses the language recognised in it, hinted by the user's languages",
          arguments: [
              ("Мінск", ["en", "be"], "be"),
              ("Минск", ["en", "ru"], "ru"),
              ("Київ", ["en", "uk", "ru"], "uk"),
              ("北京", ["en", "zh"], "zh")
          ] as [(String, [String], String)])
    func nonLatinQuery(query: String, candidates: [String], expected: String) {
        #expect(QueryLanguage.fixed(candidates).code(for: query) == expected)
    }

    @Test("a Cyrillic query from an English-only user is never searched in English")
    func cyrillicWithoutHints() throws {
        let code = try #require(QueryLanguage.fixed(["en"]).code(for: "Минск"))
        #expect(code != "en")
    }

    @Test("a Latin query uses the first preferred language; English is the API default, so nil",
          arguments: [
              ("Paris", ["de", "en"], "de"),
              ("Wien", ["de"], "de"),
              ("Paris", ["en", "be"], nil),
              ("München", ["en"], nil),
              ("Paris", [], nil)
          ] as [(String, [String], String?)])
    func latinQuery(query: String, candidates: [String], expected: String?) {
        #expect(QueryLanguage.fixed(candidates).code(for: query) == expected)
    }

    @Test("a query with no recognisable language falls back to the first preferred language")
    func unrecognised() {
        #expect(QueryLanguage.fixed(["fr", "en"]).code(for: "12345") == "fr")
        #expect(QueryLanguage.fixed(["en"]).code(for: "12345") == nil)
    }

    @Test("candidates are language codes only, preferred first, without duplicates (FR-005)")
    func candidates() {
        #expect(QueryLanguage.languageCodes(
            from: ["en-GB", "be-BY", "emoji", "en-US", "dictation", "zh-Hans-CN", "uk"])
                == ["en", "be", "zh", "uk"])
    }
}
