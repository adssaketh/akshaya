import 'package:firebase_ai/firebase_ai.dart';

import '../../ai/data/firebase_runtime.dart';
import '../domain/food_estimate_service.dart';

/// [FoodEstimateBackend] that asks Gemini through Firebase AI Logic (Developer
/// API, free tier) for a JSON answer in a fixed shape. No API key is stored in
/// the app; the model name comes from Remote Config.
final class FirebaseEstimateBackend implements FoodEstimateBackend {
  FirebaseEstimateBackend(this._runtime);

  final FirebaseRuntime _runtime;

  static Schema _schema() {
    return Schema.object(
      properties: <String, Schema>{
        // Ingredients come first, so the numbers are worked out from them.
        'ingredients': Schema.array(
          items: Schema.object(
            properties: <String, Schema>{
              'name': Schema.string(),
              'grams': Schema.number(),
            },
          ),
        ),
        'is_food': Schema.boolean(),
        'group': Schema.enumString(
          enumValues: FoodEstimateService.groupNames,
        ),
        'serving_grams': Schema.number(),
        'kcal': Schema.number(),
        'protein_g': Schema.number(),
        'carbs_g': Schema.number(),
        'fat_g': Schema.number(),
        'fibre_g': Schema.number(),
        'grams_per_piece': Schema.number(),
      },
      optionalProperties: <String>['grams_per_piece'],
      propertyOrdering: <String>[
        'ingredients',
        'is_food',
        'group',
        'serving_grams',
        'kcal',
        'protein_g',
        'carbs_g',
        'fat_g',
        'fibre_g',
        'grams_per_piece',
      ],
    );
  }

  @override
  Future<String> generateEstimateJson(String prompt) async {
    await _runtime.prepare('food estimate');
    final GenerativeModel model = FirebaseAI.googleAI().generativeModel(
      model: _runtime.modelName(),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema(),
        maxOutputTokens: 700,
        temperature: 0.2,
      ),
    );
    final GenerateContentResponse response = await _runtime.traceRequest(
      'food estimate',
      () => model.generateContent(<Content>[Content.text(prompt)]),
    );
    return response.text ?? '';
  }
}
