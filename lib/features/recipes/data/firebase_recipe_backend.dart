import 'package:firebase_ai/firebase_ai.dart';

import '../../ai/data/firebase_runtime.dart';
import '../domain/ai_recipe_service.dart';

/// Gemini (Developer API, free tier) through Firebase AI Logic with App Check,
/// asked for recipe ideas as JSON in a fixed shape. No API key is stored in the
/// app; the model name comes from Remote Config.
final class FirebaseRecipeBackend implements RecipeBackend {
  FirebaseRecipeBackend(this._runtime);

  final FirebaseRuntime _runtime;

  static const List<String> _diets = <String>['veg', 'egg', 'non_veg'];
  static const List<String> _units = <String>[
    'pcs',
    'g',
    'kg',
    'ml',
    'L',
    'packet',
    'dozen',
    'bunch',
  ];
  static const List<String> _statuses = <String>['in_pantry', 'missing'];

  static Schema _schema() {
    return Schema.object(
      properties: <String, Schema>{
        'recipes': Schema.array(
          items: Schema.object(
            properties: <String, Schema>{
              'title': Schema.string(),
              'time_minutes': Schema.number(),
              'servings': Schema.number(),
              'diet': Schema.enumString(enumValues: _diets),
              'cuisine': Schema.string(),
              'ingredients': Schema.array(
                items: Schema.object(
                  properties: <String, Schema>{
                    'name': Schema.string(),
                    'quantity': Schema.number(),
                    'unit': Schema.enumString(enumValues: _units),
                    'status': Schema.enumString(enumValues: _statuses),
                  },
                  optionalProperties: <String>['quantity', 'unit', 'status'],
                ),
              ),
              'steps': Schema.array(items: Schema.string()),
              'uses_expiring': Schema.array(items: Schema.string()),
            },
            optionalProperties: <String>['cuisine', 'uses_expiring'],
          ),
        ),
      },
    );
  }

  @override
  Future<String> generateRecipesJson(String prompt) async {
    await _runtime.ensureReady();
    final GenerativeModel model = FirebaseAI.googleAI().generativeModel(
      model: _runtime.modelName(),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema(),
      ),
    );
    final GenerateContentResponse response =
        await model.generateContent(<Content>[Content.text(prompt)]);
    return response.text ?? '';
  }
}
