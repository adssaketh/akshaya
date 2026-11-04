# Akshaya: PROGRESS

App name: Akshaya (spec placeholder "Pantry" is replaced everywhere). Repo: `adssaketh/akshaya`. Firebase Spark plan only.

## Status

| Phase | State |
| --- | --- |
| 0 Design research and design system | Built. Gets its first real analyze/test run in CI with Phase 1. |
| 1 Data model, database, pantry CRUD, add/use items | Built, not yet compiled (no SDK in the sandbox). First CI run will be the real check. |
| 2 to 8 | Not started |

## Phase 1: what is built

Drift database (schema v1), pantry CRUD, add/use/waste with FIFO and undo, pantry list with search/group/sort/status filter, item detail (batches, usage history, price history), 5-tab shell (only Pantry and Settings are live), CI.

### Files (new in Phase 1)

```
.github/workflows/android.yml                 bootstrap android/, analyze+test, debug APK
pubspec.yaml                                  riverpod, drift, drift_flutter, uuid (+ build_runner, drift_dev)
analysis_options.yaml                         excludes *.g.dart
.gitignore                                    + lib/**/*.g.dart
lib/main.dart, lib/app.dart
lib/core/time/clock.dart                      clockProvider, todayProvider (refresh on resume)
lib/core/util/{date_only,quantity,money}.dart
lib/core/ui/feedback.dart                     failureMessage, showMessage, showUndoSnackBar
lib/features/shell/app_shell.dart
lib/features/settings/settings_screen.dart    temporary: sample data + design gallery
lib/features/pantry/domain/                   entities, unit, fifo, stock_logic, pantry_query,
                                              failures, repository interface, sample data, categories
lib/features/pantry/data/database/            tables, converters, app_database (+ .g.dart generated in CI)
lib/features/pantry/data/drift_pantry_repository.dart
lib/features/pantry/presentation/             providers, pantry_screen, add_item_screen, item_form_screen,
                                              batch_form_screen, item_detail_screen, use_stock_sheet,
                                              pantry_actions, pantry_icons, widgets/
test/core/util_test.dart
test/features/pantry/domain/                  unit, stock_logic, fifo, pantry_query tests
test/features/pantry/data/                    repository tests (in-memory SQLite)
test/features/pantry/presentation/            pantry + add-item widget tests (fake repository)
```

### Key decisions

- applicationId `com.akshaya.app`; label "Akshaya".
- Drift `.g.dart` files are generated in CI and gitignored. Locally run `dart run build_runner build --delete-conflicting-outputs`.
- `android/` is created once by CI (`flutter create`), patched, and committed back by the workflow. Run `git pull --rebase` before your next push.
- Schema v1 has only what Phase 1 uses: categories, items, item_aliases, stock_batches, consumption_logs. Synced tables carry householdId (nullable), createdAt, updatedAt, updatedBy, isDeleted, syncStatus.
- Storage location is a fixed enum stored as its text key.
- Dates (purchase/expiry/opened) are stored as date-only text; instants (createdAt, updatedAt) as epoch millis. All expiry maths is by calendar day.
- Quantities are rounded to 3 decimals; units convert only g<->kg and ml<->L.
- Price is the total paid for the batch; unit price is derived.
- FIFO order = effective expiry (earlier of printed expiry or opened + use-within days), no-expiry batches last, then purchase date.
- Status priority: expired > expiring soon > low stock > fresh; nothing left = out of stock.
- Deletes are soft; every destructive action has an Undo snackbar (item delete, batch delete, use, waste).
- Swipe right = Use, swipe left = Delete, long-press = all actions. Rows are never removed by the swipe itself; the list updates from the DB.
- Typing an existing name in Add item adds stock to that item instead of failing as a duplicate.
- Dependencies use caret ranges, not exact pins. After the first green CI run, commit `pubspec.lock` to freeze versions.
- Voice and scan FABs are deferred to Phases 3 and 5; the Pantry FAB is just "Add item".

## Rules for later phases

1. Import `package:akshaya/core/design/design.dart`; use only its tokens, text styles and widgets.
2. Missing a token or widget? Add it to the design system first, with a test, then use it.
3. Use `ThemeMode.system` by default; the manual override arrives with Settings (Phase 8).

## Test checklist (you), Phase 1

1. `git pull --rebase`, then run the push script. Open the Actions tab: the `bootstrap`, `verify` and `build-apk` jobs should go green. Paste me any red log.
2. Download the `akshaya-debug-apk` artifact and install it.
3. Settings tab > Load sample data. Pantry should show 10 items across statuses (Fresh, Expiring, Expired, Low stock, Out of stock).
4. Search a sample item by its Telugu or Hindi alias (e.g. "biyyam", "chawal", "ullipaya"); it should match.
5. Group by Category / Location; sort by each option; tap a status chip to filter.
6. Add item: new item with quantity and expiry shortcut; type an existing name and confirm it adds stock rather than erroring.
7. Swipe right to Use: quick amounts, custom amount, using more than you have (should show an error), using across two batches (oldest expiry first). Undo.
8. Item detail: edit a batch, mark wasted, mark expired, delete batch (Undo each), check usage and price history.
9. Delete an item from the list and Undo.
10. Rotate, switch light/dark, set system font to 200%: nothing should overflow.
11. Kill and reopen the app: data persists; leave it overnight or change the date: statuses update on resume.

## Known issues

- Nothing has been compiled, analyzed or run (no Dart SDK in my sandbox). Code was reviewed by hand against upstream sources, but expect a few fixes from the first CI run (likely: lints, a Riverpod 3 or Drift 2.35 API detail, a widget-test finder).
- The CI auto-commit of `android/` means your local clone goes behind after the first run.
- Riverpod 3 retries failed providers by default; a persistent DB error may retry quietly before showing the error state.
- `sqlite3` native library is needed for repository tests in CI; the workflow installs `libsqlite3-dev`. If tests fail to find it, tell me.
- Settings tab is temporary (sample data + design gallery).
- No `google-services.json` is needed until Phase 6; the CI step is skipped when the secret is empty.

## Next: Phase 2 (shopping list + auto-suggestions)

Start in a new chat when you say so.

## Phase 0: what was built (unchanged)

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

