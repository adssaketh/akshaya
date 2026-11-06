import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diag.dart';
import '../../ai/domain/ai_command_service.dart';
import '../../ai/presentation/providers.dart';
import '../../commands/domain/grocery_lexicon.dart';
import '../../commands/presentation/providers.dart';
import '../../pantry/presentation/providers.dart';
import '../data/firebase_order_backend.dart';
import '../data/mlkit_screenshot_reader.dart';
import '../data/shared_images_gateway.dart';
import '../domain/ocr_models.dart';
import '../domain/order_ai.dart';
import '../domain/order_commit.dart';
import '../domain/order_import_service.dart';

/// Pictures shared from other apps. Tests override it with a fake.
final Provider<SharedImagesGateway> sharedImagesGatewayProvider =
    Provider<SharedImagesGateway>((Ref ref) => ChannelSharedImagesGateway());

/// The on-device text reader. Tests override it with a fake.
final Provider<ScreenshotReader> screenshotReaderProvider =
    Provider<ScreenshotReader>((Ref ref) => const MlKitScreenshotReader());

/// The order prompt template bundled with the app.
final FutureProvider<String> orderPromptProvider = FutureProvider<String>(
  (Ref ref) => rootBundle.loadString('assets/prompts/parse_order.txt'),
);

final Provider<OrderBackend> orderBackendProvider =
    Provider<OrderBackend>((Ref ref) {
  return FirebaseOrderBackend(ref.watch(firebaseRuntimeProvider));
});

/// The AI order reader, or null while its prompt or the AI gate load.
final Provider<OrderAiService?> orderAiServiceProvider =
    Provider<OrderAiService?>((Ref ref) {
  final String? prompt = ref.watch(orderPromptProvider).value;
  final AiCommandService? guard = ref.watch(aiCommandServiceProvider);
  if (prompt == null || guard == null) {
    return null;
  }
  return OrderAiService(
    guard: guard,
    backend: ref.watch(orderBackendProvider),
    promptTemplate: prompt,
  );
});

/// The order reader, or null while the dictionary loads.
final Provider<OrderImportService?> orderImportServiceProvider =
    Provider<OrderImportService?>((Ref ref) {
  final GroceryLexicon? lexicon = ref.watch(groceryLexiconProvider);
  if (lexicon == null) {
    return null;
  }
  return OrderImportService(
    reader: ref.watch(screenshotReaderProvider),
    lexicon: lexicon,
    ai: ref.watch(orderAiServiceProvider),
  );
});

final Provider<OrderCommitter> orderCommitterProvider =
    Provider<OrderCommitter>((Ref ref) {
  return OrderCommitter(ref.watch(pantryRepositoryProvider));
});

/// Pictures shared to the app that no screen has opened yet. The app shell
/// opens the order flow for them and then clears them.
final NotifierProvider<SharedPicturesNotifier, List<String>>
    sharedPicturesProvider =
    NotifierProvider<SharedPicturesNotifier, List<String>>(
  SharedPicturesNotifier.new,
);

class SharedPicturesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  void add(List<String> paths) {
    if (paths.isNotEmpty) {
      state = <String>[...state, ...paths];
    }
  }

  void clear() => state = const <String>[];
}

/// Collects pictures from the share menu, at start-up and while the app is
/// open. Read once at start-up.
final Provider<void> shareCoordinatorProvider = Provider<void>((Ref ref) {
  final SharedImagesGateway gateway = ref.watch(sharedImagesGatewayProvider);
  bool disposed = false;

  Future<void> collect() async {
    try {
      final List<String> paths = await gateway.take();
      if (!disposed) {
        ref.read(sharedPicturesProvider.notifier).add(paths);
      }
    } on Object catch (error) {
      Diag.warn('orders', 'Could not collect shared pictures', error: error);
    }
  }

  final StreamSubscription<void> subscription =
      gateway.arrivals.listen((_) => unawaited(collect()));
  ref.onDispose(() {
    disposed = true;
    unawaited(subscription.cancel());
  });
  unawaited(collect());
});
