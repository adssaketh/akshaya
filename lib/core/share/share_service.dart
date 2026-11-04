import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands plain text to the system share sheet (WhatsApp, Messages, ...).
/// Tests override [shareServiceProvider] with a fake.
abstract interface class ShareService {
  /// Opens the share sheet with [text]. Throws if sharing is not possible.
  Future<void> shareText(String text, {String? subject});
}

/// [ShareService] backed by the `share_plus` plugin.
final class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}

final Provider<ShareService> shareServiceProvider = Provider<ShareService>(
  (Ref ref) => const SharePlusShareService(),
);
