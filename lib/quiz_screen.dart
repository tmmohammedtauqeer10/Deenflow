import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _quizLanguages = {'en': 'English', 'ur': 'اردو', 'hi': 'हिन्दी', 'ar': 'العربية'};
const _quizLabels = {
  'en': {'title':'Islamic Quiz','choose':'Choose a category','questions':'questions','question':'Question','next':'Next','finish':'See results','correct':'Correct','incorrect':'Incorrect','answer':'Correct answer','results':'Your results','score':'Correct answers','again':'Try again','categories':'Categories','retry':'Retry','error':'Could not load quiz content. Connect and retry.','draft':'Translation draft — fluent-speaker review pending.','cached':'Saved or bundled content','fallback':'Requested language unavailable. Showing English.','session':'Practice session only; no account points are awarded.'},
  'ur': {'title':'اسلامی کوئز','choose':'ایک زمرہ منتخب کریں','questions':'سوالات','question':'سوال','next':'اگلا','finish':'نتائج دیکھیں','correct':'درست','incorrect':'غلط','answer':'درست جواب','results':'آپ کے نتائج','score':'درست جوابات','again':'دوبارہ کوشش کریں','categories':'زمرے','retry':'دوبارہ کوشش کریں','error':'کوئز لوڈ نہیں ہو سکا۔ انٹرنیٹ سے جڑ کر دوبارہ کوشش کریں۔','draft':'ترجمے کا مسودہ — ماہر زبان کا جائزہ ابھی باقی ہے۔','cached':'محفوظ یا ایپ میں شامل مواد','fallback':'مطلوبہ زبان دستیاب نہیں۔ انگریزی دکھائی جا رہی ہے۔','session':'یہ صرف مشق ہے؛ اکاؤنٹ میں پوائنٹس شامل نہیں کیے جاتے۔'},
  'hi': {'title':'इस्लामी क्विज़','choose':'एक श्रेणी चुनें','questions':'प्रश्न','question':'प्रश्न','next':'अगला','finish':'परिणाम देखें','correct':'सही','incorrect':'ग़लत','answer':'सही उत्तर','results':'आपके परिणाम','score':'सही उत्तर','again':'फिर से कोशिश करें','categories':'श्रेणियाँ','retry':'पुनः प्रयास करें','error':'क्विज़ लोड नहीं हुई। इंटरनेट से जुड़कर फिर कोशिश करें।','draft':'अनुवाद का मसौदा — भाषा-समीक्षा अभी बाकी है।','cached':'सहेजी गई या ऐप में शामिल सामग्री','fallback':'चुनी गई भाषा उपलब्ध नहीं है। अंग्रेज़ी दिखाई जा रही है।','session':'यह केवल अभ्यास है; खाते में अंक नहीं जोड़े जाते।'},
  'ar': {'title':'الاختبار الإسلامي','choose':'اختر فئة','questions':'أسئلة','question':'السؤال','next':'التالي','finish':'عرض النتائج','correct':'إجابة صحيحة','incorrect':'إجابة غير صحيحة','answer':'الإجابة الصحيحة','results':'نتائجك','score':'الإجابات الصحيحة','again':'حاول مرة أخرى','categories':'الفئات','retry':'إعادة المحاولة','error':'تعذر تحميل الاختبار. اتصل بالإنترنت وحاول مجدداً.','draft':'مسودة ترجمة — لم تكتمل مراجعتها اللغوية.','cached':'محتوى محفوظ أو مرفق بالتطبيق','fallback':'اللغة المطلوبة غير متاحة. يُعرض المحتوى بالإنجليزية.','session':'هذه جلسة تدريب فقط؛ لا تُضاف نقاط إلى الحساب.'},
};

Map<String, dynamic> _parseQuiz(String text, String language) {
  final data = Map<String, dynamic>.from(jsonDecode(text) as Map);
  if (data['status'] != 'success' || data['api_version'] != '2.0' ||
      (data['language'] ?? 'en') != language) {
    throw const FormatException('Unsupported quiz catalog');
  }
  final categories = data['categories'] as List;
  if (categories.isEmpty) throw const FormatException('No quiz categories');
  final ids = <String>{};
  for (final c in categories) {
    if ((c['category_name'] as String).trim().isEmpty) throw const FormatException('Empty category');
    final questions = c['questions'] as List;
    if (questions.isEmpty) throw const FormatException('Empty question list');
    for (final q in questions) {
      final options = (q['options'] as List).cast<String>();
      final answer = q['correct_index'];
      if (!ids.add(q['question_id'] as String) || (q['text'] as String).trim().isEmpty ||
          options.length != 4 || options.toSet().length != 4 ||
          options.any((o) => o.trim().isEmpty) || answer is! int || answer < 0 || answer >= 4) {
        throw const FormatException('Invalid quiz question');
      }
    }
  }
  return data;
}

/// Standalone practice UI. Host navigation and account rewards are intentionally external.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _client = http.Client();
  SharedPreferences? _prefs;
  Map<String, dynamic>? _catalog;
  String _language = 'en';
  String? _categoryId;
  bool _loading = true;
  bool _failed = false;
  bool _cached = false;
  bool _fallback = false;
  bool _results = false;
  int _index = 0;
  final Map<String, int> _answers = {};
  String t(String key) => _quizLabels[_language]![key]!;
  String _file(String language) => language == 'en' ? 'quiz_data.json' : 'quiz_data.$language.json';

  @override
  void initState() { super.initState(); _init(); }
  @override
  void dispose() { _client.close(); super.dispose(); }

  Future<void> _init() async {
    try { _prefs = await SharedPreferences.getInstance(); } catch (_) { /* Read without preferences. */ }
    if (!mounted) return;
    final saved = _prefs?.getString('quiz_language') ?? 'en';
    await _load(_quizLanguages.containsKey(saved) ? saved : 'en');
  }

  Future<Map<String, dynamic>> _fetch(String language) async {
    final filename = _file(language);
    final cacheKey = 'quiz_catalog_${language}_v2';
    try {
      final response = await _client.get(Uri.parse('https://raw.githubusercontent.com/tmmohammedtauqeer10/Deenflow/main/$filename')).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final text = utf8.decode(response.bodyBytes);
      final data = _parseQuiz(text, language);
      try { await _prefs?.setString(cacheKey, text); } catch (_) { /* Reading still works. */ }
      _cached = false;
      return data;
    } catch (_) {
      try {
        final cached = _prefs?.getString(cacheKey);
        if (cached != null) { final data = _parseQuiz(cached, language); _cached = true; return data; }
      } catch (_) { /* Try optional bundled file. */ }
      final data = _parseQuiz(await rootBundle.loadString(filename), language);
      _cached = true;
      return data;
    }
  }

  Future<void> _load(String requested) async {
    if (!mounted) return;
    setState(() { _loading = true; _failed = false; });
    String actual = requested;
    Map<String, dynamic>? data;
    try { data = await _fetch(requested); }
    catch (_) {
      if (requested != 'en') {
        actual = 'en';
        try { data = await _fetch('en'); } catch (_) { /* Show retry state. */ }
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = data == null;
      if (data != null) {
        _catalog = data;
        _language = actual;
        _fallback = actual != requested;
        // IDs and option order are aligned across language packs, so answers are retained.
      }
    });
    if (data != null && actual == requested) {
      try { await _prefs?.setString('quiz_language', actual); } catch (_) { /* Session selection still works. */ }
    }
  }

  Map<String, dynamic>? get _category {
    if (_categoryId == null || _catalog == null) return null;
    for (final c in _catalog!['categories'] as List) {
      if (c['category_id'] == _categoryId) return Map<String, dynamic>.from(c as Map);
    }
    return null;
  }

  void _start(String id) => setState(() { _categoryId = id; _index = 0; _results = false; _answers.clear(); });
  void _home() => setState(() { _categoryId = null; _index = 0; _results = false; _answers.clear(); });

  @override
  Widget build(BuildContext context) {
    final rtl = _language == 'ur' || _language == 'ar';
    return Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(title: Text(t('title')), actions: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: DropdownButton<String>(
          value: _language,
          items: _quizLanguages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: _loading ? null : (value) { if (value != null) _load(value); },
        )),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _failed ? Center(child: Padding(
        padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(t('error')), ElevatedButton(onPressed: () => _load(_language), child: Text(t('retry')))]),
      )) : ListView(padding: const EdgeInsets.all(20), children: [
        if (_fallback) _notice(t('fallback')),
        if (_cached) _notice(t('cached')),
        if (_language != 'en') _notice(t('draft')),
        if (_category == null) ..._categoryList() else ..._questionOrResults(_category!),
      ]),
    ));
  }

  Widget _notice(String text) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(text, style: const TextStyle(fontSize: 12)));

  List<Widget> _categoryList() => [
    Text(t('choose'), style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16),
    for (final c in _catalog!['categories'] as List) Card(child: ListTile(
      title: Text(c['category_name'] as String), subtitle: Text('${(c['questions'] as List).length} ${t('questions')} · ${c['difficulty']}'),
      trailing: const Icon(Icons.chevron_right), onTap: () => _start(c['category_id'] as String),
    )),
  ];

  List<Widget> _questionOrResults(Map<String, dynamic> category) {
    final questions = (category['questions'] as List).cast<Map>();
    if (_results) {
      final score = questions.where((q) => _answers[q['question_id']] == q['correct_index']).length;
      return [Text(t('results'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24), Text('${t('score')}: $score / ${questions.length}', style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 16), Text(t('session')), const SizedBox(height: 24),
        ElevatedButton(onPressed: () => _start(category['category_id'] as String), child: Text(t('again'))),
        TextButton(onPressed: _home, child: Text(t('categories'))),
      ];
    }
    final q = questions[_index];
    final selected = _answers[q['question_id']];
    final correct = q['correct_index'] as int;
    final options = (q['options'] as List).cast<String>();
    return [
      TextButton(onPressed: _home, child: Text(t('categories'))),
      Text(category['category_name'] as String), const SizedBox(height: 12),
      Text('${t('question')} ${_index + 1} / ${questions.length}'), const SizedBox(height: 12),
      LinearProgressIndicator(value: (_index + 1) / questions.length), const SizedBox(height: 24),
      Text(q['text'] as String, style: const TextStyle(fontSize: 22, height: 1.6)), const SizedBox(height: 20),
      for (int i = 0; i < options.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton(
        onPressed: selected != null ? null : () => setState(() => _answers[q['question_id'] as String] = i),
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Icon(selected == null ? Icons.circle_outlined : i == correct ? Icons.check_circle : i == selected ? Icons.cancel : Icons.circle_outlined),
          const SizedBox(width: 12), Expanded(child: Text(options[i], style: const TextStyle(fontSize: 18))),
        ])),
      )),
      if (selected != null) ...[
        Text(selected == correct ? t('correct') : '${t('incorrect')} · ${t('answer')}: ${options[correct]}', style: const TextStyle(fontWeight: FontWeight.bold, height: 1.6)),
        const SizedBox(height: 18), ElevatedButton(onPressed: () => setState(() { if (_index + 1 == questions.length) { _results = true; } else { _index++; } }), child: Text(_index + 1 == questions.length ? t('finish') : t('next'))),
      ],
    ];
  }
}
