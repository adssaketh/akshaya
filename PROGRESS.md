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
| 6 Firebase auth, household sharing, sync, security rules | Built, not yet compiled (CI is the first compile). Device checklist pending. |
| 7 to 8 | Not started |

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
pubspec.yaml                                       + firebase_auth, cloud_firestore, google_sign_in, qr_flutter
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
- The QR code is drawn black on white in every theme so it scans (the one hard-coded colour).

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

- Not compiled or run locally (no Flutter SDK in my sandbox). Firebase package APIs (`google_sign_in` v7 in particular) are written from memory; if CI complains, send me the errors. Versions are `^` lower bounds; send the resolved versions to pin.
- Two simultaneous alert sources: if two collections deliver at once, a change in the older one can be treated as already seen and skip its alert (sync itself is unaffected).
- The background check cannot tell a new document from an edited one, so another member's edit to an entry can read as "added".
- A member removed while offline learns about it on the next connection.
- Usage numbers are an estimate of this phone only (other members' usage counts against the same project quota).
- Rules tests were written but not run here; the CI `rules-tests` job is their first run.

## Next: Phase 7 (recipe suggestions)

Start in a new chat when you say so.

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
