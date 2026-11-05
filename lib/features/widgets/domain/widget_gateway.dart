import 'widget_snapshot.dart';

/// Hands the widget contents to the phone's home screen widgets. Tests
/// replace it with a fake.
abstract interface class WidgetGateway {
  /// Stores [snapshot] and asks the widgets to redraw.
  Future<void> publish(WidgetSnapshot snapshot);
}

/// Where a tap on a widget or an app shortcut wants to go.
enum QuickLaunch {
  voice('voice'),
  scan('scan'),
  add('add'),
  shopping('shopping'),
  useFirst('use_first');

  const QuickLaunch(this.key);

  final String key;

  /// The destination named by a `akshaya://<key>` address (or a shortcut
  /// type), or null for anything else.
  static QuickLaunch? fromKey(String? key) {
    for (final QuickLaunch q in QuickLaunch.values) {
      if (q.key == key) {
        return q;
      }
    }
    return null;
  }

  /// Reads `akshaya://voice` style addresses.
  static QuickLaunch? fromUri(Uri? uri) {
    if (uri == null || uri.scheme != 'akshaya') {
      return null;
    }
    return fromKey(uri.host);
  }
}
