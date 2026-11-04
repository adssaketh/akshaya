import 'dart:typed_data';

import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';

/// A backend that answers from a script, and counts its calls.
class FakeBackend implements GenerativeBackend {
  FakeBackend(this.script);

  /// One entry per call: a String answer, or an Object to throw.
  final List<Object> script;
  int calls = 0;
  String? lastPrompt;

  Object _next() {
    final Object step = script[calls < script.length ? calls : script.length - 1];
    calls++;
    return step;
  }

  @override
  Future<String> generateJson(String prompt) async {
    lastPrompt = prompt;
    final Object step = _next();
    if (step is String) {
      return step;
    }
    throw step;
  }

  @override
  Future<String> transcribe({
    required Uint8List audio,
    required String mimeType,
    required String prompt,
  }) async {
    final Object step = _next();
    if (step is String) {
      return step;
    }
    throw step;
  }
}

class MemoryUsageStore implements AiUsageStore {
  MemoryUsageStore([this.usage = const AiUsage()]);

  AiUsage usage;

  @override
  Future<AiUsage> read() async => usage;

  @override
  Future<void> write(AiUsage next) async => usage = next;
}

const String kTestPrompt =
    'today={{today}} screen={{screen}} lang={{language_hint}} '
    'known={{known_items}} text={{text}}';

const String kGoodJson =
    '{"actions":[{"intent":"add_stock","item_name_en":"Rice",'
    '"original_text":"biyyam","quantity":2,"unit":"kg"}]}';
