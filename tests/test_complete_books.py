import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class CompleteBookTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT/'books/tasawwuf/manifest.json').read_text(encoding='utf-8'))
        cls.catalog = json.loads((ROOT/'tasawwuf_api.json').read_text(encoding='utf-8'))

    def test_files_are_real_and_match_manifest(self):
        files = self.manifest['files']
        self.assertEqual(len(files),6)
        self.assertEqual(len({f['book_id'] for f in files}),3)
        for item in files:
            path = (ROOT/item['path']).resolve()
            self.assertTrue(path.is_relative_to(ROOT/'books/tasawwuf'))
            blob = path.read_bytes()
            self.assertEqual(len(blob), item['bytes'])
            self.assertEqual(hashlib.sha256(blob).hexdigest(),item['sha256'])
            self.assertTrue(item['source_url'].startswith('https://'))
            self.assertTrue(item['license'])
            self.assertTrue(item['completeness'])
            if item['format']=='pdf':
                self.assertTrue(blob.startswith(b'%PDF-'))
                self.assertIn(b'%%EOF',blob[-1024:])
                self.assertGreater(len(blob),1000000)
            else:
                text=blob.decode('utf-8')
                self.assertGreater(len(text),40000)
                if item['language_code']=='ar':
                    self.assertIn('creativecommons.org/licenses/by-sa/4.0/',text)
                    self.assertIn('oldid='+item['source_revision'],text)

    def test_arabic_collection_has_all_42_hadith_sections(self):
        text=(ROOT/'books/tasawwuf/nawawi-ar.html').read_text(encoding='utf-8')
        self.assertEqual(text.count('<h3'),42)
        self.assertIn('الحديث الثاني والأربعون',text)
        self.assertIn('BEGIN BOOK',(ROOT/'books/tasawwuf/nawawi-ar.txt').read_text(encoding='utf-8'))

    def test_each_catalog_edition_matches_manifest(self):
        expected={e['id']:e for e in self.manifest['files']+self.manifest['hosted_editions']}
        actual={e['id']:e for b in self.catalog['books'] for e in b.get('editions',[])}
        self.assertEqual(set(expected),set(actual))
        for eid,e in actual.items():
            self.assertEqual(e['url'],expected[eid]['url'])
            self.assertEqual(e['language_code'],expected[eid]['language_code'])
            if e['format']!='hosted_reader':
                self.assertEqual(e['sha256'],expected[eid]['sha256'])
                self.assertEqual(e['bytes'],expected[eid]['bytes'])
        urdu=self.manifest['hosted_editions'][0]
        self.assertEqual(urdu['language_code'],'ur')
        self.assertIsNone(urdu['download_url'])

if __name__=='__main__':
    unittest.main()
