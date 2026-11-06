import 'package:firebase_ai/firebase_ai.dart';

import '../../ai/data/firebase_runtime.dart';
import '../../pantry/domain/default_categories.dart';
import '../domain/order_ai.dart';

/// Gemini (Developer API, free tier) through Firebase AI Logic with App Check,
/// asked to pick the products out of order-screenshot text as JSON in a fixed
/// shape. No API key is stored in the app; the model name comes from Remote
/// Config.
final class FirebaseOrderBackend implements OrderBackend {
  FirebaseOrderBackend(this._runtime);

  final FirebaseRuntime _runtime;

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

  static Schema _schema() {
    return Schema.object(
      properties: <String, Schema>{
        'items': Schema.array(
          items: Schema.object(
            properties: <String, Schema>{
              'name': Schema.string(),
              'brand': Schema.string(),
              'quantity': Schema.number(),
              'unit': Schema.enumString(enumValues: _units),
              'price': Schema.number(),
              'category': Schema.enumString(
                enumValues: <String>[
                  for (final DefaultCategory c in kDefaultCategories) c.id,
                ],
              ),
              'is_food': Schema.boolean(),
            },
            optionalProperties: <String>[
              'brand',
              'quantity',
              'unit',
              'price',
              'category',
              'is_food',
            ],
          ),
        ),
      },
    );
  }

  @override
  Future<String> parseOrderJson(String prompt) async {
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
