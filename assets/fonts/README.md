# Bundled fonts

Both are variable fonts from the Google Fonts repository, licensed under the SIL Open Font License 1.1 (see the `OFL-*.txt` files here).

| File | Family name in pubspec | Used for |
| --- | --- | --- |
| `Fraunces-Variable.ttf` | `Fraunces` | Headings, counts, item names |
| `NunitoSans-Variable.ttf` | `NunitoSans` | Body text, labels, buttons |

Source: https://github.com/google/fonts (`ofl/fraunces`, `ofl/nunitosans`).

Weights are selected through the `wght` axis (`fontVariations`) in `lib/core/design/typography/akshaya_text.dart`. Do not add static weights; keep one file per family.

Telugu and Hindi are input languages only; the app displays English, so no Indic fonts are bundled. If a later phase needs to render native-script text, add Noto Sans Telugu and Noto Sans Devanagari here and as fallbacks in `AkshayaText`.
