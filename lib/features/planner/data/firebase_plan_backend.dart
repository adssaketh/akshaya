import 'package:firebase_ai/firebase_ai.dart';

import '../../ai/data/firebase_runtime.dart';
import '../domain/ai_plan_service.dart';

/// Gemini (Developer API, free tier) through Firebase AI Logic with App Check,
/// asked for a weekly meal plan as JSON in a fixed shape. No API key is stored
/// in the app; the model name comes from Remote Config.
final class FirebasePlanBackend implements PlanBackend {
  FirebasePlanBackend(this._runtime);

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
  static const List<String> _slots = <String>[
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  static Schema _schema() {
    return Schema.object(
      properties: <String, Schema>{
        'recipes': Schema.array(
          items: Schema.object(
            properties: <String, Schema>{
              'id': Schema.string(),
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
                  },
                  optionalProperties: <String>['quantity', 'unit'],
                ),
              ),
              'steps': Schema.array(items: Schema.string()),
              'uses_expiring': Schema.array(items: Schema.string()),
              'prep': Schema.array(
                items: Schema.object(
                  properties: <String, Schema>{
                    'text': Schema.string(),
                    'days_before': Schema.number(),
                    'time': Schema.string(),
                  },
                ),
              ),
            },
            optionalProperties: <String>['cuisine', 'uses_expiring', 'prep'],
          ),
        ),
        'meals': Schema.array(
          items: Schema.object(
            properties: <String, Schema>{
              'date': Schema.string(),
              'slot': Schema.enumString(enumValues: _slots),
              'recipe_id': Schema.string(),
            },
          ),
        ),
      },
    );
  }

  @override
  Future<String> generatePlanJson(String prompt) async {
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
