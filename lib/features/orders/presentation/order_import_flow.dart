import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:akshaya/core/design/design.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/diagnostics/diag.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import '../../ai/presentation/ai_notice_dialog.dart';
import '../../ai/presentation/providers.dart';
import '../../commands/presentation/providers.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/order_import_service.dart';
import 'order_review_screen.dart';
import 'providers.dart';

/// Reads the order pictures at [paths] and opens the review screen.
///
/// The phone reads the text itself. Only a picture it cannot make sense of is
/// sent to AI, and only with the person's OK (the one-time privacy notice) and
/// inside the daily cap; otherwise the offline result is shown as it is.
Future<void> openOrderImport(
  BuildContext context,
  WidgetRef ref,
  List<String> paths,
) async {
  if (paths.isEmpty) {
    return;
  }
  final NavigatorState navigator = Navigator.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const _ReadingDialog(),
    ),
  );
  // When the app was started by the share, the dictionary, the pantry names
  // and the AI prompts may still be loading. Wait for them (briefly) so the
  // first share after a cold start works.
  try {
    await Future.wait<Object?>(<Future<Object?>>[
      ref.read(groceryDictionaryProvider.future),
      ref.read(itemsStreamProvider.future),
      ref.read(orderPromptProvider.future),
      ref.read(parsePromptProvider.future),
    ]).timeout(const Duration(seconds: 15));
  } on Object catch (error) {
    Diag.warn('orders', 'App data was slow to load', error: error);
  }
  final OrderImportService? service = ref.read(orderImportServiceProvider);
  if (service == null) {
    if (navigator.mounted) {
      navigator.pop();
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Akshaya is still starting. Try again.')),
    );
    return;
  }
  OrderScan scan;
  String? aiNote;
  try {
    scan = await service.scan(paths);
    if (scan.isHard) {
      final AiAvailability? availability = await service.aiAvailability();
      if (availability != null && context.mounted) {
        bool ready = availability.isReady;
        if (availability == AiAvailability.noticeNeeded) {
          ready = await ensureAiNotice(context, ref);
        }
        if (ready) {
          try {
            scan = await service.improveWithAi(scan);
          } on AiFailure catch (failure) {
            aiNote = failure.message;
          }
        } else {
          aiNote = availability.message;
        }
      }
    }
  } on Object catch (error) {
    Diag.warn('orders', 'Could not read the order picture', error: error);
    if (navigator.mounted) {
      navigator.pop();
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not read that picture.')),
    );
    return;
  } finally {
    unawaited(_cleanUp(paths));
  }
  if (!navigator.mounted) {
    return;
  }
  navigator.pop();
  await navigator.push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          OrderReviewScreen(scan: scan, aiNote: aiNote),
    ),
  );
}

/// Lets the person pick order screenshots from the gallery, for when the share
/// menu is not handy.
Future<void> pickOrderPictures(BuildContext context, WidgetRef ref) async {
  final PlatformFile? picked = await FilePicker.pickFile(type: FileType.image);
  if (picked == null) {
    return;
  }
  // The picker may hand over a content address instead of a file path, so the
  // picture is copied into the cache first.
  final Uint8List bytes = await picked.readAsBytes();
  final Directory cache = await getTemporaryDirectory();
  final Directory folder = Directory('${cache.path}/shared_orders');
  await folder.create(recursive: true);
  final File copy = File(
    '${folder.path}/picked_${DateTime.now().microsecondsSinceEpoch}.img',
  );
  await copy.writeAsBytes(bytes, flush: true);
  if (!context.mounted) {
    return;
  }
  await openOrderImport(context, ref, <String>[copy.path]);
}

/// Shared pictures are copies in the cache; remove them once read.
Future<void> _cleanUp(List<String> paths) async {
  for (final String path in paths) {
    if (!path.contains('shared_orders')) {
      continue;
    }
    try {
      await File(path).delete();
    } on Object {
      // Nothing to do; the cache is cleared by the system.
    }
  }
}

class _ReadingDialog extends StatelessWidget {
  const _ReadingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: <Widget>[
            const SizedBox(
              width: AppSizes.iconLg,
              height: AppSizes.iconLg,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                'Reading your order...',
                style: context.akText.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
