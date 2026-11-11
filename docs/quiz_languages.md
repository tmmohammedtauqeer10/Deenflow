# Quiz languages

## Available content

| Language | Code | Direction | Feed | Questions |
| --- | --- | --- | --- | --- |
| English | `en` | LTR | `quiz_data.json` | 150 |
| Urdu | `ur` | RTL | `quiz_data.ur.json` | 150 |
| Hindi | `hi` | LTR | `quiz_data.hi.json` | 150 |
| Arabic | `ar` | RTL | `quiz_data.ar.json` | 150 |

`quiz_languages.json` is a discovery registry with labels, direction, file paths and raw GitHub URLs. Clients that already use English can keep using the unchanged `quiz_data.json`. The separate older `islamic_quiz_expanded.json` feed is not the source of these language packs.

Each translated feed preserves the existing schema: categories contain questions with `question_id`, `text`, `options` and zero-based `correct_index`. Numeric scoring fields and identifiers are unchanged. Extra top-level fields identify the language, text direction, English source and translation status.

## Translation status

All 150 questions and their options are translated in each new language, with localized category and difficulty labels. The initial drafts were machine-translated, followed by corrections for Islamic terminology, proper names, surah names, selected question wording and UI labels. They are marked `machine_translated_draft`; they have not received a complete fluent-speaker or scholarly review. Structural tests cannot establish linguistic or religious accuracy.

Review each question alongside its English original, all four options and the linked sources in `quiz_sources.md` where available. Particular attention is needed for negation, quoted teachings, transliteration and fiqh terminology. Existing English questions and answers have not been re-authenticated or changed as part of localization.

Do not shuffle only the translated options or change their meaning without updating the corresponding answer mapping. Question ID and option index are the stable bridge between languages. Keep answer choices distinct in each language.

## Flutter integration

`lib/quiz_screen.dart` is a standalone practice screen with a four-language picker, remembered language selection, localized interface labels, Urdu/Arabic right-to-left layout, category selection, answer feedback and session results. Switching languages retains the current question and selected answers because IDs and option positions align. Session results are in memory only; the screen does not award Supabase/account points.

The repository has no full Flutter entry point, router or `pubspec.yaml`. Add this file to the host app and wire it into the existing navigation:

```dart
import 'quiz_screen.dart';

ListTile(
  leading: const Icon(Icons.quiz_outlined),
  title: const Text('Islamic Quiz'),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const QuizScreen()),
  ),
)
```

The screen uses `http` and `shared_preferences`, already used by the repository's audio section. In the host project, run `flutter pub add http shared_preferences` if they are missing. Ensure the host platform permits HTTPS requests. Use Unicode fonts with Arabic and Devanagari glyphs; verify rendering with the host app's selected font and system text size.

For offline access from the first launch, copy the four feed files to the host app root and merge these entries into its asset list:

```yaml
flutter:
  assets:
    - quiz_data.json
    - quiz_data.ur.json
    - quiz_data.hi.json
    - quiz_data.ar.json
```

The fetch order is network (15-second timeout), that language's cached pack, then its optional bundled asset. If a requested non-English language is unavailable from all three sources, the screen tries the English pack and clearly identifies the fallback. It validates language, version, question IDs, option shape and answer indexes before using content. A cache write failure does not prevent a quiz session. Previously cached packs are retained when a download fails.

The language registry is for API clients; the supplied Flutter picker has four matching built-in language entries. Add any future language to both the registry and the widget's language/UI-label maps. Do not treat the registry's presence as automatic integration into the host app.

## Local storage

- `quiz_language`: last successfully selected language.
- `quiz_catalog_<code>_v2`: last successfully downloaded valid pack.

The screen does not save selected answers, exam scores, account identifiers or behavioral analytics. Cached quiz text is not sensitive or encrypted. Clearing the host app's storage removes these preferences.

## Validation

Run from the repository root:

```sh
python -m unittest discover -s tests
```

The multilingual tests check all 450 translated questions against the 150 English originals for category/question order, IDs, answer-index parity, four distinct choices, expected scripts, nonempty strings, translation metadata and registry consistency. They also guard corrected technical terms and selected surah names. This validates structure and scoring alignment; it does not substitute for a fluent-speaker review.

Dart syntax was parsed successfully. `flutter analyze`, widget tests and device rendering were not run because this checkout lacks a Flutter SDK and full host project. Before release, verify language switching during a question and at results, Urdu/Arabic RTL layout, Hindi glyphs, large text, offline packs, clear fallback messaging and final scores in the host app.
