import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../domain/ai_command_service.dart';
import 'firebase_runtime.dart';

/// Gemini (Developer API, free tier) through Firebase AI Logic with App Check.
/// No API key is stored in the app.
final class FirebaseGenerativeBackend implements GenerativeBackend {
  FirebaseGenerativeBackend(this._runtime);

  final FirebaseRuntime _runtime;

  static const List<String> _intents = <String>[
    'add_stock',
    'use_stock',
    'mark_finished',
    'add_to_shopping_list',
    'remove_from_shopping_list',
    'query_expiring',
    'query_stock',
  ];
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
  static const List<String> _locations = <String>[
    'fridge',
    'freezer',
    'pantry',
    'other',
  ];

  static Schema _schema() {
    return Schema.object(
      properties: <String, Schema>{
        'actions': Schema.array(
          items: Schema.object(
            properties: <String, Schema>{
              'intent': Schema.enumString(enumValues: _intents),
              'item_name_en': Schema.string(),
              'original_text': Schema.string(),
              'quantity': Schema.number(),
              'unit': Schema.enumString(enumValues: _units),
              'expiry_date': Schema.string(),
              'storage_location': Schema.enumString(enumValues: _locations),
            },
            optionalProperties: <String>[
              'item_name_en',
              'original_text',
              'quantity',
              'unit',
              'expiry_date',
              'storage_location',
            ],
          ),
        ),
      },
    );
  }

  @override
  Future<String> generateJson(String prompt) async {
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

  @override
  Future<String> transcribe({
    required Uint8List audio,
    required String mimeType,
    required String prompt,
  }) async {
    await _runtime.ensureReady();
    final GenerativeModel model = FirebaseAI.googleAI().generativeModel(model: _runtime.modelName());
    final GenerateContentResponse response = await model.generateContent(
      <Content>[
        Content.multi(<Part>[TextPart(prompt), InlineDataPart(mimeType, audio)]),
      ],
    );
    return response.text ?? '';
  }
}
