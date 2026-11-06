/// What the phone's text reader found in a screenshot. Pure Dart, so the
/// parser that works on it is tested without a phone.
library;

/// One line of text, with where it sits on the picture (pixels).
final class OcrLine {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Every line found in one screenshot and the size of the picture.
final class OcrPage {
  const OcrPage({
    required this.width,
    required this.height,
    required this.lines,
  });

  final double width;
  final double height;
  final List<OcrLine> lines;
}

/// Reads the text in a picture on the phone itself. Tests replace it with a
/// fake; the real one uses Google ML Kit (no internet needed).
abstract interface class ScreenshotReader {
  Future<OcrPage> read(String path);
}
