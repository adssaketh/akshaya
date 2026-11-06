import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/ocr_models.dart';

/// Reads the text in a screenshot with Google ML Kit's bundled Latin model.
/// It runs on the phone and needs no internet; nothing leaves the device.
final class MlKitScreenshotReader implements ScreenshotReader {
  const MlKitScreenshotReader();

  @override
  Future<OcrPage> read(String path) async {
    final File file = File(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      await file.readAsBytes(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final double width = frame.image.width.toDouble();
    final double height = frame.image.height.toDouble();
    frame.image.dispose();
    codec.dispose();

    final TextRecognizer recognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText text =
          await recognizer.processImage(InputImage.fromFilePath(path));
      final List<OcrLine> lines = <OcrLine>[
        for (final TextBlock block in text.blocks)
          for (final TextLine line in block.lines)
            OcrLine(
              text: line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
            ),
      ];
      return OcrPage(width: width, height: height, lines: lines);
    } finally {
      await recognizer.close();
    }
  }
}
