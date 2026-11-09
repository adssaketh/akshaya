import 'package:firebase_ai/firebase_ai.dart';

import '../../ai/data/firebase_runtime.dart';
import '../domain/report_ai.dart';

/// [ReportBackend] that asks Gemini through Firebase AI Logic for a short
/// plain-text review. No API key is stored in the app; the model name comes
/// from Remote Config.
final class FirebaseReportBackend implements ReportBackend {
  FirebaseReportBackend(this._runtime);

  final FirebaseRuntime _runtime;

  @override
  Future<String> generateReportText(String prompt) async {
    await _runtime.ensureReady();
    final GenerativeModel model = FirebaseAI.googleAI().generativeModel(
      model: _runtime.modelName(),
      generationConfig: GenerationConfig(
        maxOutputTokens: 450,
        temperature: 0.6,
      ),
    );
    final GenerateContentResponse response = await model.generateContent(
      <Content>[Content.text(prompt)],
    );
    return response.text ?? '';
  }
}
