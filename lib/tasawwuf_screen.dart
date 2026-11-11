import 'dart:convert';
import 'tasawwuf_book_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _catalogUrl = 'https://raw.githubusercontent.com/tmmohammedtauqeer10/Deenflow/main/tasawwuf_api.json';
const _cacheKey = 'tasawwuf_catalog_v1';
const _doneKey = 'tasawwuf_completed_v1';
const _savedKey = 'tasawwuf_saved_books_v1';
const _background = Color(0xFF0B132B);
const _surface = Color(0xFF152243);
const _gold = Color(0xFFD4AF37);

typedef Record = Map<String, dynamic>;
List<Record> _records(dynamic value) =>
    (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

Record _decodeCatalog(String text) {
  final data = Map<String, dynamic>.from(jsonDecode(text) as Map);
  if (data['api_version'] != '1.0' || data['section_id'] != 'tasawwuf') {
    throw const FormatException('Unsupported Tasawwuf catalog');
  }
  for (final key in ['stages', 'modules', 'lessons', 'books', 'sources', 'glossary', 'faqs']) {
    _records(data[key]);
  }
  if (_records(data['lessons']).isEmpty) {
    throw const FormatException('Catalog has no lessons');
  }
  return data;
}

Future<void> _openLink(BuildContext context, String value) async {
  try {
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' || uri.host.isEmpty ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const FormatException('Link cannot be opened');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link. Please try again.')),
      );
    }
  }
}

/// Add this screen to your host app's navigator. See docs/tasawwuf.md.
class TasawwufScreen extends StatefulWidget {
  const TasawwufScreen({super.key});
  @override
  State<TasawwufScreen> createState() => _TasawwufScreenState();
}

class _TasawwufScreenState extends State<TasawwufScreen> {
  Record? _data;
  SharedPreferences? _prefs;
  Set<String> _done = {};
  Set<String> _saved = {};
  bool _loading = true;
  bool _offline = false;
  String? _error;
  final _client = http.Client();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    SharedPreferences? prefs;
    Record? data;
    bool offline = false;
    try {
      prefs = await SharedPreferences.getInstance();
      final res = await _client.get(Uri.parse(_catalogUrl)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final text = utf8.decode(res.bodyBytes);
      data = _decodeCatalog(text);
      // A failed cache write must not discard successfully downloaded content.
      try { await prefs.setString(_cacheKey, text); } catch (_) { /* Read-only mode. */ }
    } catch (_) {
      offline = true;
      try {
        final cached = prefs?.getString(_cacheKey);
        if (cached != null) data = _decodeCatalog(cached);
      } catch (_) { /* Try the optional bundled asset next. */ }
      if (data == null) {
        try { data = _decodeCatalog(await rootBundle.loadString('tasawwuf_api.json')); }
        catch (_) { /* The host may not have configured the optional asset. */ }
      }
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _data = data;
      _offline = offline;
      _done = (prefs?.getStringList(_doneKey) ?? []).toSet();
      _saved = (prefs?.getStringList(_savedKey) ?? []).toSet();
      _loading = false;
      _error = data == null ? 'Could not load the learning path. Connect to the internet and retry, or add the bundled catalog asset.' : null;
    });
  }

  Future<bool> _persist(String key, Set<String> value) async {
    try {
      final prefs = _prefs;
      if (prefs == null || !await prefs.setStringList(key, value.toList())) {
        throw Exception('Storage unavailable');
      }
      if (!mounted) return false;
      setState(() { if (key == _doneKey) { _done = value; } else { _saved = value; } });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local progress could not be saved.')));
      }
      return false;
    }
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Clear local progress?'),
      content: const Text('This removes lesson completion and saved-book selections on this device. The downloaded catalog remains available.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear'))],
    ));
    if (confirm != true || !mounted) return;
    // Persist each successful operation independently so the UI always matches storage.
    await _persist(_doneKey, <String>{});
    await _persist(_savedKey, <String>{});
  }

  Widget _card(Widget child) => Card(color: _surface, margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: child));
  Widget _heading(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _gold)));

  @override
  Widget build(BuildContext context) {
    return Theme(data: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.dark(primary: _gold, surface: _surface),
    ), child: DefaultTabController(length: 4, child: Scaffold(
      appBar: AppBar(backgroundColor: _surface, title: const Text('Tasawwuf & Ihsan'), actions: [
        IconButton(tooltip: 'Refresh content', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        IconButton(tooltip: 'Clear local progress', onPressed: _loading ? null : _reset, icon: const Icon(Icons.delete_outline)),
      ], bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Learning path'), Tab(text: 'Books'), Tab(text: 'Glossary'), Tab(text: 'Guide')])),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Padding(
        padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Retry'))]),
      )) : TabBarView(children: [_path(), _books(), _glossary(), _guide()]),
    )));
  }

  Widget _path() {
    final data = _data!;
    final lessons = _records(data['lessons']);
    final validIds = lessons.map((l) => l['id'] as String).toSet();
    final count = _done.intersection(validIds).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _heading(data['title'] as String),
      Text(data['description'] as String), const SizedBox(height: 12),
      Text('${data['estimated_weeks']} suggested weeks · ${lessons.length} lessons · Self-paced'),
      if (_offline) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Offline copy · Refresh when connected', style: TextStyle(color: _gold))),
      const SizedBox(height: 14), LinearProgressIndicator(value: count / lessons.length),
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('$count / ${lessons.length} lessons completed · Study progress only')),
      for (final stage in _records(data['stages'])) ...[
        _heading(stage['title'] as String), Text(stage['description'] as String), const SizedBox(height: 12),
        for (final module in _records(data['modules']).where((m) => m['stage_id'] == stage['id'])) _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Week ${module['week']} · ${module['title']}', style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          for (final lesson in lessons.where((l) => (module['lesson_ids'] as List).contains(l['id']))) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_done.contains(lesson['id']) ? Icons.check_circle : Icons.circle_outlined, color: _gold),
            title: Text(lesson['title'] as String), subtitle: Text('${lesson['estimated_minutes']} minutes · Read, reflect, apply'),
            trailing: const Icon(Icons.chevron_right), onTap: () => _lesson(lesson),
          ),
          Text('Optional reading: ${_records(data['books']).where((b) => (module['book_ids'] as List).contains(b['id'])).map((b) => b['title']).join('; ')}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ])),
      ],
    ]);
  }

  Future<void> _lesson(Record lesson) async {
    final id = lesson['id'] as String;
    final completed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _LessonPage(
      lesson: lesson,
      sources: _records(_data!['sources']).where((s) => (lesson['source_ids'] as List).contains(s['id'])).toList(),
      completed: _done.contains(id),
      onToggle: () => _persist(_doneKey, _done.contains(id) ? (_done.toSet()..remove(id)) : (_done.toSet()..add(id))),
    )));
    if (completed != null && mounted) setState(() {});
  }

  Widget _books() => ListView(padding: const EdgeInsets.all(16), children: [
    _heading('Reading companions'),
    const Text('Read available complete editions below. Language, format and edition scope are shown for every file. Other translations remain external references. Advanced texts are for guided study.'), const SizedBox(height: 16),
    for (final book in _records(_data!['books'])) _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(book['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: _gold))),
        IconButton(tooltip: _saved.contains(book['id']) ? 'Remove saved book' : 'Save book', icon: Icon(_saved.contains(book['id']) ? Icons.bookmark : Icons.bookmark_border), onPressed: () => _persist(_savedKey, _saved.contains(book['id']) ? (_saved.toSet()..remove(book['id'])) : (_saved.toSet()..add(book['id'] as String))))]),
      Text('${book['author']} · ${book['level']}'), const SizedBox(height: 8),
      Text(book['description'] as String), const SizedBox(height: 8), Text(book['reading_guidance'] as String, style: const TextStyle(color: Colors.white60)),
      TextButton.icon(onPressed: () => _openLink(context, book['url'] as String), icon: const Icon(Icons.open_in_new), label: Text(book['access_type'] == 'publisher' ? 'View publisher' : 'Open reference')),
      for (final edition in _records(book['editions'] ?? [])) Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${edition['language']} · ${edition['format']}', style: const TextStyle(color: _gold, fontSize: 12)),
          Text(edition['edition_note'] as String, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          TextButton.icon(
            icon: Icon(edition['format'] == 'txt' ? Icons.menu_book : Icons.open_in_new),
            label: Text(edition['format'] == 'txt' ? 'Read complete edition' : edition['format'] == 'pdf' ? 'Open complete scan (PDF)' : edition['format'] == 'hosted_reader' ? 'Open hosted edition' : 'Open full HTML text'),
            onPressed: () {
              if (edition['format'] == 'txt') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => TasawwufBookReader(title: book['title'] as String, edition: edition)));
              } else {
                _openLink(context, edition['url'] as String);
              }
            },
          ),
        ]),
      ),
    ])),
  ]);

  Widget _glossary() => ListView(padding: const EdgeInsets.all(16), children: [
    _heading('Key terms'),
    for (final item in _records(_data!['glossary'])) _card(ListTile(contentPadding: EdgeInsets.zero, title: Text(item['term'] as String, style: const TextStyle(color: _gold)), subtitle: Text(item['definition'] as String))),
  ]);

  Widget _guide() => ListView(padding: const EdgeInsets.all(16), children: [
    _heading('How to use this path'),
    for (final text in _data!['weekly_plan'] as List) ListTile(leading: const Icon(Icons.check, color: _gold), title: Text(text as String)),
    _heading('Learning outcomes'),
    for (final text in _data!['learning_outcomes'] as List) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('• $text')),
    _heading('Choosing a teacher'),
    for (final text in _data!['teacher_guidance'] as List) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('• $text')),
    _heading('Questions & answers'),
    for (final faq in _records(_data!['faqs'])) _card(ExpansionTile(title: Text(faq['question'] as String), children: [Padding(padding: const EdgeInsets.all(12), child: Text(faq['answer'] as String))])),
    _heading('Content status'), Text(_data!['review_note'] as String),
    _heading('Primary references'),
    for (final source in _records(_data!['sources'])) ListTile(title: Text(source['label'] as String), trailing: const Icon(Icons.open_in_new), onTap: () => _openLink(context, source['url'] as String)),
    _heading('Your data'), Text((_data!['privacy'] as Map)['storage'] as String),
    const SizedBox(height: 8), const Text('No journal text is collected. Local preferences are not encrypted and are not a backup. The book reader also caches downloaded text and saves approximate reading position and text size.'),
  ]);
}

class _LessonPage extends StatefulWidget {
  const _LessonPage({required this.lesson, required this.sources, required this.completed, required this.onToggle});
  final Record lesson;
  final List<Record> sources;
  final bool completed;
  final Future<bool> Function() onToggle;
  @override
  State<_LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<_LessonPage> {
  int? _selected;
  bool _checked = false;
  bool _saving = false;
  late bool _completed;
  @override
  void initState() { super.initState(); _completed = widget.completed; }
  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final quiz = Map<String, dynamic>.from(l['checkpoint'] as Map);
    final options = (quiz['options'] as List).cast<String>();
    final passed = _checked && _selected == quiz['correct_index'];
    Widget heading(String s) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Text(s, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
    return Scaffold(appBar: AppBar(title: const Text('Lesson')), body: ListView(padding: const EdgeInsets.all(20), children: [
      Text(l['title'] as String, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16),
      Text(l['summary'] as String, style: const TextStyle(height: 1.7, fontSize: 16)),
      heading('Try it gently'), Text(l['practice'] as String),
      heading('Reflect privately'), Text(l['reflection'] as String),
      const SizedBox(height: 8), const Text('No response is collected or stored.', style: TextStyle(fontSize: 12)),
      heading('Primary references'),
      for (final s in widget.sources) TextButton.icon(onPressed: () => _openLink(context, s['url'] as String), icon: const Icon(Icons.open_in_new), label: Text(s['label'] as String)),
      heading('Knowledge check'), Text(quiz['question'] as String), const SizedBox(height: 10),
      for (int i = 0; i < options.length; i++) Padding(padding: const EdgeInsets.only(bottom: 6), child: OutlinedButton(
        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, backgroundColor: _selected == i ? Theme.of(context).colorScheme.primary.withAlpha(35) : null),
        onPressed: () => setState(() { _selected = i; _checked = false; }),
        child: Padding(padding: const EdgeInsets.all(10), child: Text('${_selected == i ? '●' : '○'}  ${options[i]}')),
      )),
      TextButton(onPressed: _selected == null ? null : () => setState(() => _checked = true), child: const Text('Check answer')),
      if (_checked) Text(passed ? 'Correct. ${quiz['explanation']}' : 'Try again. Revisit the lesson and its references.'),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: _saving || (!_completed && !passed) ? null : () async {
        setState(() => _saving = true);
        final success = await widget.onToggle();
        if (!mounted) return;
        if (success) { Navigator.pop(context, true); }
        else { setState(() => _saving = false); }
      }, child: Text(_saving ? 'Saving…' : _completed ? 'Mark incomplete' : 'Complete lesson')),
      const SizedBox(height: 12), const Text('Completion records learning activity, not spiritual attainment.', style: TextStyle(fontSize: 12)),
    ]));
  }
}
