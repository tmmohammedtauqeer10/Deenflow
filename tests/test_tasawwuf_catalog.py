"""Run from repository root: python -m unittest discover -s tests."""
import json
from pathlib import Path
import unittest
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]

class TasawwufCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((ROOT / 'tasawwuf_api.json').read_text(encoding='utf-8'))

    def test_counts_and_required_metadata(self):
        d = self.data
        self.assertEqual(d['section_id'], 'tasawwuf')
        self.assertEqual(d['api_version'], '1.0')
        self.assertEqual(d['editorial_status'], 'introductory_draft')
        for key, count in [('stages',4),('modules',12),('lessons',24),('books',8),('glossary',20),('faqs',7)]:
            self.assertEqual(len(d[key]), count, key)
        self.assertEqual(d['estimated_weeks'], 12)

    def test_ids_are_unique(self):
        ids = [item['id'] for key in ['stages','modules','lessons','books','sources'] for item in self.data[key]]
        self.assertEqual(len(ids), len(set(ids)))

    def test_path_is_complete_and_prerequisites_are_acyclic(self):
        d = self.data
        stages = {s['id']:s for s in d['stages']}
        modules = {m['id']:m for m in d['modules']}
        lesson_ids = {l['id'] for l in d['lessons']}
        book_ids = {b['id'] for b in d['books']}
        covered = []
        for s in stages.values():
            self.assertEqual(len(s['module_ids']),3)
            for mid in s['module_ids']:
                self.assertEqual(modules[mid]['stage_id'],s['id'])
        stage_members = [mid for s in stages.values() for mid in s['module_ids']]
        self.assertCountEqual(stage_members,list(modules))
        self.assertEqual(sorted(m['week'] for m in modules.values()), list(range(1,13)))
        for m in modules.values():
            self.assertIn(m['stage_id'],stages)
            self.assertEqual(len(m['lesson_ids']),2)
            self.assertTrue(set(m['lesson_ids']) <= lesson_ids)
            self.assertTrue(set(m['book_ids']) <= book_ids)
            for pre in m['prerequisite_ids']:
                self.assertIn(pre,modules)
                self.assertLess(modules[pre]['week'],m['week'])
            covered.extend(m['lesson_ids'])
        self.assertCountEqual(covered,list(lesson_ids))

    def test_lessons_have_content_valid_sources_and_answers(self):
        refs = {s['id'] for s in self.data['sources']}
        questions = []
        for lesson in self.data['lessons']:
            for field in ['title','summary','practice','reflection']:
                self.assertTrue(lesson[field].strip(),(lesson['id'],field))
            self.assertGreaterEqual(len(lesson['summary'].split()),30)
            self.assertTrue(lesson['source_ids'])
            self.assertTrue(set(lesson['source_ids']) <= refs)
            q = lesson['checkpoint']
            self.assertEqual(len(q['options']),4)
            self.assertEqual(len(set(q['options'])),4)
            self.assertIs(type(q['correct_index']),int)
            self.assertIn(q['correct_index'],range(4))
            self.assertTrue(q['explanation'].strip())
            questions.append(q['question'].casefold())
        self.assertEqual(len(questions),len(set(questions)))

    def test_external_links_and_book_access_are_explicit(self):
        for item in self.data['sources'] + self.data['books']:
            uri = urlparse(item['url'])
            self.assertEqual(uri.scheme,'https')
            self.assertTrue(uri.netloc)
        for book in self.data['books']:
            self.assertIn(book['access_type'],['publisher','online_text','reference_index'])
            self.assertIsNone(book['download_url'])
            self.assertTrue(book['rights_note'])
            self.assertTrue(book['reading_guidance'])

    def test_library_discovery_and_existing_quiz(self):
        library = json.loads((ROOT/'library_api.json').read_text(encoding='utf-8'))
        cat = next(c for c in library['categories'] if c['category_id']=='cat_tazkiyah')
        self.assertEqual(cat['learning_path']['section_id'],self.data['section_id'])
        self.assertTrue(cat['learning_path']['api_url'].endswith('/tasawwuf_api.json'))
        quiz = json.loads((ROOT/'quiz_data.json').read_text(encoding='utf-8'))
        self.assertEqual(sum(len(c['questions']) for c in quiz['categories']),150)

if __name__ == '__main__':
    unittest.main()
