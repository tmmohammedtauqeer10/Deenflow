# Complete-edition book files

This folder contains real book texts and a historical scan, rather than lesson summaries. The individual edition scopes below are significant.

| Work | Language | Included files | Edition scope |
| --- | --- | --- | --- |
| The Beginning of Guidance | Arabic | `beginning-ar.txt`, `beginning-ar.html` | Complete Wikisource source-page transcription, revision 305860; not a newly verified critical edition. |
| Forty Hadith of Imam an-Nawawi | Arabic | `nawawi-ar.txt`, `nawawi-ar.html` | All 42 hadith sections on the selected Wikisource page, revision 500107, including source-page commentary. Commentary is not represented as an-Nawawi's own writing. |
| The Alchemy of Happiness | English | `alchemy-field-1910-en.pdf`, `alchemy-field-1910-en.txt` | Complete 1910 Claud Field edition: 124 scanned leaves through printed page 115. This historical translation is abridged relative to the Persian original. The text file is unedited OCR and may contain errors; use the scan for checking. |
| Kimiya-e Saadat | Urdu | External hosted reader only | [Rekhta listing](https://www.rekhta.org/ebooks/detail/keemiaye-sa-adat-ebooks?lang=ur) gives 574 pages, Matba Hashmi, Meerut. Not mirrored; this repository has not independently verified every scanned leaf or the translation's rights. |

## Reading and downloads

- Open the text files directly on GitHub or use the Raw/download control.
- Download the HTML files to read Arabic locally in a browser; the files have no scripts or required remote assets.
- Download the PDF for the historical English page images.
- The Flutter book shelf offers in-app text reading, font-size controls, approximate saved reading position, and cached text after the first successful download. Optional bundled text assets support a first launch offline.
- Remaining book recommendations retain external publisher/text links. The presence of a modern translation in the catalog does not give permission to redistribute that translation.

## Attribution and licenses

**These third-party books are not relicensed under the repository's MIT license.**

The Arabic source transcriptions are attributed to Arabic Wikisource contributors and distributed here under [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/). The original classical works are separate from the modern transcription and commentary. Each adapted file contains the source revision URL, contributor-history link, license link and change notice. Navigation was removed and formatting was converted; no intentional abridgment of book text was made. Wikisource transcriptions may contain typographical errors and are not a replacement for a critically edited edition. Copies/adaptations of these files must preserve the required attribution and share-alike terms.

The English files are unchanged downloads of the [1910 John Murray edition held by Princeton Theological Seminary Library and scanned through Internet Archive](https://archive.org/details/alchemyofhappine00algh). Al-Ghazali died in 1111 and translator Claud Field died in 1941. The public-domain assessment applies to this historical edition, not to modern translations, introductions or re-editions. No modern publisher translation was copied.

`manifest.json` records exact source URLs, revisions where applicable, edition notes, byte sizes and SHA-256 file hashes. Files should not be silently replaced with a different edition. Update the manifest and review licensing whenever a file changes.

## Validation

Run from the repository root:

```sh
python -m unittest discover -s tests
```

Tests check file hashes, sizes, UTF-8 decoding, PDF signature, source attribution, all 42 Arabic hadith headings and catalog links. They do not certify theological conclusions or textual accuracy.
