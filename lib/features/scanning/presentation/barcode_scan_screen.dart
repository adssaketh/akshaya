import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/util/barcode.dart';

/// Retail barcode types. Limiting the formats makes detection faster and
/// stops stray QR codes from being read as products.
const List<BarcodeFormat> kRetailBarcodeFormats = <BarcodeFormat>[
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
];

/// Opens the camera and returns the canonical barcode that was scanned or
/// typed, or null when the person goes back.
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (BuildContext _) => const BarcodeScanScreen(),
    ),
  );
}

/// Full-screen camera that pops with the first retail barcode it reads.
/// Typing the code is always available, so scanning never blocks adding an
/// item (no camera, permission refused, damaged label).
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  late final MobileScannerController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: kRetailBarcodeFormats,
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
      final String? code = raw == null ? null : normalizeBarcode(raw);
      if (code != null) {
        _done = true;
        unawaited(HapticFeedback.mediumImpact());
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  Future<void> _typeInstead() async {
    final String? code = await askForBarcode(context);
    if (code != null && mounted && !_done) {
      _done = true;
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: <Widget>[
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (BuildContext context, MobileScannerState state, _) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final bool on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Turn torch off' : 'Turn torch on',
                icon: Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (BuildContext context, MobileScannerException error) {
              return _CameraProblem(
                error: error,
                onTypeInstead: _typeInstead,
              );
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: AppSizes.scanFrameWidth,
                height: AppSizes.scanFrameHeight,
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
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppRadius.controlBorder,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          'Point the camera at the barcode',
                          style: context.akText.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.tonalIcon(
                      onPressed: _typeInstead,
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Type the barcode instead'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error, required this.onTypeInstead});

  final MobileScannerException error;
  final VoidCallback onTypeInstead;

  String get _message {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera access is off. Allow the camera for Akshaya Patra in '
            'your phone settings to scan, or type the barcode.';
      case MobileScannerErrorCode.unsupported:
        return 'This device has no usable camera. You can type the barcode.';
      default:
        return 'The camera could not start. You can type the barcode instead.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;

    return ColoredBox(
      color: colors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.no_photography_rounded,
                size: AppSizes.iconXl,
                color: colors.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: context.akText.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onTypeInstead,
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('Type the barcode'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a barcode to be typed. Returns the canonical code, or null when
/// cancelled. Only codes with a correct check digit are accepted, so a
/// mistyped digit is caught here rather than saved.
Future<String?> askForBarcode(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext _) => const _BarcodeDialog(),
  );
}

class _BarcodeDialog extends StatefulWidget {
  const _BarcodeDialog();

  @override
  State<_BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<_BarcodeDialog> {
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final String? code = normalizeBarcode(_text.text);
    if (code == null) {
      setState(() => _error = 'Enter the 8, 12, 13 or 14 digits under the bars.');
      return;
    }
    if (!hasValidCheckDigit(code)) {
      setState(() => _error = 'Those digits do not form a valid barcode. '
          'Check for a typo.');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Type the barcode'),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9 -]')),
          LengthLimitingTextInputFormatter(20),
        ],
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Barcode number',
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Use this code')),
      ],
    );
  }
}
