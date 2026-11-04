# Data Model: App Icons

No runtime data and no `ForecastKit` changes. Two static "entities" from the spec:

## App icon
One motif, three appearance variants, all 1024×1024 PNG in `App/Resources/Assets.xcassets/AppIcon.appiconset/`.

| Variant | File | Catalog entry | Background |
|---|---|---|---|
| Default | `AppIcon.png` | no `appearances` | opaque gradient |
| Dark | `AppIcon-Dark.png` | `appearances: [{appearance: luminosity, value: dark}]` | transparent |
| Tinted | `AppIcon-Tinted.png` | `appearances: [{appearance: luminosity, value: tinted}]` | transparent, grayscale motif |

Rules: each variant uses the same motif (FR-002); no text (FR-003); the committed PNGs are the source of truth; change all three together (FR-004 provenance: research.md D1).

## Activity icon
A total, fixed mapping `Activity → SF Symbol name` (App target, `Activity.symbolName`). Exactly one symbol per activity, all distinct. Values in [research.md](./research.md) D4.

Rules: exhaustive (enforced by `switch`), distinct (review + preview), decorative to VoiceOver (FR-006).
