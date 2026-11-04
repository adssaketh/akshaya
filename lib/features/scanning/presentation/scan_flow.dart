import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/scan_service.dart';
import 'providers.dart';

/// Resolves [barcode] while showing a short "Looking up" dialog. Never
/// throws: a failed lookup is just an outcome without details.
Future<ScanOutcome> resolveScan(
  BuildContext context,
  WidgetRef ref,
  String barcode,
) async {
  final ScanService service = ref.read(scanServiceProvider);
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext _) => const _LookingUpDialog(),
    ),
  );
  try {
    return await service.resolve(barcode);
  } on Object catch (_) {
    return ScanNewProduct(barcode: barcode, notice: ScanNotice.offline);
  } finally {
    navigator.pop();
  }
}

class _LookingUpDialog extends StatelessWidget {
  const _LookingUpDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: <Widget>[
            const SizedBox(
              width: AppSizes.iconXl,
              height: AppSizes.iconXl,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                'Looking up the product...',
                style: context.akText.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
