# Akshaya Patra: PROGRESS

App name: Akshaya Patra (spec placeholder "Pantry" is replaced everywhere; code package stays `akshaya`). Repo: `adssaketh/akshaya`. Firebase Spark plan only.

## Status

| Phase | State |
| --- | --- |
| 0 Design research and design system | Done. Green in CI. |
| 1 Data model, database, pantry CRUD, add/use items | Done. CI green, APK installed and checklist passed. |
| 2 Shopping list + auto-suggestions | Done. CI green (180 tests), APK installed and checklist passed. |
| 3 Barcode scanning + Open Food Facts | Done. CI green, APK installed and checked on device. |
| 4 Local notifications and background checks | Done. CI green, APK installed and checklist passed. |
| 5 Multilingual input (offline parser, then Gemini with daily cap) | Done. CI green after fix rounds, APK installed and checklist passed. |
| 6 Firebase auth, household sharing, sync, security rules | Done. CI green (incl. rules tests), Google sign-in, create/join by code and QR, two-way sync checked on two devices. |
| 7 Recipe suggestions | Done. CI green, checked on device. |
| 8 Dashboard, insights, backup/export, settings and usage | Done. CI green. |
| 9 Leftovers, cooked food, homemade items | Done. CI green. |
| 10 Inventory reconciliation (count mode) | Done. CI green, checked on device. |
| 11 Consumption forecasting, "What should I buy?" | Done. CI green, checked on device. |
| 12 Weekly meal planner and prep reminders | Done. CI green, checked on device. |
| 13 Food rescue, waste cost, actionable notifications | Done. CI green, checked on device. |
| 14 Home screen widgets, app shortcuts, travel mode | Built in 1.0.1. CI green (analyzer, tests, rules, signed APK); waiting for your device check. Needs a Firestore rules + indexes redeploy (trips). |
| In-app user guide with search (1.0.3) | Built. Waiting for CI and your device check. No schema change, no new packages, no rules redeploy. |
| Shortcut icons and smaller APK (1.0.4) | Built. Waiting for CI and your device check. Build config only. |
| Order screenshot import (1.0.9) | Built. Waiting for CI and your device check. One new package (ML Kit text recognition), no schema change, no rules redeploy. |

## Phase 2: what is built

Shopping tab (replaces the placeholder): multiple named lists, entries grouped by category, check-off into an "In basket" section, urgent entries first, recurring entries (daily / weekly / monthly), computed restock suggestions, "Done shopping" into the pantry (expiry and price only, plus one optional store field), share as plain text, undo on every destructive action. Drift schema v2 with a real migration.

### Files (new or changed in Phase 2)

```
pubspec.yaml                                      + share_plus ^13.3.1
.github/workflows/android.yml                     pubspec.lock is now committed whenever it changes
lib/core/design/design.dart                       + export checklist_card
lib/core/design/widgets/checklist_card.dart       NEW design widget: check-off row
lib/core/share/share_service.dart                 NEW ShareService + share_plus implementation
lib/features/shell/app_shell.dart                 Shopping tab is live
lib/features/pantry/data/database/app_database.dart   schema v2, onUpgrade, default list seed
lib/features/shopping/domain/
  shopping_enums.dart                             Recurrence (+ nextDue), AddedReason, ShoppingPriority
  shopping_entities.dart                          ShoppingList, ShoppingEntry, drafts, tokens, CheckoutLine/Result
  shopping_repository.dart                        interface
  shopping_suggestions.dart                       pure restock rules
  shopping_view.dart                              pure grouping / ordering
  shopping_share.dart                             plain-text share format
lib/features/shopping/data/
  database/shopping_tables.dart                   shopping_lists, shopping_entries
  drift_shopping_repository.dart                  incl. Done shopping transaction + undo
lib/features/shopping/presentation/
  providers.dart, shopping_screen.dart, shopping_actions.dart,
  entry_form_screen.dart, checkout_screen.dart
test/core/design/checklist_card_test.dart
test/features/shopping/domain/                    suggestions, view/recurrence/share, test data
test/features/shopping/data/                      repository + v1->v2 migration test
test/features/shopping/presentation/              fake repository, widget tests
```

### Key decisions (Phase 2)

- **Schema v2** adds `shopping_lists` and `shopping_entries`, both with the standard sync columns. Entries carry `recurrence` and `dueOn` (no separate rules table). `onUpgrade` creates both tables and the indexes, and seeds the default list. A test builds a v1 database, upgrades it, and checks the result.
- **Default list** has the fixed id `list_default` and the name "Shopping list" (renamable), so synced devices agree on it. The last list can never be deleted.
- **Entries always store an English `name`**; `itemId` is set when the entry is linked to a pantry item (picked from the autocomplete, or typed exactly as an item name or alias).
- **Suggestions are computed, not stored.** Out of stock (only if the item was ever bought or is essential), everything left is past its date, or usable stock at or below the low-stock level. Expired stock does not count as stock. Quantity = what was bought last time. Items already on any list (by item or name) are skipped. "Dismiss" lasts until the app restarts. Out of stock is saved as reason `lowStock`, because the spec has no out-of-stock reason.
- **Adding a duplicate merges** into the unchecked entry already on that list (same item or name, convertible unit, same repeat) by adding the quantity; urgent wins.
- **Recurrence:** buying a repeating entry unchecks it, sets `dueOn` to the next date from today, and marks it reason `recurring`. Until due it sits in a collapsed "Repeats later" section and cannot be ticked.
- **Done shopping** runs in one transaction. Linked entry adds a batch to the item; a free-text entry reuses the pantry item with the same name or creates one (category Other, entry's unit). Purchase date = today, location = the item's usual one. Any failure (for example a unit that cannot convert) rolls everything back. Undo removes the batches and any new items and restores the entries as they were.
- **Price semantics** match Phase 1: price is the total paid for that entry's batch. Prices accept "1,250".
- **Share** uses the system share sheet (`share_plus`); if it cannot open, the text is copied to the clipboard instead. Only unchecked, due entries are shared.
- **FABs need unique `heroTag`s** because every tab stays alive in the IndexedStack. The Shopping FAB uses `shopping-add-fab`; give each later tab its own.
- **Design system:** added `ChecklistCard` (with tests). Everything else uses existing tokens.

## Phase 1: what was built (unchanged)

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
4. Give every FAB a unique `heroTag`.

## Test checklist (you), Phase 2 (passed)

1. Run the push script, then open the Actions tab. `verify` (analyze + tests) and `build-apk` should go green. Paste me any red log. CI will also commit an updated `pubspec.lock` (adds `share_plus`): run `git pull --rebase` before your next push.
2. Install the new APK over the old one. Your pantry data must still be there (this exercises the v1 to v2 migration). Shopping tab shows "Shopping list" and an empty state.
3. Settings > Load sample data. Shopping tab should show **Suggested for you (4)**: Tomato (out of stock), Curd (expired), then Onion and Toor Dal (low stock), each with "buy" = the last purchase size. Rice, Milk, Ghee, Turmeric, Atta and Peanuts must not appear. Nothing is added by itself.
4. Tap the + on one suggestion: it joins the list, quantity = what you bought last time, a reason chip shows. Tap Add all; tap the x on one to dismiss it.
5. Add item: type a pantry name or an alias ("biyyam", "chawal"): the pantry item is suggested; pick it. The unit list narrows to units that convert. Add a free-text item ("Candles", 4 pcs). Add the same item twice: one entry, quantities added.
6. Mark one entry Urgent (it sorts first). Give another a Repeat of "Every week".
7. Tick a few entries: they move to **In basket** and a **Done shopping (n)** button appears. Untick one.
8. Swipe an entry left: removed, Undo brings it back. Tap an entry to edit it, change its list.
9. New list "DMart", add something, switch between lists (chips show the open count). Rename it, delete it (Undo restores its entries). Try to delete the only list (should refuse).
10. Done shopping: add expiry with the shortcut chips, a price like 1,250, and a store. Confirm. Pantry shows the new stock (batch details: today's date, your price/store). The free-text item now exists in the pantry under Other. Undo works and removes the stock again.
11. The weekly-repeat entry: after Done shopping it returns unchecked under "Repeats later", dated 7 days ahead.
12. List menu > Share as text: WhatsApp preview shows the list by category.
13. Rotate, dark mode, system font at 200%: no overflow.

## Known issues

- Free-text entries become pantry items in category **Other** with no low-stock level; edit them in Pantry afterwards.
- Dismissed suggestions come back after an app restart (not stored).
- Phase 1's batch form still reads a price like "1,250" as 1.25 (it treats the comma as a decimal point). Done shopping handles it correctly. I can fix the Phase 1 form in the next phase.
- Voice entry (reason `voice`) and recipe entries (reason `recipe`) are in the data model but arrive in Phases 5 and 7. Daily "low stock" notifications arrive in Phase 4.
- Settings tab is still temporary (sample data + design gallery).

## Phase 3: what is built

Scan a barcode from the Pantry screen (small scan FAB) or from Add item (scan icon in the app bar). A known barcode opens "Add stock" for that item. An unknown one is looked up on Open Food Facts and pre-fills name, brand, pack size (quantity and unit) and a guessed category. If the product is not found, or the phone is offline, you get the plain form with the barcode kept. A camera problem offers "Type the barcode" (check digit validated). Also: app renamed **Akshaya Patra** with a new basket logo and launcher icon, and the motif is now `SarukuluMotif`.

### Files (new or changed in Phase 3)

```
pubspec.yaml                                      + http ^1.2.0, mobile_scanner ^7.5.0
.github/workflows/android.yml                     bootstrap uses new applicationId + label
android/app/build.gradle.kts                      applicationId com.akshayapatra.app
android/app/src/main/AndroidManifest.xml          label, INTERNET, CAMERA, optional camera features
android/app/src/main/res/...                      launcher icons (legacy, adaptive, monochrome, background)
assets/branding/                                  akshaya_patra_logo.svg, akshaya_patra_icon_512.png
tool/generate_launcher_icons.py                   Pillow script that draws logo B and writes all icons
lib/core/util/barcode.dart                        NEW canonical form, check digit, lookup variants
lib/core/design/widgets/akshaya_logo.dart         basket logo painter (tokens only)
lib/core/design/widgets/sarukulu_motif.dart       renamed from kolam_motif.dart
lib/core/design/{design.dart,README.md,tokens/layout_tokens.dart,widgets/akshaya_header.dart,widgets/empty_state.dart}
lib/app.dart                                      title
lib/features/scanning/domain/                     product_info, product_lookup, scan_service
lib/features/scanning/data/                       open_food_facts_client, cached_product_lookup, database/scanning_tables
lib/features/scanning/presentation/               providers, barcode_scan_screen, scan_flow
lib/features/pantry/data/database/app_database.dart   schema v3 + migration
lib/features/pantry/domain/pantry_repository.dart     + addBarcode
lib/features/pantry/data/drift_pantry_repository.dart barcode lookups via item_barcodes
lib/features/pantry/presentation/{add_item_screen,pantry_actions,pantry_screen}.dart
lib/features/pantry/presentation/widgets/item_fields.dart  barcode helper text
test/core/barcode_test.dart
test/core/design/design_widgets_test.dart
test/features/pantry/presentation/fake_repository.dart
test/features/scanning/{domain,data,presentation}/    product_info, scan_service, OFF client, cache, repository + v2->v3 migration, widgets
```

### Key decisions (Phase 3)

- **Schema v3** adds `item_barcodes` (one item, many barcodes; not unique in SQL so deleted items keep their rows for Undo; the repository only matches live items) and `product_cache` (local only). `items.barcode` already existed, so it stays as the item's main barcode, and the migration copies existing values into `item_barcodes`.
- **Canonical barcodes:** UPC-A becomes EAN-13 (leading zero), zero-padded GTIN-14 becomes EAN-13. Lookups try both spellings. Check digits are validated only for typed codes.
- **Open Food Facts:** `GET /api/v2/product/{barcode}.json` with a fields filter; 8 s timeout; generic User-Agent, nothing personal sent. Found products cached 30 days, unknown barcodes 1 day, an expired found entry is used when offline, failures are never cached.
- **Pack size** is parsed from the product's quantity text ("500 g", "1,5 l", "6 x 100 g"); 1000 g or more shows as kg, 1000 ml or more as L.
- **Category** is a heuristic from Open Food Facts category tags; falls back to Other. Always editable.
- **Same barcode, existing item:** scanning opens Add stock for it. Scanning a new barcode and naming an existing item links the barcode to that item instead of creating a duplicate. A barcode owned by another item is refused.
- **Logo B** (basket with handle, bottle, carrot, greens). The launcher icon uses the same geometry, simplified to fit the adaptive safe zone. The in-app painter, the SVG and the Python script are kept in sync by hand.
- **applicationId** is `com.akshayapatra.app` (fresh install). Namespace and MainActivity stay `com.akshaya.akshaya`.
- **Two FABs on Pantry** (scan + Add item) with heroTags `pantry-scan-fab` and `pantry-add-fab`.

## Test checklist (you), Phase 3

1. Run the push script (it removes the old `kolam_motif.dart`). `verify` and `build-apk` in Actions: paste me any red log. CI also commits an updated `pubspec.lock`, so run `git pull --rebase` before the next push.
2. The new app installs **next to** the old one (new applicationId) with an empty pantry. Uninstall the old app when ready. Launcher icon and name show "Akshaya Patra"; the header shows the basket logo.
3. Pantry > scan button. Camera permission prompt appears only now. Deny it once: the screen offers "Type the barcode".
4. Scan a packaged product with internet on (Amul, Parle-G, Maggi...). Add item opens with name, brand, quantity, unit and category filled and a "Filled in from Open Food Facts" note. Add expiry, save. Item appears.
5. Scan the same pack again: "Add stock" for the existing item, no duplicate.
6. Scan something Open Food Facts does not know (a local-shop item): form opens empty with the barcode and a "does not know this barcode" note. Name it, save.
7. Airplane mode, scan a new product: "Could not reach Open Food Facts" note, manual entry works, barcode kept. Scan a product you looked up earlier in airplane mode: it still fills in from the cache.
8. Torch toggle works; the phone vibrates on a successful read.
9. Type a barcode with a wrong last digit: rejected with a typo message. A valid one is accepted.
10. Add item screen: scan icon in the app bar fills the form the same way. Scanning a second pack size of an existing item (name it the same) links both barcodes to that one item.
11. Rotate, dark mode, font scale 200%: no overflow on the scan screen and the new note banner.

## Known issues (Phase 3)

- Verified in CI and on device after one analyzer fix (join query type, private named formals).
- The migration test, `product_cache` table and the extra `payload` column are mine; `product_cache` was not part of the schema question you answered.
- Open Food Facts asks apps to send contact details in the User-Agent. I used a generic one; add yours in `open_food_facts_client.dart` if you want.
- The product image from Open Food Facts is not stored or shown (no image UI yet).
- UPC-E (8 digits starting with 0 or 1) and EAN-8 are ambiguous on some labels; the scanner reports them as read.
- Category mapping is a heuristic and can be wrong for unusual products.
- Phase 1's batch form read a price like "1,250" as 1.25: fixed in Phase 4.
- Barcode scanning needs a real device camera; emulators will not read codes.
- Reinstalling under the new applicationId loses old data; there is no export until Phase 8.

## Phase 4: what is built

A daily local alert at a time you choose (default 8:00 am, Asia/Kolkata), up to three grouped notifications: **Expired**, **Expiring** (today and the next N days, default 3) and **Low stock**. Each tap opens its own list: Pantry filtered to Expired, Pantry filtered to Expiring soon, or the Shopping tab (restock suggestions on top). The opened-item rule (earlier of printed expiry or opened + use-within days) comes from the existing `StockLogic`, so alerts and the Pantry statuses always agree. A periodic WorkManager check (every 6 h) re-plans the alerts even if the app is never opened. Settings has a new "Alerts" block: switch, time, window (1 to 14 days), include low stock, permission banner, and "Show today's alert now". Notification permission is asked once on first run (with an explanation) and again from Settings; declining just leaves the banner. Also fixed: Phase 1 batch form read "1,250" as 1.25 (now `parseMoney`).

### Files (new or changed in Phase 4)

```
pubspec.yaml                                      + flutter_local_notifications ^22.3.3, timezone (>=0.10.1 <0.12.0), workmanager ^0.10.10
android/app/build.gradle.kts                      core library desugaring, multidex
android/app/src/main/AndroidManifest.xml          POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, notification receivers
lib/main.dart                                     expiryWarningDaysProvider follows the saved setting
lib/app.dart                                      starts alertCoordinatorProvider; re-checks permission on resume
lib/core/util/money.dart                          + parseMoney
lib/features/pantry/data/database/app_database.dart   schema v4 (+ app_settings), migration
lib/features/pantry/data/database/open_database.dart  NEW openAppDatabase() (busy_timeout, shared with the worker)
lib/features/pantry/presentation/providers.dart   uses openAppDatabase
lib/features/pantry/presentation/widgets/stock_fields.dart   price via parseMoney
lib/features/shopping/presentation/checkout_screen.dart      price via parseMoney
lib/features/shell/app_shell.dart                 opens the tapped alert's list; first-run prompt
lib/features/settings/settings_screen.dart        + Alerts block
lib/features/settings/domain/settings_repository.dart
lib/features/settings/data/{drift_settings_repository.dart,database/settings_tables.dart}
lib/features/settings/presentation/providers.dart
lib/features/alerts/domain/
  alert_settings.dart, alert_digest.dart, alert_plan.dart, alert_schedule.dart,
  alert_scheduler.dart, notification_gateway.dart, background_work.dart
lib/features/alerts/data/
  local_notification_gateway.dart, alert_worker.dart, workmanager_background_work.dart
lib/features/alerts/presentation/
  providers.dart, alerts_section.dart, first_run_prompt.dart
test/core/util_test.dart                          + parseMoney
test/features/pantry/presentation/stock_fields_price_test.dart
test/features/settings/{fake_settings_repository.dart,data/settings_repository_test.dart}   incl. v3->v4 migration
test/features/alerts/{fake_notification_gateway.dart,domain/*,data/alert_worker_test.dart,presentation/alerts_widgets_test.dart}
```

### Key decisions (Phase 4)

- **Schema v4** adds `app_settings` (key/value text, local only). Alert settings live there; Phase 8 reuses it for the other settings.
- **Fixed Asia/Kolkata** time zone (no device time-zone lookup). Wall-clock times are carried as UTC-labelled `DateTime`s, so no DST maths exists.
- **Inexact alarms** (`inexactAllowWhileIdle`): no exact-alarm permission. An alert can arrive a few minutes late.
- **Scheduled notifications have fixed text**, so the app schedules the next 3 days, each with that day's own content, and re-plans on any change to settings, pantry or lists, on a new day, and every 6 h from WorkManager. If the worker is delayed, the 3-day buffer still covers you.
- **Only pending notifications are cancelled** when re-planning, so an alert already in the shade stays. Alerts time out after 18 h.
- **Pantry data is read from already-loaded providers, never `await provider.future`** (that hung in tests when nothing was listening). The coordinator and the preview both listen first, then read `.value`.
- **Worker isolate opens its own DB connection** with `busy_timeout = 5000`; the migration is safe if the worker runs it first.
- **Low stock excludes "expired"** suggestions (those are already in the Expired alert).
- **"Expiring soon" days drives the Pantry status too** (one setting, one meaning).
- Nothing is scheduled on days with nothing to say.

## Test checklist (you), Phase 4

1. Push, then check Actions: `verify` and `build-apk`. Paste me any red log (I could not run the analyzer locally). Run `git pull --rebase` before the next push.
2. Install the APK over Phase 3 (data must survive: v3 to v4 migration). First launch: a "Daily expiry alerts" dialog. Tap Allow, grant the system prompt.
3. Settings > Load sample data, then Alerts > "Show today's alert now": up to three notifications appear (Expired, Expiring, Low stock). Expand one: the body lists names with days.
4. Tap each: Expired and Expiring open Pantry with that status filter set; Low stock opens Shopping. Do it with the app in the background and with it closed.
5. Set the alert time 2 minutes ahead, lock the phone: the alert arrives (a few minutes late is normal on some phones).
6. Change "Expiring soon means" to 7: the Pantry "Expiring soon" chip count changes to match.
7. Switch "Include low stock" off, then "Daily alert" off: nothing further is scheduled (re-check at the set time).
8. Deny the permission (system settings > Akshaya Patra > Notifications off), return to the app: the banner appears; "Allow notifications" / "Open settings" works.
9. Restart the phone: alerts are still scheduled (open the app once if your phone's battery saver blocks the boot receiver).
10. Add a batch price of "1,250": detail shows ₹1250.
11. Dark mode and 200% font scale on the Alerts block: no overflow.

## Known issues (Phase 4)

- I could not run `flutter analyze` or tests locally; CI needed four rounds (unused imports, two test bugs, the stream-read hang). Now green.
- Alerts are inexact and can be several minutes late. Some phone makers (Xiaomi, Oppo, Vivo, Samsung battery saver) stop background work; the 3-day schedule still fires, but the content is only as fresh as the last time the app or worker ran.
- A day's text is fixed when it is scheduled: stock used after that is reflected at the next re-plan (any change in the app triggers one).
- No custom notification sound, action buttons or per-item snooze.
- The Settings tab is still temporary (sample data, design gallery, Alerts block). Phase 8 builds the full screen.
- Notification title/body are English only (as the spec requires).

## Phase 5: what is built

Mic button in the header of every main tab (Home, Pantry, Shopping, Recipes placeholders, Settings). Tap it: speak (phone speech recogniser, `en-IN`, `te-IN` or `hi-IN`) or type, and the words go through the pipeline **offline parser -> (only if not confident and AI is allowed) Gemini with a strict JSON schema -> app validates -> confirmation card -> you confirm or edit -> action runs -> Undo**. Nothing is executed from AI output without the card.

Also in this change: the launcher icon artwork is bigger inside its tile (legacy icon 0.70 -> 0.82 of the tile, adaptive foreground 50/108 -> 60/108; the artwork still sits inside the 66/108 adaptive safe zone).

### Files (new or changed in Phase 5)

```
assets/dictionary/grocery_dictionary.json          NEW 138 products, 1100+ words (en/te/hi, script + romanised)
assets/prompts/parse_command.txt                   NEW Gemini prompt template (parsing)
tool/offline_words/                                NEW generator: tables.py, dictionary_source.txt, generate.py, README.md
tool/generate_launcher_icons.py                    bigger artwork
android/app/src/main/res/{mipmap,drawable}-*/      regenerated launcher PNGs; assets/branding/akshaya_patra_icon_512.png
pubspec.yaml                                       + firebase_core, firebase_ai, firebase_app_check, firebase_remote_config, speech_to_text, record; + assets
android/app/src/main/AndroidManifest.xml           + RECORD_AUDIO, microphone feature (optional), RecognitionService query
.github/workflows/android.yml                      Firebase settings from the secret -> --dart-define (no google-services plugin)
lib/features/commands/domain/
  text_normalizer.dart                             lower-case, nukta/ZWJ/digit folding, tokenizer, phonetic key
  parser_words.dart                                GENERATED numbers, units, intent words, separators, filler words
  grocery_dictionary.dart, grocery_lexicon.dart    dictionary + the pantry's own names/aliases, longest match
  offline_command_parser.dart                      clauses, quantity groups, intent, confidence
  command_models.dart                              CommandIntent (the 7 schema intents), CommandAction, CommandInterpretation
  command_service.dart                             offline first, AI only if unsure and allowed
  command_executor.dart                            runs confirmed actions, per-action outcome + undo
  voice_language.dart, speech_gateway.dart         language choice; speech/recorder interfaces
lib/features/commands/data/                        speech_to_text_gateway.dart, record_audio_gateway.dart
lib/features/commands/presentation/                providers, voice_mic_button, command_input_sheet,
                                                   command_confirmation_sheet, command_flow
lib/features/ai/domain/                            ai_settings, ai_gate, ai_failures, ai_response_validator, ai_command_service
lib/features/ai/data/                              firebase_runtime (lazy init, App Check, Remote Config),
                                                   firebase_generative_backend (Firebase AI Logic)
lib/features/ai/presentation/                      providers, ai_voice_section (Settings), ai_notice_dialog
lib/features/{pantry,shopping,shell,settings}/...  mic button in the header; AI and voice block in Settings
test/features/commands/, test/features/ai/         parser (3 languages, both scripts), dictionary sanity,
                                                   normalizer, service, executor, confirmation card, validator, gate, daily cap
```

### Key decisions (Phase 5)

- **Offline first.** Longest-match item lookup over the dictionary plus your own item names and aliases (yours win, and a dictionary product you already have, such as "rice" when you have "Basmati Rice", resolves to *your* item, so no duplicates). Unknown spellings are matched by a phonetic key and plural/case stems, not fuzzy edit distance (it produced false hits). Function words ("cheyyi", "khatam", "mein") are matched exactly only.
- **Confident** only if no word was unknown, every clause has an intent and every item-needing action found an item. Otherwise the AI is asked (if allowed) or the card opens with a "not sure, please check" line.
- **Intent rules:** need/list words -> shopping list; "bought" -> pantry; bare "add" -> pantry, but the shopping list when the mic is tapped on the Shopping tab; remove > finished > use > expiring > how much. Two different kinds of request in one clause (for example "milk khatam add karo") are flagged, not guessed.
- **AI gate order:** off -> not configured -> notice not accepted -> daily cap reached -> cooling down after a quota error -> ready. Every attempt (including retries) counts against the cap before it is sent. Backoff 1 s then 2 s on server errors; quota (429) and offline errors are not retried; a quota error pauses AI for one minute. 20 s timeout. All failures fall back to the offline reading with a one-line reason; nothing is lost.
- **Privacy:** only the typed/spoken grocery text (max 300 chars, control characters and template markers stripped), up to 150 pantry item *names*, today's date and the language name are sent. No user, household, location or alias data. The text is fenced in the prompt and marked as data. One-time notice (declining turns AI off; Settings can turn it on again, which shows the notice again).
- **Validation:** the whole AI answer is rejected if any action has an unknown intent, a missing item name, a bad/zero/huge quantity, an unknown unit or location, or an impossible date. Then the offline reading is kept.
- **Firebase without the google-services plugin.** AGP 9 + the Gradle plugin is a build risk, so the app initialises Firebase lazily from `--dart-define` values (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`). CI derives them from your `GOOGLE_SERVICES_JSON` secret (client for package `com.akshayapatra.app`) and masks them. No secret -> the app builds and AI stays in offline mode. Startup speed is unchanged because Firebase starts only on the first AI call.
- **Model name** is the Remote Config key `gemini_model_name` (default `gemini-3.8-flash`, used until a fetch succeeds).
- **Aliases grow:** a new item created by a command stores your word ("kandi pappu") as an alias; when the AI read the command, an existing item also learns the new word, so next time no AI call is needed.
- **Voice:** the phone's recogniser first. If the phone has none, and AI is allowed, it records up to 10 s of 16 kHz WAV, sends it to Gemini for transcription, and deletes the file. Otherwise you are told to type.
- **Executor details:** mark finished uses the item's remaining total (retries with the exact available amount on rounding); shopping adds merge into an existing entry and undo restores the old quantity; an unknown product on the shopping list becomes a free-text entry (it becomes a pantry item at "Done shopping"); unit mismatches (litres for a kg item) are refused with a message; one failing action never stops the others.

### Spec notes to be aware of

- The dictionary has 138 products and about 1,100 words/spellings (the spec said ~300 words); extend it by editing `tool/offline_words/dictionary_source.txt` (see the README there).
- Docs do not explicitly say the Gemini Developer API free tier works with App Check on a Spark project with no billing account; it should, but this is the first thing to confirm on device.
- Gemini audio is used only as the fallback when the phone has no speech recogniser, so it adds the `record` package.

## Test checklist (you), Phase 5

Before anything: push, wait for CI. If `flutter analyze` or tests fail, paste the output; this phase was written without a compiler.

Offline (turn on airplane mode, or leave the secret unset):
1. Tap the mic on Pantry. Say or type: "add 1 litre milk, 6 eggs and half kilo tomatoes". The card shows what was heard, three English lines (Milk 1 L, Eggs 6, Tomato 0.5 kg), and "Understood on your phone". Confirm: they appear in the pantry with an Undo snackbar. Undo removes them.
2. Type (or say) each of: "rendu kilo biyyam add cheyyi", "do kilo chawal list mein daalo", "milk ayipoyindi", "half packet ravva vaadesanu". Check the card text before confirming each. Native script: "రెండు కిలోలు బియ్యం యాడ్ చేయి", "दो किलो चावल लिस्ट में डालो".
3. On the Shopping tab, "eggs 12 add" goes to the shopping list; on the Pantry tab it goes to the pantry.
4. "what is expiring" and "dahi kitna hai" show an answer sheet and change nothing.
5. Edit a name, quantity and unit on the card before confirming; remove a line; "Change words" returns to the text.
6. Type nonsense ("xyzzy 2 kg add"): the card says it is not sure and shows "Xyzzy" as a new item; Cancel changes nothing.
7. Say a word for an item you already have with an alias (add alias "biyyam" to Rice first). It must update Rice, not create a second item.
8. Mic permission: first tap shows the explanation, then the system prompt. Deny it: you get a message and can still type.

With AI (secret set, notice accepted):
9. First mic tap shows the AI notice. "Use offline only" turns AI off in Settings.
10. Type a hard sentence ("amma ki 2 kilos kandi pappu and oka dabba nuvvulu kavali"). The card says "Read by AI (Google Gemini). Please check it." Confirm, and the new words are saved as aliases (item detail).
11. Settings -> AI and voice: calls today increase by one per AI read. Set the limit to 5 and use it up: you see "AI limit reached for today, using offline mode." and commands still work offline.
12. Turn AI off: no AI calls at all.
13. Debug APK: register the App Check debug token (logcat shows it on first AI call) in Firebase console -> App Check -> Apps -> Manage debug tokens, otherwise AI calls are rejected and you stay offline.

## Known issues (Phase 5)

- Not compiled or run locally. Package versions for the Firebase and speech packages are lower bounds (`^`); after the first green CI, tell me the resolved versions and I will pin them. If `AndroidProvider.debug/playIntegrity` or a `firebase_ai` signature differs in the resolved version, CI will say so.
- Several different intents in one sentence with no separator ("add rice and milk finished") can fall back to the AI or manual edit. Say them as separate commands or use commas.
- A mixed-intent clause is never guessed; the card opens with whatever was understood and a warning.
- Quantities spoken as words beyond twelve (thirteen, fourteen, ...) are digits-only offline; the AI handles the rest.
- Items spoken for the shopping list that are not in the pantry become free-text entries.
- Recipes and Home are still placeholders (mic button is there; "Recipes" and "Home" commands arrive with Phases 7 and 8).
- Phase 4 device checklist: passed (confirmed after this phase).

## Phase 6: what is built

Optional sign-in (Google, email/password), households (create, join by 8-character code or QR, owner removes members, new code, leave), two-way Firestore sync with Drift as the UI source, household change alerts, security rules with emulator tests. The app is fully usable without signing in or without a Firebase config.

### Files (new or changed in Phase 6)

```
pubspec.yaml                                       + firebase_auth, cloud_firestore, qr_flutter
firestore.rules / firestore.indexes.json / firebase.json
firebase/                                          rules tests (@firebase/rules-unit-testing, node --test)
docs/FIREBASE_SETUP.md                             Spark-only setup, SHA-1, rules deploy, quota notes
.github/workflows/android.yml                      web client id define, stable debug keystore, rules-tests job
lib/app.dart                                       starts sync coordinator; pause/resume listeners with the app
lib/core/design/tokens/layout_tokens.dart          + qrCode, qrScanFrame sizes
lib/features/ai/data/firebase_runtime.dart         + FIREBASE_WEB_CLIENT_ID
lib/features/pantry/data/database/app_database.dart schema v5 (4 sync tables + triggers)
lib/features/alerts/...                            household channel + 2 targets; worker also checks household changes
lib/features/shell/app_shell.dart                  opens Shopping/Pantry for household alerts
lib/features/settings/settings_screen.dart         + SyncSection
lib/features/sync/domain/                          schema, documents, merge rules, models, gateways, invite code, digest, settings
lib/features/sync/data/                            store, engine, Firestore remote/household/auth gateways, background check
lib/features/sync/data/database/                   sync tables and change-capture triggers
lib/features/sync/presentation/                    providers + controller + coordinator, sign-in, household screens, QR join, settings section
test/features/sync/                                merge, documents, invite code, digest, triggers, engine (fake remote), controller, v4->v5 migration, section widget
```

### Key decisions (Phase 6)

- **Schema v5, no change to existing tables.** Four new tables (`sync_state`, `sync_cursors`, `sync_batch_bases`, `household_members`) plus SQL triggers: any update to a synced row marks it `pending` unless `sync_state.suppress = 1`, so existing repositories needed no edits.
- **Delta queries use a server `syncedAt`** (not the client `updatedAt`, which is used for last-write-wins), so clock skew between phones cannot hide changes.
- **Batch quantity merge by difference:** `remote + (local - base)`, floored at 0. Two people using the same stock both count. Everything else is last-write-wins on `updatedAt`.
- **Transactions for pushes** (chunks of 20): they fail cleanly offline and keep rows pending; backoff 30 s to 15 min, 1 h on quota.
- **No Cloud Functions / FCM.** Alerts come from listeners while the app is open and a one-shot check in the existing WorkManager task.
- **Joining uses an invite-code document** that rules check; codes cannot be listed. Owner cannot leave (remove others instead).
- **Sign out keeps local data** unless "Clear data" is chosen. Joining a different household asks: add my data or start fresh.
- **Firebase starts only when someone is in a household.**

### Spec notes to be aware of

- Categories are synced too (not in the spec list) because items point at them.
- `image_path` is not synced (local path, no Storage uploads).
- The QR code is drawn black on white in every theme so it scans (tokens `AkshayaColors.qrForeground` and `qrBackground`).

## Test checklist (you), Phase 6

Set up first: `docs/FIREBASE_SETUP.md` (Google + Email providers, Firestore, rules + indexes, SHA-1 matching the CI keystore, secrets). CI must be green, including the `rules-tests` job.

1. Install the APK with no Firebase secret: Settings shows "Sync is not set up in this build"; everything else works.
2. With the secret: Settings > Household & sync > sign in with email (register). Cancel mid-way: app still works.
3. Sign in with Google (needs SHA-1 registered and a fresh google-services.json).
4. Create a household: invite code and QR shown; your pantry uploads (watch Firestore console, collection `households/<id>/items`).
5. On a second phone/account: Join with the code, then with the QR. Choose "Add my data" once and "Start fresh" once.
6. Add an item on phone A: it appears on B within seconds. Check off a shopping entry on B: A updates.
7. Use 1 of the same batch on both phones, one offline then online: the total drops by 2, not 1.
8. Edit the same item name on both: the later edit wins.
9. Airplane mode: edit, then reconnect: status goes Offline -> Synced; "Sync now" works.
10. Household alert: with A in the background, add 3 shopping entries on B: A shows "<B's name> added 3 items to <list>". Tap it: Shopping tab opens.
11. Owner removes B: B's status shows "No longer a member"; B's pantry stays on B. Owner "New code" invalidates the old code.
12. Member leaves; sign out with "Keep data" then "Clear data".
13. Delete an item, wait/sync: it disappears on both (soft delete).
14. Settings shows today's estimated reads/writes.

## Known issues (Phase 6)

- Google sign-in uses Firebase's own provider flow (`signInWithProvider`), not the Android Credential Manager (it rejected the build with `[16] Account reauth failed`). Firebase package APIs are written from memory; if CI complains, send me the errors. Versions are `^` lower bounds; send the resolved versions to pin.
- Two simultaneous alert sources: if two collections deliver at once, a change in the older one can be treated as already seen and skip its alert (sync itself is unaffected).
- The background check cannot tell a new document from an edited one, so another member's edit to an entry can read as "added".
- A member removed while offline learns about it on the next connection.
- Usage numbers are an estimate of this phone only (other members' usage counts against the same project quota).
- Firestore setup lessons: create the database (Standard edition, `(default)`, production mode) and publish `firestore.rules` before first use; add every Google account you test with as a Test user (or publish the consent screen); the debug APK is signed with the cached CI keystore (SHA-1 D6:15:75:44:…:BE registered in Firebase).
- The seven composite indexes (`firestore.indexes.json`) are only for the daily purge of 30-day-old deletes; deploy them when you want that clean-up to work.

## Phase 7: what is built

Recipes tab (replaces the placeholder): AI recipe ideas from the pantry (expiring first), preferences (diet, cuisine, max time, people, avoid list), ideas ranked by expiring items used, recipe detail with live "in pantry / short / missing" labels, "Add missing" to the selected shopping list, "I cooked this" (confirm, edit amounts, FIFO deduction logged as cooked in recipe, Undo), saved recipes (synced to the household), last ideas cached for offline reading, no re-ask when the pantry and preferences are unchanged. Drift schema v6 with a real migration.

### Files (new or changed in Phase 7)

```
assets/prompts/generate_recipes.txt                 NEW recipe prompt template (separate file, as specified)
firestore.rules                                     + recipes/{id}
firestore.indexes.json                              + recipes index (now seven)
docs/FIREBASE_SETUP.md                              seven indexes
firebase/test/firestore.rules.test.js               + recipe rules test
lib/features/ai/domain/ai_command_service.dart      + guardedCall (recipes share the one cap and cooldown)
lib/features/ai/domain/ai_response_validator.dart   + public parseUnit
lib/features/pantry/data/database/app_database.dart schema v6 (saved_recipes, recipe_cache)
lib/features/sync/domain/sync_schema.dart           + recipes spec
lib/features/sync/data/database/sync_triggers.dart  + saved_recipes
lib/features/sync/data/sync_store.dart              pending count + Clear data cover recipes
lib/features/shell/app_shell.dart                   Recipes tab is live
lib/features/recipes/domain/
  recipe_models.dart                                diet, cuisine, preferences, Recipe, SavedRecipe, cache entry
  recipe_pantry.dart                                cookable pantry lines, expiring map
  recipe_fingerprint.dart                           "pantry unchanged" code
  recipe_matcher.dart                               ingredient to pantry matching + ranking
  recipe_validator.dart                             JSON schema check + diet / avoid safety filter
  recipe_prompt.dart                                fills the template (no personal data)
  ai_recipe_service.dart                            Gemini call through the shared AI gate
  cook_plan.dart                                    "I cooked this" plan, executor, undo
  recipe_shopping.dart                              missing ingredients to shopping drafts
  recipe_repository.dart                            interface
lib/features/recipes/data/
  database/recipe_tables.dart                       SavedRecipes (synced), RecipeCache (local)
  drift_recipe_repository.dart
  firebase_recipe_backend.dart                      Firebase AI Logic, JSON response schema
lib/features/recipes/presentation/
  providers.dart, recipes_screen.dart, recipe_card.dart, recipe_detail_screen.dart,
  cook_sheet.dart, preferences_sheet.dart
test/features/recipes/domain/                       models, pantry + fingerprint, matcher + ranker, validator + safety,
                                                    prompt, AI service, cook plan, shopping planner, shared support
test/features/recipes/data/                         repository + v5 to v6 migration
test/features/recipes/presentation/                 widget tests + controller tests
test/features/sync/domain/sync_documents_test.dart  collections list includes recipes
```

### Key decisions (Phase 7)

- **Schema v6:** `saved_recipes` is synced (standard sync columns; ingredients and steps are JSON text; collection `recipes`). `recipe_cache` is local only (one row, the last AI answer). `Clear data` also clears both.
- **Spec deviations:** a `diet` column (veg / egg / non_veg) replaces `isVeg`, so eggetarian works. The ingredient `in pantry / missing` flag from the AI is ignored; the app recomputes it from the live pantry on every change. Water and salt are assumed on hand and never shopped for or deducted.
- **Diet and avoid list are enforced in the app**, not only in the prompt. The avoid match is deliberately wide ("nut" also catches "coconut"). Default diet is vegetarian.
- **One AI budget:** recipes use `AiCommandService.guardedCall`, so the on/off switch, privacy notice, daily cap (every attempt counts), quota cooldown and retries are the same as for commands. An unusable answer is never retried.
- **Privacy:** the prompt carries only item names, amounts, units, dates and the cooking preferences. Free text is stripped of control characters and template markers.
- **No re-ask:** a fingerprint of cookable stock (name, quantity, unit, expiry) plus preferences is stored with the cache. Same fingerprint means "Ask again anyway" instead of "Get recipe ideas". Changing preferences or stock allows a new request.
- **Offline / AI off or capped:** cached ideas and saved recipes stay visible with the reason shown ("AI limit reached for today, using offline mode."). There is no offline recipe engine (your choice).
- **Matching is a heuristic** (stemming, brackets, aliases, dictionary synonyms, blocklist like powder/flour/paste). "I cooked this" shows every line with an editable amount; lines without a convertible amount start unticked.
- **Saved recipes** remember the matched item id per ingredient as a hint only.

## Test checklist (you), Phase 7

1. Open CI; confirm analyze, tests, the rules tests and the APK are green. Install the APK over the old one (the database upgrades from v5).
2. Pantry has food with a few items expiring within 3 days. Recipes tab shows the "Use these first" chips and your preferences line. Tap the line, change diet, cuisine, time, people and add an allergy ("peanuts"), save.
3. First time: "Get recipe ideas" shows the privacy notice. Allow. 3 to 5 recipes appear, those using expiring food first, each with a chip (uses N expiring / ready to cook / N missing). No recipe breaks your diet or contains your avoid word.
4. Tap the button again without changing the pantry: it now says "Ask again anyway" and a plain tap does not call AI (Settings, Usage shows no new call). "Ask again anyway" does call it.
5. Open a recipe: ingredients show In pantry / Short / Missing; salt and water show Assumed. Use an item in the Pantry, come back: labels update by themselves.
6. "Add missing": the Shopping tab shows only the missing/short items, noted "For <recipe>".
7. "I cooked this": amounts match the recipe, untick one, change one, confirm. The Pantry quantities drop (oldest batch first). Undo restores them. Item detail history shows "cooked in recipe".
8. Heart: recipe appears in Saved. Remove it, Undo brings it back. With the second device signed in to the same household, the saved recipe appears there too.
9. Airplane mode or AI off: cached ideas and saved recipes still open; the message explains why nothing new is generated. Reaching the daily cap shows "AI limit reached for today, using offline mode."
10. Settings, Clear data: Recipes ideas and Saved are cleared on this phone.

## Known issues (Phase 7)

- Written without a local Flutter SDK; CI is the compiler. Send me any analyzer or test errors.
- Not yet linked from the dashboard (arrives with the dashboard in Phase 8) or from expiry notifications (needs a new alert target; planned with Phase 8's dashboard).
- Ingredient matching can miss odd names (it errs towards "missing"); "I cooked this" lets you correct any line.
- Recipe quality and quantities are the model's; check amounts before cooking. The recipe is stored as you saw it, not re-generated.
- Deploy the new rules and the recipes index (`firebase deploy --only firestore:rules,firestore:indexes`) or saved recipes will not sync (rules reject unknown collections).
- Removing a saved recipe on one phone and saving the same recipe on another at once can leave two copies.

## Phase 8: what is built

Home dashboard (summary tiles, quick actions Voice / Scan / Add / Shopping, "Use these first" with "Get recipe ideas", Insights button), Insights (monthly spend trend and by category, waste report, "runs out in ~N days", price history by item and store), backup (JSON export/import via the system file picker, CSV of pantry and of usage history), expanded Settings, optional biometric app lock.

### Files
```
pubspec.yaml                                   + fl_chart, local_auth, file_picker
android/.../MainActivity.kt                    FlutterFragmentActivity (local_auth)
android/.../res/values/styles.xml              AppCompat launch theme (local_auth)
android/.../AndroidManifest.xml                + USE_BIOMETRIC
lib/app.dart                                   theme choice, currency symbol, AppLockGate
lib/core/util/money.dart                       currentCurrencySymbol
lib/features/home/presentation/home_screen.dart            NEW dashboard
lib/features/shell/app_shell.dart              Home tab wired
lib/features/insights/domain/insights.dart     NEW pure calculators
lib/features/insights/presentation/{providers,insights_screen}.dart   NEW
lib/features/backup/data/backup_service.dart   NEW JSON export + merge import
lib/features/backup/domain/{csv,backup_csv}.dart   NEW
lib/features/backup/presentation/{backup_files,backup_section}.dart  NEW
lib/features/lock/app_lock.dart                NEW lock gate + authenticator seam
lib/features/settings/domain/app_settings.dart NEW
lib/features/settings/presentation/{general_section,categories_screen}.dart  NEW
lib/features/settings/settings_screen.dart     rewritten
lib/features/pantry/...                        category add/rename/delete, watchAllHistory, default unit
test/...                                       insights, backup, app settings, app lock, categories
```

### Decisions
- Import merges by id; a row is replaced only when the file's `updated_at` is newer. All-or-nothing in one transaction. Settings and caches are not in backups.
- Currency is a global symbol (display only, no conversion).
- App lock keeps the app mounted underneath (state survives) and never locks a phone with no screen lock.
- Storage locations stay a fixed set (Fridge, Freezer, Pantry, Other).

## Test checklist (you), Phase 8
1. Home: tiles show right counts; tapping a tile opens the Pantry filtered; quick actions work; "Use these first" and "Get recipe ideas".
2. Insights: spend, waste, run-out and price history after a few purchases/uses.
3. Settings: theme, currency (prices relabel), default unit (new item), diet preferences, categories add/rename/icon/delete.
4. Backup: save JSON, restore on same phone (nothing duplicates), restore on a second phone/after clear; CSV files open in a spreadsheet.
5. App lock: turn on (prompts), background and reopen, unlock; turn off.
6. Usage sections (AI calls, Firestore writes) still show.

## Known issues (Phase 8)
- Recipes are not linked from expiry notifications.
- Storage locations are not editable.
- Currency symbol refreshes on screens when they rebuild; reopen a screen to see it.
- Category deletion has a confirmation, not an Undo.
- `file_picker`/`local_auth` calls are untested on device until your check.

## Motion smoothness fix (post Phase 8)

Symptom: every tab switch flashed blank, Home counters restarted (9 > 10 > 2 > 10), list rows and FABs re-animated.
Cause: `TabPane` and `Reveal` returned the bare child once finished but wrapped it in `Opacity`/`Transform` while animating. Changing the widget type at that spot made Flutter rebuild the whole screen from scratch at the start and end of each animation.
Fix:
- `TabPane`: fade and slide wrappers are always present; a tab starts at 40% opacity (never blank) and eases to 100%.
- `Reveal`: tree shape is decided once on first build; rows from index 10 on (or built with motion off) appear at once.
- Pantry and Shopping rows always pass their index (no more `index < 8 ? index : null`, which re-wrapped rows as the list changed). Pantry list rows have stable keys with `findChildIndexCallback`, so search/filter reuses rows and only new rows animate.
- Tests: `motion_test.dart` now checks that the child State survives a tab switch and an entrance, and that a tab never starts fully transparent.
Rule: never swap a widget wrapper in or out around a screen or row to "skip" an animation at rest.

## Settings scroll lag fix (post Phase 8)

Symptom: the Settings tab scrolled with lag.
Cause (found by reading the code; not profiled on a device): every setting, the AI call counter and the Firestore read/write counters live in one `app_settings` table behind one `settingsMapProvider`. Sync and AI write a counter on almost every operation. `AppSettings`, `AiSettings`, `AiUsage`, `SyncSettings` and `FirestoreUsage` had no `==`, so each of those writes produced "new" values and rebuilt `AkshayaApp` (MaterialApp, two fresh `ThemeData`), `AppLockGate`, every Settings section and, via the alert coordinator, re-planned the scheduled alerts. The Alerts block also watched the whole pantry and shopping streams.
Fix:
- Value equality (`==`/`hashCode`) on the five classes above, so a provider only notifies when its own values change.
- `alertCoordinatorProvider` listens to `alertSettingsProvider` instead of the whole settings table.
- `AppLockGate` watches only "settings loaded" and `appLock` (`select`).
- `AkshayaApp` builds its two `ThemeData` once.
- `AlertsSection` uses `ref.listen` (keeps the streams loaded for the preview) instead of `ref.watch`.
- Test: `test/features/settings/settings_rebuild_test.dart` (usage-counter writes notify only the usage providers).
Files: `lib/app.dart`, `lib/features/lock/app_lock.dart`, `lib/features/alerts/presentation/{providers,alerts_section}.dart`, `lib/features/settings/domain/app_settings.dart`, `lib/features/ai/domain/ai_settings.dart`, `lib/features/sync/domain/sync_settings.dart`.
If Settings still stutters on your phone, the next suspects are the long monolithic sections (each is one `Column`, built whole when it scrolls into view) and first-draw cost of the variable fonts; tell me and I will profile or split the sections into lazily built tiles.

## Phase 9: Leftovers, cooked food and homemade items (built, CI green: analyzer, tests, rules, APK)

Item type is now Stocked (default) / Cooked / Homemade.

**Decisions (asked first):** kind and shelf life are columns on existing tables (no new tables); one new unit `portion` (counts servings of cooked food, converts to nothing).

**Schema v7** (idempotent `ALTER TABLE ADD COLUMN`, all nullable, old rows read as Stocked): `items.kind`, `items.shelf_life_days`, `stock_batches.container_label`, `stock_batches.check_by`. All four are synced columns, optional, so documents from older apps still load. `firestore.rules` is unchanged (extra fields are accepted): no redeploy needed.

**Built**
- Shelf life defaults (`ShelfLife`): cooked fridge 2 / freezer 30 / pantry 1 / other 1 days; homemade fridge 30 / freezer 180 / pantry 90 / other 30. A per-item override ("Keeps for") applies to the place the item is usually kept; other places use the default. Use-by is filled in at save when left empty, counted from the cooked/made date.
- Add item: Stocked/Cooked/Homemade selector. Cooked defaults to portion + fridge, homemade to pantry. Made-at-home items show container label ("steel dabba"), "Check by" date and a hint of the default use-by. The Pantry screen has a small FAB for quick-add of cooked/homemade food.
- Pantry: Cooked and Homemade filter chips; list lines read "Cooked · Fridge · 3 portions left · steel dabba".
- Item detail and batch edit: "Cooked/Made on", container, check-by.
- Home "Use these first" also lists cooked leftovers still in stock.
- Recipes: pantry lines for leftovers are marked `[cooked leftover]` in the prompt, with a template rule to serve or reuse them. "I cooked this" has "Some food is left over": portions + place; it creates (or adds to) a Cooked item named after the recipe, rolled back by Undo. A Stocked item with the same name is never touched ("<name> (leftover)" is used).
- CSV pantry export gained Type, Container, Check by columns.
- Backup JSON is generic by column, so the new fields are included.

**New/changed files** (besides the Settings scroll fix above): `pantry/domain/{item_kind,shelf_life,unit,entities,stock_logic,pantry_query}.dart`, `pantry/data/database/{tables,app_database}.dart`, `pantry/data/drift_pantry_repository.dart`, `pantry/presentation/{add_item_screen,pantry_screen,pantry_actions,item_detail_screen,batch_form_screen,providers}.dart`, `pantry/presentation/widgets/{item_fields,stock_fields}.dart`, `home/presentation/home_screen.dart`, `recipes/domain/{cook_plan,recipe_prompt}.dart`, `recipes/presentation/{cook_sheet,recipe_detail_screen}.dart`, `assets/prompts/generate_recipes.txt`, `commands/domain/command_executor.dart` (alias learning keeps kind), `sync/domain/sync_schema.dart`, `backup/domain/backup_csv.dart`. Tests: `shelf_life_test`, `summary_line_test`, `made_at_home_repository_test`, new cases in `sync_documents_test`.

**Test checklist (device)**
1. Pantry > soup FAB > Cooked food: name "Sambar", 3 portions, leave use-by empty. Expect use-by = today + 2 days (fridge), line shows "Cooked · Fridge · 3 portions left".
2. Change location to Freezer before saving: use-by should be +30 days.
3. Homemade item (pickle) with container "glass jar" and a Check by date: appears under the Homemade chip; detail shows container and check-by.
4. Cooked leftover shows on Home under "Use these first" even with days left.
5. Recipes > open a recipe > I cooked this > turn on "Some food is left over" (2 portions): confirm, see the new Cooked item; Undo removes it.
6. Existing stocked items are unchanged after the update (kind shows nothing extra).
7. With two phones in one household: a Cooked item added on one appears on the other. The other phone should be updated too: an old build cannot read the new `portion` unit.
8. Settings scroll: scroll the Settings tab fast, with and without sync/AI on. Tell me if lag is still there.

**Known issues**
- The optional "check by" date is stored and shown but does not raise a notification yet (planned with Phase 13 actionable notifications).
- Mixed app versions in one household: an older build fails to parse items using unit `portion`. Update all members' phones together.
- Item kind is not set by voice/text commands: a command that creates an item makes a Stocked one.
- The Settings scroll fix was found by reading the code, not by profiling on a device (see above).
- Written without a local Flutter SDK: CI is the compiler; if it is red, fix first.

## Phase 10: Inventory reconciliation, Count mode (built, CI green; waiting for device check)

**Decisions (asked first):** a surplus found on the shelf becomes a new batch; count progress is a local session; spec extended to add a `set_stock` voice intent and the `adjustment` log type.

**No schema change** (still v7). `ConsumptionLog.type` is text, so `adjustment` needs no migration. A surplus is a new batch (today, no expiry/price, the counted place) plus an adjustment log with a negative `quantityUsed` (shown as "+2 kg"). Count progress and reminder settings live in `app_settings` (`count.*` keys), local to the phone, not synced. `firestore.rules` unchanged.

**Built**
- `PantryRepository.setStock` / `undoCount`: sets an item (optionally within one storage location) to a counted amount. Lower: FIFO deduction logged as `adjustment` (or `wasted` when the person chooses). Higher: new batch. Same: writes nothing. Unit-convertible input (500 g for a kg item) works.
- Count mode: entry from Pantry header icon and Settings > Count mode. Start screen: by place, by category, whole pantry, resume a count in progress, "last counted". Count screen: progress bar, one big card per item with Matches / Change / "Finished, none left"; swipe right = Matches, swipe left = Later; Undo snackbar on each answer; end-of-count summary (matched, found more/less, finished, wasted, skipped, list of changes). Adjust sheet: None / Half / Same chips, amount + unit, "missing amount was wasted" switch.
- Monthly reminder (Settings > Count mode): off by default; due on the chosen day (1 to 28) with the daily alert, skipped if a count finished that month. Tapping it opens Count mode. Needs Daily alert on.
- Voice/text: "rice inka 3 kilo undi", "dahi 2 packet hai", "rice is 3 kg", "set rice to 3 kg" set stock via confirmation card. Presence words (undi/vundi/hai/have/is...) plus an explicit quantity trigger it; a question without quantity stays a stock query. Gemini prompt/schema accept `set_stock`.
- Item history shows adjustments with signed amounts.

**New/changed files:** `pantry/domain/{stock_count,consumption_type,entities,pantry_repository}.dart`, `pantry/data/drift_pantry_repository.dart`, `count/domain/{count_session,count_settings}.dart`, `count/presentation/{providers,count_flow,count_screen,count_start_screen,count_summary_screen,count_adjust_sheet,count_section}.dart`, `alerts/domain/{alert_plan,alert_scheduler}.dart`, `alerts/presentation/providers.dart`, `alerts/data/alert_worker.dart`, `shell/app_shell.dart`, `pantry/presentation/{pantry_screen,item_detail_screen}.dart`, `settings/settings_screen.dart`, `core/util/date_only.dart`, `commands/domain/{command_models,offline_command_parser,command_executor,parser_words}.dart`, `tool/offline_words/{tables,generate}.py`, `ai/data/firebase_generative_backend.dart`, `assets/prompts/parse_command.txt`. Tests: `stock_count_repository_test`, `count_session_test`, `count_settings_test`, set-stock cases in parser and executor tests, reminder cases in `alert_scheduler_test`, ISO date cases in `util_test`.

**Test checklist (device)**
1. Pantry header > Count mode icon. Start by place (Pantry). Progress bar moves as you answer.
2. Tap Matches on an item: nothing changes, no history row.
3. Change an item to less: history shows "Adjustment -X" and stock drops from the batch expiring first. Undo snackbar restores it.
4. Change to more: a new batch appears (no expiry), history shows "Adjustment +X".
5. Change to less with "missing amount was wasted" on: history shows Wasted; Insights waste report counts it. Without the switch it does not.
6. "Finished, none left" empties the item (adjustment).
7. Swipe right = Matches, swipe left = Later; Later items can be reviewed at the end.
8. Leave mid-count, reopen Count mode: Resume card appears with the right count.
9. Finish: summary lists changes; Settings shows "Last counted today".
10. Voice: "rice inka 3 kilo undi" shows a "Set how much is in the pantry" card, Rice 3 kg; confirm; stock = 3 kg. "how much rice is left" still just answers.
11. Settings > Count mode: turn reminder on for today's date (needs Daily alert on), wait for the alert time or use the alert preview; tapping opens Count mode.

**Known issues**
- Older builds in the same household cannot parse the new `adjustment` log type; update all phones together.
- The surplus batch has no label or expiry; edit it from the item detail if needed.
- Items with zero stock are not listed in a count (nothing on the shelf to check); use Add for those.
- The reminder fires only on the chosen day and only when the Daily alert is on.
- Written without a local Flutter SDK: CI is the compiler; if it is red, fix first.

## Phase 11: Consumption forecasting and "What should I buy?" (built, CI green; waiting for device check)

All on-device, no AI. Schema v8 adds nullable `shopping_entries.repeat_every_days` (synced, optional; older builds ignore it and read the nearest built-in repeat).

### Files
- New `lib/features/forecast/`: `domain/consumption_forecast.dart`, `purchase_history.dart`, `what_to_buy.dart`, `repeat_learning.dart`; `presentation/providers.dart`, `forecast_actions.dart`, `what_to_buy_screen.dart`.
- Changed: `shopping_enums.dart` (`approxDays`, `nearestTo`), `shopping_entities.dart` (`repeatEveryDays`, `repeatLabel`, `nextDueAfter`), `shopping_tables.dart`, `app_database.dart` (v8), `sync_schema.dart`, `drift_shopping_repository.dart`, `shopping_screen.dart` (What-should-I-buy button, schedule suggestion card), `entry_form_screen.dart` ("Every few days" custom interval), `insights.dart` + `insights_screen.dart` (now use the shared forecast), `pantry_screen.dart` and `item_detail_screen.dart` (runs-out text), `home_screen.dart` ("Running out soon", What-should-I-buy button).
- Tests: `test/features/forecast/**`, plus additions to the shopping repository, sync documents and Insights tests; `FakePantryRepository` gained `history`.

### Key decisions
- Only "used" and "cooked in recipe" logs count. Waste, expiry, given away and count-mode adjustments never do.
- Rate: last 56 completed days from the first logged use, recency-weighted (half-life 21 days), zero-use days included, days above 3x the median dropped (needs 5+ use days). "Learning" until 3 use days spanning 7+ days.
- Expired batches are not usable stock. Cooked/homemade items get no forecast.
- What to buy: horizon 3/7/14/30 days (default 7); quantity covers max(14, horizon+7) days in whole usual packs (most common of the last 5 purchases, count-mode batches excluded). Items already on any list are skipped. Added with reason "low stock".
- Repeat learning: 3+ purchase days, median of the last 5 gaps, all gaps within 0.5x-2x; suggested when it differs by max(2 days, 25%). Dismissals are stored locally in `app_settings`.

### Test checklist (you)
1. Log use of one item (Use button) on 3+ different days across a week or more: Pantry row and item detail show "runs out in ~N days"; before that "Learning: x of 3 days".
2. Shopping tab: tap the graph icon -> What should I buy?; change the horizon, untick one item, change an amount with +/-, add. They land on the list; reopening no longer shows them.
3. Home: "Running out soon" shows up to 3 items; the What should I buy? button opens the screen.
4. Insights "runs out" card matches the Pantry numbers.
5. Add a repeating entry with "Every few days..." (e.g. 10): label shows "Every 10 days"; Done shopping brings it due 10 days later.
6. Buy an item on 3 different days ~14 days apart with a weekly repeat entry: Shopping tab suggests "every 14 days"; Use it (try Undo) and Keep mine.
7. Upgrade over an existing install: data intact, nothing lost.

### Known issues
- A forecast needs real use logs; items you only "count" or waste never get one.
- Cooked/homemade items have no forecast. Schedule suggestions need 3+ purchase days.
- Older builds in a household read only the nearest built-in repeat of a custom interval.
- Count-mode surplus batches are excluded from purchase habits.

## Phase 12: Weekly meal planner and prep reminders (built, CI green; waiting for device check)

Schema v9 adds one synced table, `meal_plan_entries` (Firestore collection `mealPlan`). **Redeploy rules and indexes before using it with a household:** `firebase deploy --only firestore:rules,firestore:indexes` (still Spark, no billing). Without it, meal plan sync is rejected (local use is unaffected).

### Files
- New `lib/features/planner/`:
  - `domain/`: `meal_slot.dart`, `meal_plan_models.dart`, `meal_plan_repository.dart`, `prep_rules.dart`, `prep_schedule.dart`, `meal_shopping.dart`, `plan_prompt.dart`, `plan_validator.dart`, `ai_plan_service.dart`.
  - `data/`: `database/planner_tables.dart`, `drift_meal_plan_repository.dart`, `firebase_plan_backend.dart`.
  - `presentation/`: `providers.dart`, `meal_planner_screen.dart`, `slot_picker_sheet.dart`, `prep_reminders_sheet.dart`, `plan_week_sheet.dart`, `meal_actions.dart`.
- New `assets/prompts/plan_week.txt`.
- Changed: `app_database.dart` (v9 + migration), `sync_triggers.dart`, `sync_schema.dart`, `sync_store.dart`, `backup_service.dart`, `firestore.rules`, `firestore.indexes.json` (8th index), `docs/FIREBASE_SETUP.md`, `firebase/test/firestore.rules.test.js`, `recipe_validator.dart` / `recipe_prompt.dart` (public helpers reused), alerts (`alert_plan.dart` `AlertTarget.mealPlan` + `prep` channel, `alert_scheduler.dart`, `alert_worker.dart`, `local_notification_gateway.dart`, `alerts/presentation/providers.dart`), `app_shell.dart` (opens planner from a prep notification), `recipes_screen.dart` (calendar button in the header).
- Tests: `test/features/planner/**`, plus additions to `sync_documents_test.dart`.

### Key decisions
- One meal per slot (Breakfast / Lunch / Dinner / Snack). A meal is a recipe (stored whole as JSON, so it survives the saved recipe or ideas going away), a leftover pantry item, or free text.
- Prep reminders live on the meal (`prep_json`), suggested on-device by `PrepRules` when a recipe is assigned (soak beans, batter dishes with urad, thaw, marinate, ferment, overnight) and fully editable. The AI only supplies prep inside "Plan my week"; rules are the fallback.
- "Plan my week": one AI call, up to 21 empty slots, full recipes returned once and referenced by id. Same gate as other AI features: on/off, privacy notice, shared daily cap (every attempt counts), cooldown, retries. Only empty slots are filled; diet and avoid list are enforced again on-device. Undo removes what it added.
- Prep notifications use their own channel, ids 6000+, scheduled for the next 7 days and refreshed with the other alerts (app open, plan change, 6-hourly background). They work while daily alerts are off.
- "Generate shopping list" totals the shown week's uncooked recipe meals from today, subtracts current stock, skips items already unchecked on the list, adds the rest as "recipe".
- Cooking a meal reuses the "I cooked this" sheet, executor and Undo. A leftover meal takes 1 portion; free text just toggles done.

### Test checklist (you)
1. Recipes tab -> calendar icon -> Meal plan opens on this week. Tap a slot: type "Pesarattu", then use a chip (Outside). Both appear; Undo works.
2. Pick a saved recipe or a recent idea. Open it; with Rajma or idli batter it shows the bell icon and suggested prep reminders. Edit text, day and time; save.
3. Wait for (or set a time a few minutes ahead for) a reminder: notification "Soak ..." arrives; tapping it opens the planner. Also works with daily alerts turned off.
4. Plan my week: pick days and meals, confirm the notice, wait. Empty slots fill with recipes; existing meals untouched; Undo clears them. With AI off or the cap reached you get a clear message and nothing changes.
5. Generate shopping list: only missing/short items land on your list; pressing again adds nothing new.
6. "I cooked this" on a recipe meal: cook sheet shows, ingredients deducted, meal ticked, Undo restores both. Leftover meal takes 1 portion.
7. Replace and Remove a meal (with Undo); Clear this week; switch weeks with the arrows.
8. Two devices in one household (after redeploying rules/indexes): a meal added on one appears on the other.
9. Upgrade over an existing install: data intact. Export a backup and import it: meals come back.

### Known issues
- Prep reminders belong to the planned meal, not to the saved recipe, so a recipe planned again gets suggestions again.
- Home is not linked to the planner yet.
- Meal plan sync needs the redeploy above; older app versions in a household ignore the new collection.
- Prep reminders are scheduled only 7 days ahead and re-planned on each refresh.
- Plan my week needs the network and AI quota; the offline path is picking meals by hand.

## Phase 13: Food rescue, waste cost and actionable notifications (built, CI green; waiting for device check)

Schema v10 adds one nullable column, `consumption_logs.waste_reason`, which syncs with the log. It is an optional field, so **no rules redeploy is needed**; older app versions in a household ignore it.

### Files
- New `lib/features/rescue/`: `domain/` (`freeze_rules.dart`, `food_rescue.dart`), `presentation/` (`providers.dart`, `food_rescue_section.dart`, `rescue_actions.dart`, `waste_reason_sheet.dart`, `freeze_rules_screen.dart`).
- New `pantry/domain/waste_reason.dart`, `insights/domain/waste_cost.dart`.
- New in `alerts/`: `domain/alert_action.dart`, `alert_snoozes.dart`, `quiet_hours.dart`, `notification_action_runner.dart`, `data/notification_background_handler.dart`.
- Changed: `app_database.dart` (v10), `tables.dart`, `entities.dart`, `pantry_repository.dart`, `drift_pantry_repository.dart`, `sync_schema.dart`, `insights.dart` and `insights_screen.dart` (reasons, Money saved), `backup_csv.dart` (Reason column), `home_screen.dart` (Food rescue), `settings_screen.dart`, `item_detail_screen.dart` (reason when marking wasted), `shopping_suggestions.dart`, alerts (`alert_plan.dart`, `alert_settings.dart`, `alert_digest.dart`, `alert_scheduler.dart`, `notification_gateway.dart`, `local_notification_gateway.dart`, `alert_worker.dart`, `alerts_section.dart`, `presentation/providers.dart`), `app_shell.dart` (Recipes target), `app.dart`, `household_check.dart`, `sync/presentation/providers.dart`.
- Tests: `test/features/rescue/**`, `insights/waste_cost_test.dart`, `alerts/domain/phase13_alerts_test.dart`, plus fake gateway updates.

### Key decisions
- Food rescue works per batch (so the expiring batch is acted on). Groups: Already expired, Expires today, Expiring soon, Leftovers, Opened. It replaces the Home "Use these first" list. Actions: Use, Cook something, Freeze, Mark wasted.
- Freeze moves the batch to the freezer and sets expiry to the later of the printed date and today + the category days (defaults editable in Settings > Freezing rules; 0 = not offered). Never offered for expired batches. Clears "use within days after opening".
- Waste reasons: Expired, Spoiled, Forgot about it, Bought too much, Other. Old expired logs report as Expired; other old waste as Not recorded.
- Money saved = batch price share of uses (and recipe cooking) done within the warning window before expiry, from history.
- Digest notifications are kept. Buttons: expired [Add to list, Snooze], one expiring item [Used it, Snooze, Show recipes], several [Show recipes, Add to list, Snooze], low stock [Add to list, Snooze]. Buttons recompute from current data when tapped.
- Snooze hides the item from alerts through tomorrow.
- Per-type switches (expired, expiring, low stock, prep, household) and quiet hours. Quiet hours shift scheduled alerts to the end of the window and drop household alerts that arrive inside it.
- Closed-app buttons run in a background isolate with its own DB connection; the app re-runs its queries on resume.

### Test checklist (you)
1. Home: Food rescue shows groups with items; Use opens the sheet, Cook something opens Recipes, Freeze moves the item to the freezer with a later date (Undo restores), Mark wasted asks for a reason (Undo works).
2. Expired item: Mark wasted preselects Expired; Freeze is not offered.
3. Settings > Freezing rules: change a category, reset it, set "not offered"; Freeze follows.
4. Insights: Waste card shows "Why" by reason; Money saved shows after using an expiring item with a price.
5. Alerts > Preview: notification shows buttons. With the app closed: Add to list adds to your default list; Snooze hides the item from the next preview; Used it (single item) deducts it. Show recipes opens the Recipes tab.
6. Settings > Alerts: switch each type off and preview; turn quiet hours on and check the next daily alert time.
7. Household: with household alerts off or in quiet hours, no notification, data still syncs.
8. Item detail > batch menu > Mark as wasted asks for a reason.
9. Upgrade over an existing install: data intact; export CSV has a Reason column.

### Known issues
- Notification buttons cannot show feedback; check the app to see the result. Closed-app buttons need the phone to allow background work.
- "Used it" is offered only for single-item digests.
- Use sheet "Wasted" (from the swipe/Use screen) does not ask for a reason yet; it is recorded as Not recorded.
- Quiet hours drop (not defer) household alerts.

## UI consistency pass and Ping-style navigation bar (post Phase 13; CI pending, waiting for device check)

No schema, sync or rules change.

**What changed**
- **Bottom navigation** is now `AkshayaNavBar`, the same look as Ping's: a floating, fully rounded 76 dp pill on a soft shadow, tonal `surfaceAlt` colour with a solid `primary` indicator; tab pages run behind it (`extendBody`, `navClearance`/`navBarInset`), an indicator pill that slides with a small overshoot behind the selected icon, bold label under the selected tab, slide-up entrance, max width 576 on tablets. Respects "Remove animations".
- **One header action style:** `HeaderAction` (48 dp, 24 dp icon, one colour) used by Voice, Guide, Count mode, What should I buy?, Meal plan.
- **One toolbar under the header:** `ToolbarRow` (same side margin and gap), `AkshayaSearchField` (pill), `AkshayaSegmented` (Category/Location, Ideas/Saved), `ChipRow` (filter chips, Shopping lists + "New list" + list menu).
- **One FAB pattern:** `AkshayaFabCluster`: one extended primary action, secondary actions as small tonal buttons above it. Used on Pantry (Add item + scan + cooked food), Shopping, Categories, Travel.
- **One add action per screen:** the empty states of Pantry, Shopping and Travel no longer repeat the FAB as a second "Add item" button; the text points to the FAB instead. Empty states that have no FAB (Home, errors, "No matches") keep their button.
- **Theme-level rules (apply to every screen, including ones not touched):** buttons, FABs, segmented switches and chips are pills; cards stay 20, sheets 28, fields 16; icon buttons share size and colour; segmented and popup menus are themed.
- New tokens: `AppRadius.pill`, `AppRadius.navBar`, `AppSizes.navIndicatorWidth/Height`, `navIcon`, `navPadding`, `navMaxWidth`, `navShadowBlur`, `navShadowOffset`.

**Files:** new `core/design/widgets/{akshaya_nav_bar,header_action,akshaya_search_field,toolbar,fab_cluster}.dart`, `test/core/design/nav_bar_test.dart`. Changed: `design.dart`, `theme/akshaya_theme.dart`, `tokens/layout_tokens.dart`, `shell/app_shell.dart`, `pantry_screen.dart`, `shopping_screen.dart`, `recipes_screen.dart`, `categories_screen.dart`, `travel_screen.dart`, `voice_mic_button.dart`, `guide_button.dart`.

**Test checklist (device)**
1. The bar floats with rounded ends and a shadow; tapping a tab slides the indicator across; the selected label is bold. Dark mode and 200% font: no overflow.
2. Pantry, Shopping, Recipes, Home, Settings: header icons all the same size and colour.
3. Pantry: search box, Category/Location switch and chips line up with the same margins; one "Add item" button (the FAB) on the empty Pantry, with the two small tonal buttons above it.
4. Shopping: list chips and the three-dot menu on one row; empty list shows only the FAB.
5. Recipes: the Ideas/Saved switch matches Pantry's.
6. Settings > Categories and Travel: FAB looks the same.

**Known issues**
- Written without a local Flutter SDK; CI is the compiler. If red, paste the log.
- Glass style added as a Settings option (see below).
- The tonal mini-FAB colours come from the theme, so they follow your colour choice in Settings.
- Not touched: AppBar screens (item detail, insights, planner) keep their app bars; they pick up the theme-level button, icon and menu changes.

### Bar style (Settings > General)
No schema change (local `app_settings` keys `app.bar_style`, `app.glass_alpha`, `app.glass_blur`, `app.glass_edge`).
- **Solid** (default) or **Glass**. Glass shows: Glass transparency slider (Frosted to Clear, shown as %; stored as opacity 20-95, default 62, so slider default is 38%), Glass blur Soft/Medium/Strong (10/18/28 px, sigma = px/2; default Strong), Glass edge switch (thin light rim, default on).
- Implemented in `AkshayaNavBar(glass: NavBarGlass(...))` with `BackdropFilter`; wired in `app_shell.dart`. Tokens `navGlassEdge*`.
- Tests: `app_settings_test.dart` (bar style group), `nav_bar_test.dart` (glass has BackdropFilter and taps; solid has none).
- Device check: Settings > Bar style > Glass; scroll a list behind the bar: it should blur through; slider, blur chips and edge switch change the bar live; switch back to Solid.

### Smoothness pass
- `MainActivity` asks Android for the highest refresh rate at the same resolution (90/120 Hz); before, the app could stay at 60 Hz.
- Scroll edge fade is now a plain gradient over the list (no ShaderMask, so no offscreen layer every frame); blur bands 10 to 6.
- Motion tokens shortened: fast 160 to 120 ms, base 280 to 220, slow 420 to 320, stagger 45 to 35.
- Not profiled on a device (no device here). If something still feels slow, note which screen and I will profile it.

## Next: Phase 14 (v2 roadmap), only when you say so.

## Phase 0: what was built (unchanged)

Direction chosen: **A, Haldi** (terracotta, turmeric, cream; Fraunces + Nunito Sans; soft filled cards; round icons; vessel mark and dot-diamond motif, later renamed SarukuluMotif).

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
lib/core/design/widgets/sarukulu_motif.dart   (was kolam_motif.dart)
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

## Releases and housekeeping (after Phase 13)

Version rule: 1.0.0 was the first signed build. Every change or patch bumps the patch number (and the build number after the `+`) in `pubspec.yaml`: 1.0.1+2, 1.0.2+3 and so on.

### 1.0.0
- Sync no longer fails as a whole when the published rules refuse one collection (for example `mealPlan` before the rules were redeployed). The refused collections are skipped, the rest syncs, and Settings says "Not syncing: ... Publish the latest firestore.rules". Only when every collection is refused does it show "removed from the household".
- Header: the dot motif was removed (it overlapped the action icon); it stays on empty states.
- Wallpaper colours (Material 3 Expressive): superseded in 1.0.2, see below. `dynamic_color` supplied the wallpaper colour, rebuilt into the same `AkshayaColors` tokens. Status colours keep their meaning. Switch in Settings (on by default; Android 12+ only).
- Settings builds its sections lazily, each in its own repaint layer (scroll lag).
- Release signing: `android/app/build.gradle.kts` signs `release` with the key from `RELEASE_KEYSTORE_PATH` and friends, else the debug key. CI restores the key from the secrets `RELEASE_KEYSTORE_BASE64`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD` and uploads `akshayapatra-release.apk` (artifact `akshaya-release-apk`). The keystore (a PKCS12 `.p12`) is only on your devices and in GitHub secrets: back it up.
- 3D launcher icon and in-app logo (`tool/generate_launcher_icons.py` renders the shaded SVG with rsvg-convert; the logo widget uses gradients from the tokens).

### 1.0.4: shortcut icons and APK size

#### What changed
- **Long-press shortcut icons were blank** (Voice add, Scan barcode, Shopping list). The icons are looked up by name at run time (`quick_actions`), so release builds treated them as unused and stripped them. `android/app/src/main/res/raw/keep.xml` now keeps the three `ic_shortcut_*` drawables.
- **APK size.** The workflow built a *debug* APK for all three CPU types (arm64, armv7, x86_64) with the slow, unoptimised debug engine, which is why it was far larger than a store app. Both the debug and the signed release builds now use `--target-platform android-arm64` (every phone from about 2017 on). Expect the debug APK to drop by roughly two thirds. The signed release APK (`akshayapatra-release.apk`) is the small one to install day to day: it is optimised and has unused code and resources removed.
- Version 1.0.4+5. Follow-ups 1.0.5 and 1.0.6 fix guide tests CI caught (1.0.6: the alert, meal-plan and insights pictures had a header row that overflowed at 200% text; the all-pages test now lists every failing page in one run). 1.0.5: the scan-barcode picture overflowed by 44 px at 200% text (fixed-height frame, now a minimum height with padding) and the "Read next" test now scrolls to the chip.

#### Files
```
pubspec.yaml                                     1.0.6+7
android/app/src/main/res/raw/keep.xml            keeps the shortcut icons in release builds
.github/workflows/android.yml                    --target-platform android-arm64 for debug and release
```

#### Key decisions
- arm64 only. A 32-bit (armv7) phone cannot install these APKs. If you ever need one, remove the flag, or build with `--split-per-abi`.
- Not done: `mobile_scanner` could use Google's downloadable barcode model (`dev.steenbakker.mobile_scanner.useUnbundled=true`) to save about 2 to 3 MB, but the first scan would then need internet and Play services. Say if you want it.

#### Test checklist (you)
1. Install the new APK. Long-press the app icon: Voice add, Scan barcode and Shopping list each show a terracotta icon. (If an old install still shows blanks, open the app once, or uninstall and reinstall: Android caches shortcut icons.)
2. Each shortcut still opens the right screen.
3. In the Actions run, compare the size of `akshaya-debug-apk` with the previous one, and use `akshaya-release-apk` for daily use.

#### Known issues
- Written without a Flutter SDK here, so CI is the compiler.
- The blank-icon cause is deduced from how release builds work. If you were on the debug APK and icons are still blank after this, tell me the launcher (for example One UI) and I will switch the icons to PNG.

### 1.0.3: In-app user guide

#### What is built
- **User guide** with a search box, 11 area chips and 52 pages (what the feature is for, a small picture, where to find it, numbered steps, tips, "Read next" links). Pages cover every feature from the five tabs to travel mode, widgets, backup and household sharing.
- Opened from a **? icon at the top of Home, just before the microphone**, and from **Settings > User guide** (first row).
- Search matches titles, steps, tips, hidden keywords and everyday synonyms (mic = voice, throw = wasted, qr = household, expiry = expiring). Every word must match; if no page has all the words, pages with some of them are shown. A light stemmer makes "scanning", "expires" and "recipes" match their base words.
- **Pictures** are live mini-previews drawn with the design system's own widgets (`ItemCard`, `StatusChip`, `SummaryTile`, `ChecklistCard`) and colour tokens, not screenshots. They follow light/dark/wallpaper colours and font scale, add no image files, and are hidden from screen readers behind a one-line description. Each is captioned "Example picture. Your screen may look a little different."

#### Files
```
pubspec.yaml                                     1.0.3+4
lib/features/guide/domain/guide_models.dart      GuideArea (11), GuidePreview (49 pictures), GuideTopic
lib/features/guide/domain/guide_content.dart     the 52 pages + guideTopicById
lib/features/guide/domain/guide_search.dart      pure search, synonyms, stemmer
lib/features/guide/presentation/guide_previews.dart   one drawing per GuidePreview
lib/features/guide/presentation/guide_screen.dart     search + chips + topic cards, openGuide()
lib/features/guide/presentation/guide_topic_screen.dart  one page, openGuideTopic()
lib/features/guide/presentation/guide_button.dart     the ? icon
lib/features/home/presentation/home_screen.dart  header: GuideButton before VoiceMicButton
lib/features/settings/settings_screen.dart       User guide row
test/features/guide/domain/guide_content_test.dart    ids, links, areas, pictures, label drift guard
test/features/guide/domain/guide_search_test.dart     stemmer and ranking
test/features/guide/presentation/guide_screen_test.dart  screens, search, button, every page at 1x and 2x text, light and dark
```

#### Key decisions
- Live previews instead of real screenshots (chosen by you): this environment cannot run the app, and drawn previews never go stale in colour or theme.
- English only (chosen by you).
- Guide text lives in `guide_content.dart` as plain const data. To document a new feature, add a `GuideTopic` there (pick or add a `GuidePreview`); the tests check ids, links and that every picture is used.
- **Label drift guard:** `guide_content_test.dart` lists the button and screen names the guide quotes and fails if one no longer appears in `lib/` outside the guide. If you rename a button in the app, update the guide text too.
- No providers, database or network: the guide works offline and cannot affect your data.

#### Test checklist (you)
1. Home: a ? icon sits just left of the microphone. Tap it: User guide opens with the search box, chips and "New here?" card.
2. Settings: first row "User guide" opens the same screen.
3. Search "barcode", "mic", "whatsapp", "expiry", "throw", "telugu", "dark mode", "how do I share my list": the right page is first or near the top. Search nonsense: "Nothing found". The x clears the search.
4. Tap an area chip (for example Alerts): only that area is listed. Tap All to return.
5. Open several pages: picture, Where to find it, numbered steps, Good to know, Read next (tap one).
6. Compare a few pictures with the real screens (Home tiles, Shopping list, Count card, Food rescue) and tell me anything that reads wrongly.
7. Dark mode and system font 200%: no overflow on the list or a page.
8. TalkBack (optional): each picture reads "Example picture: ..." once; steps read as "Step n: ...".

#### Known issues
- Written without a Flutter SDK here (the proxy blocks Flutter hosts), so CI is the compiler. Paste any red log and I will fix it.
- Pictures are drawings with example values, not captures of your screens. Example numbers (3 of 50 AI calls, "Goa" trip, 1,250) are illustrative.
- Pages describe the app as of 1.0.2. They do not deep-link into the app ("Take me there" buttons would need shell navigation hooks).
- Guide text is English only. Telugu and Hindi would triple the text and need your proofreading.
- A first-run swipe tour was not requested and was not built.

### 1.0.2: theme fixes
- Wallpaper colours now use the phone's own dynamic palette (`DynamicColorBuilder` light and dark schemes) directly via `AkshayaTheme.fromSystemScheme`, so Akshaya matches other apps (blue wallpaper gives blue). 1.0.1 re-derived an Expressive scheme from the seed, which shifted hues to green and maroon.
- Appearance picker (Follow phone / Light / Dark) is now three icon cards (`theme_choice_picker.dart`) instead of a segmented button.
- Test: tap the three cards; with a blue wallpaper the FAB, nav indicator and chips should be blue, status chips still green/amber/red/blue.

### 1.0.1: Phase 14

#### What is built
- Widgets (home_widget): "Use these first", Shopping list with check-off (tapping a row ticks it without opening the app, through a background callback) and Quick add (Voice / Scan / Add). Light/dark colours follow the system (`values-night`). They refresh when Food rescue, the shopping list or a trip changes (1 s debounce), with the daily background check and every 30 minutes (`updatePeriodMillis`).
- App shortcuts (quick_actions): long-press the icon for Voice add, Scan barcode, Shopping list.
- Travel mode (Settings and Home): trips with leaving and return days. Trips are a synced household table (`trips`, schema v11).
  - Food that goes off before the return, soonest first, with Use, Cook something, Freeze, Give away (logged as "given away", not waste) and Mark wasted.
  - Pauses expiry/low-stock alerts and repeating shopping items for the away days (leaving day up to the day before the return); both resume on the return day.
  - A "Welcome back" summary notification on the return day.
  - Back home checklist (default Milk 1 L, Bread 1 packet, Vegetables 1 kg, editable per trip) added to the first shopping list the day before the return, once (also done by the background check; up to 3 days late if the phone was off).
  - Home banner for the trip that is on now or starts within two weeks.

#### Files
```
lib/features/travel/domain/trip_models.dart, travel_plan.dart, trip_summary.dart, back_home.dart, trip_repository.dart
lib/features/travel/data/database/trip_tables.dart, data/drift_trip_repository.dart
lib/features/travel/presentation/trip_providers.dart, back_home_coordinator.dart, travel_screen.dart,
  trip_form_screen.dart, trip_detail_screen.dart, travel_actions.dart, trip_banner.dart
lib/features/widgets/domain/widget_snapshot.dart, widget_gateway.dart (also QuickLaunch)
lib/features/widgets/data/home_widget_gateway.dart, widget_background.dart
lib/features/widgets/presentation/widget_providers.dart
android/app/src/main/kotlin/com/akshaya/akshaya/UseFirstWidgetProvider.kt, ShoppingWidgetProvider.kt, QuickAddWidgetProvider.kt
android/app/src/main/res/layout/widget_*.xml, xml/widget_*_info.xml, drawable/widget_*.xml, drawable/ic_shortcut_*.xml,
  values/widget_*.xml, values-night/widget_colors.xml
changed: app_database.dart (v11), sync_schema/store/triggers, backup_service, firestore.rules, firestore.indexes.json,
  alerts (planner, scheduler, worker, providers), shopping (recurring pause), home_screen, settings_screen, app_shell, app.dart,
  AndroidManifest.xml, pubspec.yaml (home_widget, quick_actions)
tests: test/features/travel/**, test/features/widgets/**
```

#### Key decisions
- A trip is "away" from the leaving day up to the day before the return; the return day must be after the leaving day (at most 365 nights).
- Widget check-off works from the widget (background isolate opens its own database connection, like the alert worker).
- Shortcuts use `quick_actions`; widget buttons use `akshaya://<voice|scan|add|shopping|use_first>` addresses handed to the app shell.
- Native widget code can only be compiled in CI, so it was verified there (APK builds); behaviour needs your device check.

#### Before you test: redeploy the Firestore rules and indexes
```
cd ~/akshaya && git pull
firebase deploy --only firestore:rules,firestore:indexes
```
(Spark plan, no billing.) Without it, trips will not sync (the app says so and keeps working).

#### Test checklist (you)
1. Settings > Travel mode > Add trip (leave tomorrow, back in 4 days). Save. It shows on Home as a banner.
2. Put something expiring in 3 days in the pantry: it appears under "Will not last until you are back" with Use / Freeze / Give away / Mark wasted. Give away, then Undo.
3. During the trip dates: no daily alerts; repeating shopping items are held back ("back on ...").
4. The day before the return: Milk, Bread, Vegetables appear on the first shopping list once.
5. Long-press the Home screen > Widgets > Akshaya: add all three. Shopping widget: tap a row, it ticks without the app opening; open the app, it is ticked there too.
6. Quick add widget: Voice, Scan and Add open the app on that action. Long-press the app icon: the three shortcuts work.
7. Switch the phone to dark mode: widgets change colours.
8. Delete a trip (swipe) and Undo.

#### Known issues
- Widgets show text only (no item icons) and the shopping widget shows the first six rows of the first list.
- The widget redraw after a tick in the app can take about a second.
- Travel mode follows the household's trips: a trip added on one phone shows on the others after sync.

### 1.0.7: development-only leftovers removed (CI pending)

Removed from the shipped app (nothing else changed):
- Settings > **Load sample data** and **Design gallery** tiles. `SettingsScreen` is now a plain `StatelessWidget`.
- `lib/core/design/gallery/design_gallery_page.dart` and its widget test (design widgets keep their own tests).
- `insertSampleData()` from `PantryRepository` and `DriftPantryRepository`. The ten sample items live on as a **test fixture**: `test/features/pantry/sample_data.dart` (`insertSampleData()` extension on `PantryRepository`, used by the sync tests). Its own "inserted once" test was dropped with the production method.
- Guide topic "Try it with sample data", its `GuidePreview.settingsSample` picture and the matching label in the guide's "names still exist in the app" test.
- Design README lines about the gallery.

Checked and kept: every design widget and every dependency is still used; `assets/branding/*` and `tool/` are the source of the launcher icons and the offline dictionary.

Version 1.0.7+8. Consequence: to try the app with data you now add items by hand (or restore a backup). Written without a local Flutter SDK; CI is the compiler.

### 1.0.8: diagnostics (CI pending, waiting for device check)

A private on-device log so bugs can be fixed from a report instead of guesses. No schema change, nothing leaves the phone unless you share a report. Written without a local Flutter SDK; CI is the compiler.

#### What it does
- **Log file** `diagnostics/diagnostics.log` in the app's private files folder (`getApplicationSupportDirectory`), plus one older copy `.1`; each rotates at 256 KB, so at most about 512 KB. The app and its background tasks (alert check, notification buttons, widget taps) all append to the same file.
- **Captured automatically:** Flutter errors (`FlutterError.onError`), uncaught async errors (`PlatformDispatcher.onError`), and every place that used to swallow an error with `debugPrint` (28 sites in alerts, sync, count, travel, widgets) now logs the error **with its stack trace**. `failureMessage()` also logs the real error behind every generic "Something went wrong" (the same error is logged once, not on every rebuild).
- **Breadcrumbs (info):** session start (version, build mode, phone, Android), app paused/resumed, tab changes, pages/sheets opened and closed (route type only, routes have no names), database create/upgrade (`v10 -> v11`), sync phase changes, AI call failures (kind only, never the request or answer), background check start/finish.
- **Privacy rules:** messages never contain item names, notes, recipes, names or e-mail. E-mail addresses, API keys, bearer tokens and `key=` query values are stripped; messages are cut at 600 characters, stacks at 30 lines. Drift error text can still contain item names inside a SQL statement, which is why the screen asks you to glance at a report before sending.
- **Settings > Diagnostics:** this build (version, build mode, phone, Android, language), counts of what is stored (items, batches, usage history, shopping entries, saved recipes, planned meals, trips, database version, notifications allowed, daily alert, AI on/off and usage, sync phase and waiting rows), the log newest first with filters (Everything / Warnings and errors / Errors), expandable stack traces, Share report (text), Save as file (full report via the file dialog), Copy, Clear log.
- **How to use it with me:** after something breaks, open Settings > Diagnostics > Share report (or Save as file) and paste or attach it in the chat.

#### Files
```
pubspec.yaml                                         1.0.8+9; + path_provider, package_info_plus, device_info_plus
lib/main.dart                                        error handlers, Diag.init(), session start line
lib/app.dart                                         lifecycle lines, navigator observer
lib/core/diagnostics/
  diag_entry.dart, diag_redactor.dart, diag_sink.dart, diag_log.dart, diag.dart,
  error_handlers.dart, app_info.dart
lib/core/ui/feedback.dart                            logs the error behind generic messages
lib/features/diagnostics/domain/diag_report.dart
lib/features/diagnostics/presentation/{providers,diagnostics_screen}.dart
lib/features/settings/settings_screen.dart           Diagnostics entry
lib/features/shell/app_shell.dart                    tab lines
lib/features/pantry/data/database/app_database.dart  create/upgrade lines
lib/features/ai/domain/ai_command_service.dart       failure kind lines
lib/features/sync/data/sync_engine.dart              phase change lines (+ errors)
28 catch sites in alerts, sync, count, travel and widgets (debugPrint -> Diag.error / Diag.warn)
test/core/diagnostics/{diag_entry,diag_redactor,diag_sink,diag_log}_test.dart
test/features/diagnostics/{domain/diag_report_test,presentation/diagnostics_screen_test}.dart
```

#### Key decisions
- **File, not Drift:** no schema migration, and it still works if the database is the thing that is broken.
- **Always on, local, capped.** There is no switch; Clear log empties it. Say if you want an "off" switch (it would need a marker the log checks before the database is open).
- **Three small packages:** `path_provider` (already pulled in by drift_flutter), `package_info_plus` and `device_info_plus` (build number, phone model and Android version). If CI complains about any of them, the fallback is to drop that package and show "unknown".
- **Not logged:** every `catch` that shows its own message to the person (validation, form errors) stays quiet; only unexpected errors are logged.
- **Not done:** Firebase Crashlytics (opt-in in the spec) needs the google-services Gradle plugin; the build avoids it on purpose, so this log is the substitute.

#### Test checklist (you)
1. `verify` and `build-apk` are green (CI also commits an updated `pubspec.lock`: `git pull --rebase` before the next push).
2. Settings > Diagnostics opens. Build rows show the real version `1.0.8+9`, your phone and Android version. Counts match what you have.
3. Log shows "Session start", Resumed/Paused when you leave and return, and "Tab Pantry" etc. when you switch tabs.
4. Open Settings > Alerts > Preview, then come back: nothing red. Turn on airplane mode while signed in to a household: Sync lines appear (phase offline).
5. Filters: Warnings and errors / Errors hide the info lines. Tap an error: its stack opens.
6. Share report: the share sheet opens with the text. Save as file writes a `.txt` you can open. Copy puts it on the clipboard. Skim it: no e-mail address, no item names.
7. Clear log: asks first, empties, leaves one "Diagnostics log cleared" line.
8. Close the app fully, trigger the daily alert preview or wait for the background check, reopen Diagnostics, pull Refresh: "Background check started/finished" lines from the worker are there.
9. Dark mode and 200% font: no overflow on the screen.

#### Known issues
- Written without a local Flutter SDK; if CI is red, send me the log first.
- The screen refreshes itself after a short pause when the app logs something; lines written by a background task while the screen is open need the Refresh button.
- Route names are types (`MaterialPageRoute<void>`, `ModalBottomSheetRoute`), so the "open/close" lines say that something opened, not which screen. Tab lines say where you were.
- Cache or data clearing by Android deletes the log with the rest of the app's files.

### 1.0.9: order screenshot import (CI pending, waiting for device check)

Share a screenshot of an order from Blinkit, Zepto, Amazon Now, Swiggy Instamart or Flipkart Minutes to Akshaya Patra; it reads the items, shows a review screen and adds the ticked lines to the pantry. Written without a local Flutter SDK; CI is the compiler. The parsing logic was first checked in a Python prototype against layouts laid out from your five screenshots, and the Dart tests use the same fixtures.

#### How it works
1. **Share target:** Android share menu > Akshaya Patra (image/*, one or several pictures). `MainActivity.kt` copies each picture into the cache and hands the paths to Dart over the `akshaya/share` channel (at start-up and while the app is open). Pictures can also be picked from Add item > receipt icon.
2. **On-device reading:** Google ML Kit text recognition (bundled Latin model, offline). Nothing leaves the phone at this step.
3. **Rows from positions:** `OrderRowParser` uses where each line sits. Two layouts: name lines + a pack line (`1 kg x 1`, `1 pc (500 ml) . 2 units`, `100 g . 2 units`, `1 x 500 ml`) with the price on the right (the lower of two prices; coin counts after `+` ignored), or one `1 x Garlic` line per product. Pack size times packs gives the quantity (1000 g becomes 1 kg, 1000 ml becomes 1 L). The shop is guessed from its fixed headings.
4. **Naming and filing:** `OrderClassifier` uses the existing dictionary (138 products) plus your pantry names and aliases: brand removed, English name, category, where it is kept (fridge for dairy, eggs, leafy veg and fruit; pantry for onion, potato, garlic and packaged goods), and a "keeps for" guess only for fresh food (veg 5 days, roots 14, fruit 5, milk and curd 3, bread 3, eggs 14). Packaged goods get no expiry guess. Cleaning, personal care, paper, batteries, thermometers: **Not food**. Chicken, fish, meat: **Not vegetarian**. Both start unticked. Masala powders are spices, not meat. Eggs are food.
5. **AI only when hard:** if the page gives no products although it has text, or most names are unknown (3 or more rows and 60% unrecognised), the app asks Gemini (`parse_order.txt`) with the same gate as every other AI call (AI on, privacy notice, daily cap, quota cooldown). Only product-looking text lines are sent: headings, bills, addresses, phone numbers and e-mail are dropped first. The AI answer is validated; if it has fewer items than the offline reading, the offline result stays. If AI is off or capped, the offline result is shown with a note.
6. **Review screen, then add:** tick or untick, tap a line to edit name, amount, unit, price, category, place and expiry. Nothing is saved until "Add N items to pantry". Each line becomes one new batch (bought today, store applied to all) on the matching existing item, else on a new item with the English name; the printed name is saved as an alias so the next order matches without guessing. One bad line fails alone. **Undo** removes the new items and batches.

#### Files
```
pubspec.yaml                                        1.0.9+10; + google_mlkit_text_recognition
android/app/src/main/AndroidManifest.xml            SEND / SEND_MULTIPLE image/* intent filters
android/app/src/main/kotlin/com/akshaya/akshaya/MainActivity.kt   share channel, copies pictures to cache
assets/prompts/parse_order.txt
lib/features/orders/domain/
  ocr_models.dart, order_models.dart, order_row_parser.dart, order_classifier.dart,
  order_ai.dart, order_import_service.dart, order_commit.dart
lib/features/orders/data/
  mlkit_screenshot_reader.dart, firebase_order_backend.dart, shared_images_gateway.dart
lib/features/orders/presentation/
  providers.dart, order_import_flow.dart, order_review_screen.dart, order_draft_sheet.dart
lib/app.dart                                        reads shareCoordinatorProvider
lib/features/shell/app_shell.dart                   opens the flow for shared pictures
lib/features/pantry/presentation/add_item_screen.dart   "Add from an order screenshot" action
lib/features/recipes/presentation/preferences_sheet.dart   Non-veg diet chip hidden unless already chosen
test/features/orders/
  order_fixtures.dart, order_row_parser_test.dart, order_classifier_test.dart,
  order_import_service_test.dart, order_ai_test.dart, order_commit_test.dart
```

#### Key decisions
- **ML Kit plugin** is the one new dependency. If CI rejects it (for example an AGP 9 / Kotlin plugin clash), send me the CI log; the fallback is another on-device reader or a picture-to-Gemini path (that would send the picture itself, so it would need your OK first).
- **Truncated names** ("Tata Sampann White...") cannot be repaired by AI either (the text is not in the picture); they are flagged "Name was cut off" for you to fix.
- **Non-veg:** no section added. The recipe diet chip "Non-veg" is hidden unless it is already selected; the enum stays so old settings and backups still load. Rename "Meat & Eggs" yourself in Settings > Categories if you like.
- **Prices** are what you paid for the line; a misread price is editable in the review sheet.
- **No schema change, no sync change:** it only uses the existing add-item and add-batch calls, so household sync works as before.

#### Test checklist (you)
1. `verify` and `build-apk` are green (CI commits an updated `pubspec.lock`: `git pull --rebase` before the next push).
2. Open a Blinkit order, take a screenshot, Share > Akshaya Patra. "Reading your order..." then the review screen lists every product with a sensible English name, amount, price and category. Repeat for Zepto, Amazon Now, Swiggy Instamart, Flipkart Minutes.
3. Zepto milk shows 1 L, eggs 10 pcs, Amazon green chilli 200 g. Swiggy lines say "Pack size not shown". Flipkart cut-off names say "Name was cut off".
4. Harpic, Dettol, shampoo, thermometer, baking paper start unticked as "Not food". Everest Chicken Masala stays ticked.
5. Vegetables and milk show a "keeps about" date; dals and masalas do not. Change one date and one amount in the edit sheet.
6. Tap Add: pantry has the items, expiring-soon ones show correct chips, snackbar Undo removes them.
7. Share the same order again later: lines whose names you saved match the same pantry items (no duplicates).
8. Share two overlapping screenshots of one long order: each product appears once.
9. Share while the app is closed, and while it is open on another screen.
10. Turn AI off in Settings and share a screenshot of some other shop: the review shows a note instead of crashing. Add item > receipt icon picks from the gallery.
11. Recipe preferences: the Non-veg chip is gone.

#### Known issues
- Written without a local Flutter SDK; if CI is red, send me the log first.
- Other shops' layouts or a new app version may not parse offline; they fall back to AI (or show an empty review with a hint).
- Text that ML Kit misreads (for example a rupee sign read as 2) can give a wrong price; check prices on the review screen.
- Share handling copies up to 6 pictures per share.

---

## Fix batch: search, categories, settings bar, long-press Move, Vegetables & fruits

No schema change, no new packages, no sync change.

#### What changed
1. **Search keyboard** (`akshaya_search_field.dart`): own FocusNode, tap requests focus and asks the platform to show the keyboard, re-asks once after 500 ms; Diagnostics log "Field tapped / focused / Keyboard shown / keyboard not showing". Root cause unproven (add-item screens work on the same phone); if it still fails, send the Diagnostics log.
2. **Category icons** (`pantry_icons.dart`): ~48 icons (eggs, dry fruits, fish, millets, beauty, hair care, baby, pets, pooja...), labelled in the picker. Old keys unchanged. **Suggested categories** (Settings > Categories > playlist-add icon): opt-in sheet of 32 ready-made categories, grouped Food / Personal care and health / Home (`suggested_categories.dart`). Not auto-added, because categories sync across the household.
3. **Settings search** (`settings_index.dart`, `settings_screen.dart`): pinned bar with search over all blocks (title + keywords, any word order).
4. **Sync button** next to the search: shows state (syncing, pending badge, error colour); tap = Sync now; if sync cannot run it explains why and jumps to Household & sync (`sync_now_button.dart`).
5. **Long-press menu** (`pantry_actions.dart`, `move_actions.dart`, `item_moves.dart`): Use, Add stock, Add to shopping list, Move to category, Move to place (item default + in-stock batches), Mark/Remove essential, View details, Edit, Delete. Moves have Undo.
6. **Vegetables & fruits** (`features/produce/`): 6th Home tile (count in stock) opening All / Vegetables / Fruits, soonest expiry first, same swipe and long-press as Pantry (`PantryRow` is now public). Recognises `cat_vegetables`/`cat_fruits` and any category using the vegetables/fruits icon.

#### New / changed files
lib/core/design/widgets/akshaya_search_field.dart; lib/features/pantry/{domain/item_moves.dart, domain/suggested_categories.dart, presentation/move_actions.dart, presentation/pantry_actions.dart, presentation/pantry_icons.dart, presentation/pantry_screen.dart}; lib/features/produce/{domain/produce.dart, presentation/produce_screen.dart}; lib/features/home/presentation/home_screen.dart; lib/features/settings/{settings_screen.dart, presentation/settings_index.dart, presentation/categories_screen.dart}; lib/features/sync/presentation/sync_now_button.dart; tests: core/design/akshaya_search_field_test, pantry/domain/suggested_categories_test, settings/settings_index_test, produce/produce_test.

#### Test checklist (you)
1. CI green; `git pull --rebase` first (CI commits pubspec.lock).
2. Tap Pantry search, Settings search, Add-item search: keyboard appears. If not, Settings > Diagnostics > share report.
3. Settings > Categories > icon picker shows many icons; playlist-add icon offers suggestions; adding Eggs gives an egg icon.
4. Settings: type "alert", "csv", "currency": only matching blocks show; Clear returns all.
5. Sync button: signed out explains and jumps to Household & sync; signed in syncs.
6. Long-press an item: all actions; Move to category moves it and Undo restores; Move to place; Essential toggle; Add to shopping list appears in the list.
7. Home: 6th tile "Vegetables & fruits" opens the screen; segments filter; swipe and long-press work; Move a "Spinach" into Vegetables and it shows up.

#### Known issues
- Written without a local Flutter SDK; if CI is red send the log.
- Scan and order-import category guessing does not know the new categories (they land in Other).
- Move is one item at a time (multi-select is a possible follow-up).

#### Follow-up: search keyboard root cause (found from the screen recording)
`_EdgeBody` gives `ScrollEdgeEffect` `barHeight = MediaQuery.paddingOf(context).bottom`, which is 0 while the keyboard is open. `ScrollEdgeEffect` then returned the bare child instead of its Stack, which re-parented the whole tab tree: every screen was rebuilt from scratch (rows replayed their entrance animation, the dimming in the video) and the focused field was destroyed, so the keyboard closed ~0.4 s after opening. Fix: `ScrollEdgeEffect` now always builds the same Stack (child at the same position); only the fade and blur overlays are conditional. Regression test in `scroll_edge_effect_test.dart` (child state survives bar height 0 and kind changes). The search-field focus code from the earlier fix stays as a harmless safeguard.
