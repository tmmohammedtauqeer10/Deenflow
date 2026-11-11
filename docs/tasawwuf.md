# Tasawwuf, Tazkiyah & Ihsan

DeenFlow now includes a dedicated, source-linked introductory section for sincere worship, purification and good character. The path is informed by classical Sunni scholarship and acknowledges differences in terminology and practice. It is an educational draft, not an endorsed scholarly curriculum or a fatwa.

## Included

- Four stages, twelve suggested weeks, twelve modules and twenty-four lessons.
- A practical exercise, private reflection prompt, source references and a multiple-choice knowledge check for every lesson.
- Nine book entries, with levels, reading guidance and external publisher/text links.
- Twenty glossary terms, seven FAQs, teacher-selection guidance and learning outcomes.
- A Flutter screen with Path, Books, Glossary and Guide tabs; local completion and saved-book selections; network timeout/retry; cached and optional bundled offline content; and clear-local-progress controls.
- A standard-library Python validator for catalog structure and cross-references.

## Path

| Stage | Weeks | Topics |
| --- | --- | --- |
| Establish the foundations | 1–3 | Ihsan, obligations, intention, repentance, prayer, remembrance |
| Refine everyday character | 4–6 | Speech, disagreement, humility, envy, anger, sincerity |
| Live the virtues | 7–9 | Patience, gratitude, reliance, hope, family, service |
| Sustain the journey | 10–12 | Companionship, guided reading, self-accounting, watchfulness, consistency |

The twelve-week schedule and fifteen-minute lessons are suggestions. Learners may repeat lessons or change pace. Prerequisite IDs express a recommended sequence; they do not lock access. Completion tracks study activity, never purity, spiritual rank or salvation. Exercises do not introduce ritual counts or claim special rewards.

## Reading shelf

1. **The Beginning of Guidance** — al-Ghazali; beginner; [publisher](https://www.whitethreadpress.com/products/ghazalis-the-beginning-of-guidance-bidayat-al-hidaya).
2. **Forty Hadith** — an-Nawawi; beginner; [online collection](https://sunnah.com/nawawi40).
3. **Riyad as-Salihin** — an-Nawawi; beginner; [online collection](https://sunnah.com/riyadussalihin).
4. **The Book of Assistance** — al-Haddad; intermediate; [publisher](https://fonsvitae.com/product/the-book-of-assistance-imam-abdallah-ibn-alawi-al-haddad-risalatul-muawanah/).
5. **Ihya Ulum al-Din** — al-Ghazali; intermediate; [Arabic reference index](https://www.ghazali.org/ihya/ihya.htm).
6. **The Marvels of the Heart** — al-Ghazali; intermediate; [publisher](https://fonsvitae.com/product/al-ghazali-the-marvels-of-the-heart-science-of-the-spirit-book-xxi-of-the-revival-of-the-religious-sciences/).
7. **Al-Qushayri’s Epistle on Sufism** — al-Qushayri; advanced, guided reading; [publisher](https://www.garnetpublishing.co.uk/product/al-qushayris-epistle-on-sufism-al-risala-al-qushayriyya-fi-ilm-al-tasawwuf/).
8. **The Book of Wisdoms**, with commentary — Ibn Ata Allah; advanced, guided reading; [publisher](https://www.whitethreadpress.com/products/the-book-of-wisdoms-kitab-al-hikam-with-ikmal-al-shiyam).

The shelf now includes complete-edition files for three works in `books/tasawwuf/`: Arabic transcriptions of **The Beginning of Guidance** and **Forty Hadith** (the source includes commentary), and the full **1910 Claud Field English edition of The Alchemy of Happiness**, supplied as an unchanged scan and OCR. The English edition is abridged relative to the Persian original; it must not be described as the complete Persian work. The Arabic files reproduce the complete selected source pages, not a newly certified critical edition.

An Urdu **Kimiya-e Saadat** listing opens Rekhta’s hosted reader. Rekhta lists 574 pages; all scanned leaves and translation authorship have not been independently verified. No Urdu scan is copied into this repository because redistribution permission has not been established. Other modern translations retain publisher links. The manifest records source revisions, attribution, formats, file sizes, SHA-256 checksums and edition limitations.

The screen opens `.txt` editions in `TasawwufBookReader`, with right-to-left Arabic support, text-size controls, approximate reading-position persistence and local text caching. HTML, PDF and hosted-reader links open externally. Never pass a hosted HTML page to `SmartReaderScreen`, which expects PDF bytes. Third-party files have their own rights and are not covered by the repository’s MIT license; see `books/tasawwuf/README.md`.

## Connect to the Flutter app

This repository currently contains reusable screens and JSON feeds, but no `main.dart`, `pubspec.yaml`, app router, Android/iOS projects or widget-test harness. The new screen is supplied for integration into the host app; it cannot automatically add a home-screen tile that is absent from this repository.

1. Include `lib/tasawwuf_screen.dart` and `lib/tasawwuf_book_reader.dart` in your host app.
2. In the host project run `flutter pub add http shared_preferences url_launcher`. Resolve versions compatible with that app’s Flutter SDK. The screen uses the existing repository’s legacy SharedPreferences API for consistency; it does not require changes to the audio feature.
3. Ensure Android has the `android.permission.INTERNET` permission. Follow the [HTTP package](https://pub.dev/packages/http) and [URL launcher](https://pub.dev/packages/url_launcher) platform setup instructions for your target platforms.
4. Import the screen and add a navigation entry:

```dart
import 'tasawwuf_screen.dart';

// In an existing home/drawer/menu widget:
ListTile(
  leading: const Icon(Icons.spa_outlined),
  title: const Text('Tasawwuf & Ihsan'),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const TasawwufScreen()),
  ),
)
```

5. For offline access before the first successful download, copy `tasawwuf_api.json` and the three text files (preserving their `books/tasawwuf/` paths) into the host project and add this to its existing asset list:

```yaml
flutter:
  assets:
    - tasawwuf_api.json
    - books/tasawwuf/beginning-ar.txt
    - books/tasawwuf/nawawi-ar.txt
    - books/tasawwuf/alchemy-field-1910-en.txt
```

6. Run `flutter analyze` and test the checklist below in the host app.

The screen fetches `https://raw.githubusercontent.com/tmmohammedtauqeer10/Deenflow/main/tasawwuf_api.json`. It validates the version and basic collection shape before caching. If fetching fails, it tries the previous cached catalog and then the optional bundled asset. A failed cache write does not block reading. Book text already cached or bundled is available offline. External PDF/HTML files, source websites and hosted-reader editions still need a connection.

## Content contract

`tasawwuf_api.json` is a versioned object containing `section_id`, `api_version`, `stages`, `modules`, `lessons`, `books`, `sources`, `glossary`, `faqs`, `weekly_plan`, `learning_outcomes`, `teacher_guidance`, `privacy` and editorial metadata.

- Stages reference module IDs; modules reference lesson and book IDs.
- Each module has a stage ID, suggested week and prerequisite module IDs.
- Lessons reference source IDs. Checkpoint `correct_index` is zero-based, with four distinct answer options.
- Book `editions` lists available languages and formats (`txt`, `html`, `pdf`, `hosted_reader`). Files are listed in `books/tasawwuf/manifest.json`; a non-null `download_url` must match a listed edition URL.
- Book `access_type` distinguishes `publisher`, `online_text` and `reference_index`; `url` is always an external HTTPS destination.
- `editorial_status` is `introductory_draft`. Keep it a draft until an identified, qualified reviewer signs off on the material. Do not invent a reviewer or endorsement.
- Existing `library_api.json` readers can ignore the additive `learning_path` field on `cat_tazkiyah`. New clients can use that pointer to discover the section.

Run:

```sh
python -m unittest discover -s tests -p 'test_tasawwuf_catalog.py'
```

When adding content, keep IDs stable, cite appropriate sources, distinguish a teaching from an original exercise, and verify all new cross-references. Update the counts asserted by the validator if intentionally expanding the catalog.

## Local data

The supplied screens store completed lesson IDs, saved-book IDs, cached plain-text editions, approximate reading positions and text-size settings in SharedPreferences. These records are device-local, not encrypted and not guaranteed to survive device loss or app removal. It stores no private journal text, confessions, analytics, account identifiers or spiritual ratings. The host app’s other features retain their own policies. Clear local progress removes this section’s completion and saved-book records; catalog and book caches and reading positions are retained for offline reading. The host app can clear its app storage to remove all feature data. Opening external links is subject to those sites’ own policies.

## Halaqa / facilitator format

For an optional weekly gathering, read both lessons beforehand, review the primary references, discuss one general scenario, and choose one practical action. Participation and sharing are voluntary; do not request private sins or require public progress reports. Keep fiqh questions for qualified scholarship and seek explanation for advanced terminology. End with a realistic next step rather than a comparison between learners.

## Host verification checklist

- Open the section on a small phone and with large system text.
- Open all four tabs, a lesson, a source link, a publisher link and each full-text edition.
- Read Arabic right-to-left and English left-to-right; change font size, reopen the reader and check approximate reading position.
- Cache a text edition, disable networking and reopen it. Confirm that the PDF is a scan, not an app-generated summary.
- Confirm that an incorrect answer allows retry and a correct answer enables completion.
- Complete a lesson, restart the app, then mark it incomplete.
- Save a book, restart, then remove it.
- Load once online, then open without network; also test a fresh install with the bundled asset.
- Simulate an HTTP error, timeout and unavailable local storage; reading should remain available where content exists, and a failed progress write must not claim success.
- Clear local progress and confirm the list resets while cached content remains.

Flutter analysis, widget tests and device rendering were not executed in the authoring environment because no Flutter/Dart SDK or full host app was available. The Python content tests are independently runnable. A host-app build and qualified content review remain necessary before releasing this as a fully integrated feature.

The unchanged 1910 English PDF was opened successfully (124 scan pages); title, contents and final printed page 115 were visually inspected. SHA-256 checks verify the committed files against the manifest. The book reader’s Dart syntax was parsed, but runtime behavior still requires the host verification above.
