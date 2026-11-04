# Offline words generator

The offline command parser (Phase 5) is driven by two generated files:

- `assets/dictionary/grocery_dictionary.json` – grocery products and every word people use for them (English, Telugu and Hindi, native script and romanised).
- `lib/features/commands/domain/parser_words.dart` – numbers, units, intent words, separators and filler words.

Both come from the files in this folder. Edit those, never the generated files.

| File | What it holds |
| --- | --- |
| `dictionary_source.txt` | One product per line: `English name \| category id \| usual unit \| forms, comma separated` |
| `tables.py` | Number words, unit words, intent words (add / need / bought / use / finished / remove / expiring / how much), separators and filler words |
| `generate.py` | Writes the two generated files |

## Regenerate

```
pip install regex
python3 tool/offline_words/generate.py
```

## Add a new language

1. Add the language's words for numbers, units and intents to the tables in `tables.py` (native script and romanised).
2. Add its product words to the `forms` column of `dictionary_source.txt`.
3. Add a value to `VoiceLanguage` (`lib/features/commands/domain/voice_language.dart`) with its speech locale (for example `ta-IN`) and a name for the AI prompt.
4. Regenerate, then add phrase tests to `test/features/commands/domain/offline_command_parser_test.dart`.

The dictionary test fails if one word is used for two different products, so collisions are caught at once.
