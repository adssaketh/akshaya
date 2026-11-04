import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/invite_code.dart';

/// Camera screen that pops with the invite code in a household QR code.
class QrJoinScreen extends StatefulWidget {
  const QrJoinScreen({super.key});

  @override
  State<QrJoinScreen> createState() => _QrJoinScreenState();
}

class _QrJoinScreenState extends State<QrJoinScreen> {
  late final MobileScannerController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw == null || !raw.startsWith(InviteCode.qrPrefix)) {
        continue;
      }
      final String? code =
          InviteCode.normalize(raw.substring(InviteCode.qrPrefix.length));
      if (code != null) {
        _done = true;
        unawaited(HapticFeedback.mediumImpact());
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan household QR')),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (BuildContext context, MobileScannerException error) {
              return ColoredBox(
                color: colors.background,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'The camera is not available. Go back and type the '
                      'invite code instead.',
                      textAlign: TextAlign.center,
                      style: context.akText.bodyLarge,
                    ),
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: AppSizes.qrScanFrame,
                height: AppSizes.qrScanFrame,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(
                    color: colors.accent,
                    width: AppSizes.scanFrameBorder,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
