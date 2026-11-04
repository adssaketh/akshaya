import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/alerts/presentation/providers.dart';
import 'features/pantry/presentation/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        // The pantry's "expiring soon" window is the saved alert setting, so
        // the Pantry list and the daily alert always agree.
        expiryWarningDaysProvider.overrideWith(
          (Ref ref) => ref.watch(savedWarningDaysProvider),
        ),
      ],
      child: const AkshayaApp(),
    ),
  );
}
