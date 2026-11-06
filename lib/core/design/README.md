# Akshaya design system (Haldi)

Warm terracotta, turmeric and cream, with a faint dot motif (`SarukuluMotif`, named for sarukulu, groceries) and the Akshaya Patra basket mark (`AkshayaLogo`).

Import one file from feature code:

```dart
import 'package:akshaya/core/design/design.dart';
```

## Rules for every phase

1. No raw colours. Read `context.akColors` (or `Theme.of(context).colorScheme`). A test fails the build if `Color(0x...)` or `Colors.xxx` (except `Colors.transparent`) appears outside `tokens/akshaya_colors.dart`.
2. No magic numbers for layout. Use `AppSpacing`, `AppRadius` and `AppSizes`.
3. No ad-hoc `TextStyle`. Use `context.akText.<style>`; tint with `copyWith(color: ...)` from the tokens only.
4. Status is always colour plus icon plus word. Use `StatusKind` with `StatusChip` or `SummaryTile`.
5. Touch targets are at least `AppSizes.touchTarget` (48).
6. Need something new (a colour, size or style)? Add it to the tokens first, with a contrast test, then use it.

## Layout

```
tokens/      akshaya_colors.dart  light + dark palettes, status colours (only file with hex values)
             layout_tokens.dart   AppSpacing, AppRadius, AppSizes
             status_kind.dart     Fresh / Expiring soon / Expired / Low stock / Out of stock
typography/  akshaya_text.dart    Fraunces (display) + Nunito Sans (body) scale
theme/       akshaya_theme.dart   AkshayaTheme.light() / .dark() (Material 3)
             design_context.dart  context.akColors, context.akText
widgets/     AkshayaHeader, AkshayaLogo, SarukuluMotif, StatusChip, SummaryTile,
             ItemCard, SectionHeader, EmptyState, ChecklistCard
```

## Wiring (Phase 1)

```dart
MaterialApp(
  theme: AkshayaTheme.light(),
  darkTheme: AkshayaTheme.dark(),
  themeMode: ThemeMode.system, // user override comes from settings later
  home: const AppShell(),
);
```

Requires Flutter 3.27 or newer (`CardThemeData`, `WidgetState`, `Color.withValues`).
