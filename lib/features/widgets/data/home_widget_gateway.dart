import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../domain/widget_gateway.dart';
import '../domain/widget_snapshot.dart';

/// Android classes that draw the widgets (see android/.../widgets).
const List<String> kWidgetProviders = <String>[
  'com.akshaya.akshaya.UseFirstWidgetProvider',
  'com.akshaya.akshaya.ShoppingWidgetProvider',
];

/// [WidgetGateway] using the `home_widget` plugin.
class HomeWidgetGateway implements WidgetGateway {
  const HomeWidgetGateway();

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    try {
      for (final MapEntry<String, Object> entry in snapshot.toPrefs().entries) {
        final Object value = entry.value;
        if (value is String) {
          await HomeWidget.saveWidgetData<String>(entry.key, value);
        } else if (value is int) {
          await HomeWidget.saveWidgetData<int>(entry.key, value);
        } else if (value is bool) {
          await HomeWidget.saveWidgetData<bool>(entry.key, value);
        }
      }
      for (final String provider in kWidgetProviders) {
        await HomeWidget.updateWidget(qualifiedAndroidName: provider);
      }
    } on Object catch (error) {
      // Widgets are a convenience: a failure here never disturbs the app.
      debugPrint('Could not update the home screen widgets: $error');
    }
  }
}
