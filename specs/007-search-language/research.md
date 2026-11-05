# Research: Search in the Query's Language

## R1 — Query detection over the active keyboard

**Decision**: detect from the text with `NLLanguageRecognizer`; use `UITextInputMode.activeInputModes` (enabled keyboards) and `Locale.preferredLanguages` as hints and fallback.

**Rationale**: `.searchable` hides its `UITextField`, so `textInputMode.primaryLanguage` needs a UIKit search field, re-testing the split-view/iPad/fold layout of specs/003. The keyboard is also not the text's language for pasted text, dictation or the emoji keyboard.

## R2 — Latin script uses the preferred language

**Verified live**: Latin-script names match whatever `language` is sent ("Minsk" with `pl`, "Paris" with `zh` or `be`); only the result names change. Language detection on short Latin strings is unreliable ("Wien", "Paris"), so the user's own language is the better choice: results read in a language they know.

## R3 — Limits

Non-Latin queries need the exact language (Минск with `be`, Київ with `ru`, 東京 with `ja` find nothing). Hints from the user's keyboards resolve the common cases; a retry in a second language was not added (extra request, little evidence of need).
