# NewsBlur 17.0 independent translation review

Reviewed `es`, `fr`, `de`, `pt-BR`, `it`, `nl`, and `pl`. These languages were produced by a different translation agent. Compared all iOS/macOS/Android listing fields, release notes, subscription descriptions/benefits, and group copy against the finalized English sources.

Checked completeness and meaning; actual platform-specific features; the default-off, movement-only Reduce motion contract; continued fades; all four reading filters; phone discovery and tablet rotation fixes; Mac frame changes; tone and glossary vocabulary; immutable product IDs; account qualifications, listening allowances and reset day; subscription disclosures; unchanged canonical URLs; Apple shared names/subtitles; field limits and keyword UTF-8 bytes.

Compared UI terms directly with the shipped Apple Localizable.strings and Android strings.xml. The Spanish All label (Apple `Todos`, Android `Todo`), French Saved (Apple `Enregistré`, Android `Enregistrés`), and Italian Saved (Apple `Salvato`, Android `Salvati`) correctly retain their platform differences.

## Finding and correction

- Dutch: replaced `in- en uitvloeien` (flowing in/out) with `geleidelijk verschijnen en verdwijnen` (gradual appearance/disappearance). The earlier wording suggested movement while explaining movement reduction. Adjusted both listing descriptions/promotional text and release notes; the option name stays the shipped `Beweging verminderen`.
- No missing release facts, unsupported claims, changed URLs, altered product identifiers, or subscription-term changes found in the seven-language batch.

## Validation

- `ruby clients/store/validate.rb 17.0 --platform ios`: 21 languages, 294 fields passed.
- `ruby clients/store/validate.rb 17.0 --platform macos`: 21 languages, 294 fields passed.
- `ruby clients/store/validate.rb 17.0 --platform android`: 21 languages, 336 fields passed.
- `git diff --check`: passed.

No commits, store writes, or browser actions performed. This review covers text, not rendered storefront layouts or localized screenshots.
