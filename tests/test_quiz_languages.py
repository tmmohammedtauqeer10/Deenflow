"""Structural and scoring-parity checks for every quiz language pack."""
import json
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]

class QuizLanguageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=json.loads((ROOT/'quiz_data.json').read_text(encoding='utf-8'))
        cls.registry=json.loads((ROOT/'quiz_languages.json').read_text(encoding='utf-8'))

    def test_registry_and_files(self):
        self.assertEqual(self.registry['default_language'],'en')
        self.assertEqual({x['code'] for x in self.registry['languages']},{'en','ur','hi','ar'})
        for lang in self.registry['languages']:
            self.assertTrue((ROOT/lang['file']).is_file())
            self.assertTrue(lang['url'].endswith('/'+lang['file']))
            self.assertEqual(lang['text_direction'],'rtl' if lang['code'] in ['ur','ar'] else 'ltr')

    def test_all_categories_questions_and_scoring_align(self):
        for lang in self.registry['languages']:
            with self.subTest(language=lang['code']):
                d=json.loads((ROOT/lang['file']).read_text(encoding='utf-8'))
                self.assertEqual(d['api_version'],self.source['api_version'])
                self.assertEqual(d['total_categories'],10)
                self.assertEqual(len(d['categories']),len(self.source['categories']))
                total=0
                ids=[]
                for original,translated in zip(self.source['categories'],d['categories']):
                    self.assertEqual(translated['category_id'],original['category_id'])
                    self.assertEqual(translated['points_per_question'],original['points_per_question'])
                    self.assertEqual(len(translated['questions']),len(original['questions']))
                    self.assertTrue(translated['category_name'].strip())
                    for oq,q in zip(original['questions'],translated['questions']):
                        ids.append(q['question_id'])
                        self.assertEqual(q['question_id'],oq['question_id'])
                        self.assertEqual(q['correct_index'],oq['correct_index'])
                        self.assertEqual(len(q['options']),4)
                        self.assertEqual(len(set(q['options'])),4)
                        self.assertTrue(q['text'].strip())
                        self.assertTrue(all(isinstance(v,str) and v.strip() for v in q['options']))
                        self.assertNotRegex(q['text']+' '.join(q['options']),r'⟦|⟧|\ufffd')
                        total+=1
                self.assertEqual(total,150)
                self.assertEqual(len(ids),len(set(ids)))

    def test_translations_use_expected_scripts_and_draft_metadata(self):
        for code,script in [('ur',r'[\u0600-\u06ff]'),('hi',r'[\u0900-\u097f]'),('ar',r'[\u0600-\u06ff]')]:
            d=json.loads((ROOT/f'quiz_data.{code}.json').read_text(encoding='utf-8'))
            self.assertEqual(d['language'],code)
            self.assertEqual(d['source_language'],'en')
            self.assertEqual(d['translation_status'],'machine_translated_draft')
            for c in d['categories']:
                for q in c['questions']:
                    self.assertRegex(q['text'],script)

    def test_corrected_technical_terms_and_surah_names(self):
        expected={'ur':('متن','الرعد','النور'),'hi':('मत्न','अर-रअद','अन-नूर'),'ar':('المتن','الرعد','النور')}
        for code,(matn,thunder,light) in expected.items():
            d=json.loads((ROOT/f'quiz_data.{code}.json').read_text(encoding='utf-8'))
            qs={q['question_id']:q for c in d['categories'] for q in c['questions']}
            self.assertIn(matn,qs['q_had_006']['options'])
            self.assertIn(thunder,qs['q_surahs_008']['text'])
            self.assertIn(light,qs['q_surahs_012']['text'])

if __name__=='__main__':
    unittest.main()
