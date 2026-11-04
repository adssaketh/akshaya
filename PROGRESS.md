# Akshaya: PROGRESS

App name: Akshaya (spec placeholder "Pantry" is replaced everywhere). Repo: `adssaketh/akshaya`. Firebase Spark plan only.

## Status

| Phase | State |
| --- | --- |
| 0 Design research and design system | Built, awaiting your test (see checklist). Not yet analyzed or run: the Dart SDK could not be downloaded in the build sandbox. |
| 1 Data model, database, pantry CRUD, add/use items | Not started. Start in a new chat when you say so. |
| 2 to 8 | Not started |

## Phase 0: what is built

Direction chosen: **A, Haldi** (terracotta, turmeric, cream; Fraunces + Nunito Sans; soft filled cards; round icons; vessel mark and kolam dot motif).

Research summary (patterns adopted): expiry-first sections; colour plus icon plus word for status; large countdown or count numbers; storage-location grouping; resolve actions (used / discarded / frozen); recipes from expiring items; fast add; low stock feeding the shopping list. Used only as inspiration, nothing copied.

### Files

```
.gitignore                                   (google-services.json is ignored)
analysis_options.yaml                        flutter_lints + strict modes
pubspec.yaml                                 minimal; Phase 1 extends it
assets/fonts/Fraunces-Variable.ttf
assets/fonts/NunitoSans-Variable.ttf
assets/fonts/OFL-Fraunces.txt
assets/fonts/OFL-NunitoSans.txt
assets/fonts/README.md
lib/core/design/README.md                    rules + usage
lib/core/design/design.dart                  barrel export
lib/core/design/tokens/akshaya_colors.dart   light + dark palettes (only file with hex values)
lib/core/design/tokens/layout_tokens.dart    AppSpacing, AppRadius, AppSizes
lib/core/design/tokens/status_kind.dart      StatusKind enum
lib/core/design/typography/akshaya_text.dart AkshayaFonts, AkshayaText
lib/core/design/theme/akshaya_theme.dart     AkshayaTheme.light()/dark()
lib/core/design/theme/design_context.dart    context.akColors, context.akText
lib/core/design/widgets/akshaya_header.dart
lib/core/design/widgets/akshaya_logo.dart
lib/core/design/widgets/kolam_motif.dart
lib/core/design/widgets/status_chip.dart
lib/core/design/widgets/summary_tile.dart
lib/core/design/widgets/item_card.dart
lib/core/design/widgets/section_header.dart
lib/core/design/widgets/empty_state.dart
lib/core/design/gallery/design_gallery_page.dart
test/core/design/akshaya_colors_test.dart
test/core/design/akshaya_theme_test.dart
test/core/design/design_widgets_test.dart
test/core/design/no_hardcoded_colors_test.dart
PROGRESS.md
```

### Key decisions

- Folder layout: feature-first. `lib/core/design/`, later `lib/core/...` and `lib/features/<feature>/`.
- Fonts: bundled variable TTFs in `assets/fonts`, declared in pubspec (works offline, no `google_fonts` package). Weight set via `fontVariations` (wght axis).
- Theme: Material 3 `ColorScheme` built from the tokens, plus a `ThemeExtension` (`AkshayaColors`) for status colours. Requires Flutter 3.27+.
- Status model: `StatusKind` = fresh, expiring, expired, lowStock, outOfStock. The spec lists "Out of stock" as a fifth chip, so it has its own neutral colours and icon. Domain code maps stock data to a kind.
- Status is never colour alone: each kind has its own icon and label.
- Contrast: every text/background pair is at least 4.5:1 (WCAG AA), checked by tests. One deliberate exception: primary icon on the selected nav indicator in light mode is 4.15:1 (icons need 3:1); the label text stays on the high-contrast text colour.
- No hard-coded colours outside `akshaya_colors.dart`: enforced by `no_hardcoded_colors_test.dart` (`Colors.transparent` allowed).
- Chips ellipsise at 144 dp so large system font sizes never overflow rows.
- Icons: Material rounded/outlined icons; category icons are chosen per item in Phase 1.

## Rules for later phases

1. Import `package:akshaya/core/design/design.dart`; use only its tokens, text styles and widgets.
2. Missing a token or widget? Add it to the design system first, with a test, then use it.
3. Phase 1 adds: full Flutter project (replaces the minimal pubspec), the GitHub Actions debug-APK workflow, `google-services.json` injected from a GitHub secret, and runs `flutter analyze` and `flutter test` in CI.
4. Use `ThemeMode.system` by default; the manual override arrives with Settings (Phase 8).

## Test checklist (you)

1. Run `bash push_phase0.sh` in Termux; confirm the commit appears at github.com/adssaketh/akshaya.
2. In Phase 1 the debug APK will open `DesignGalleryPage`; check light and dark mode, and system font size at 100% and 200%.
3. Check that Fraunces headings and Nunito Sans body text render (not the default Roboto).
4. Check that status chips read clearly in both modes, and that each status is understandable in greyscale (icon plus word).
5. Tell me anything to adjust (palette, radius, type sizes) before Phase 1 builds on it.

## Known issues

- Not compiled or tested yet: the build sandbox blocks the Dart SDK download (storage.googleapis.com returns 403), so `flutter analyze` and `flutter test` have not run. The code was reviewed by hand. CI in Phase 1 will be the first real run; expect to fix a small thing or two there.
- The `unnecessary_import` lint may flag `import 'dart:ui' show FontVariation;` in `akshaya_text.dart` if your Flutter version already re-exports it. Delete that line if so.
- The Phase 0 pubspec has no Android project; `flutter create` and the full project come in Phase 1.
- Fonts are variable fonts; if a device renders weights incorrectly, the fallback is static instances (tell me and I will swap them).

## Open items from the spec

- None blocking Phase 0. The spec's mention of "Pantry" as the app name is replaced by Akshaya in all files.
