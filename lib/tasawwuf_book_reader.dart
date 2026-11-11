import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Plain-text edition reader; each edition is cached after a successful fetch.
class TasawwufBookReader extends StatefulWidget {
  const TasawwufBookReader({super.key, required this.title, required this.edition});
  final String title;
  final Map<String, dynamic> edition;
  @override
  State<TasawwufBookReader> createState() => _TasawwufBookReaderState();
}

class _TasawwufBookReaderState extends State<TasawwufBookReader> {
  final _client = http.Client();
  final _scroll = ScrollController();
  SharedPreferences? _prefs;
  Timer? _timer;
  String? _text;
  String? _error;
  bool _loading = true;
  bool _offline = false;
  double _font = 20;
  double _fraction = 0;
  String get _key => 'tasawwuf_book_${widget.edition['id']}';
  String get _cacheKey => '${_key}_${widget.edition['sha256']}_text';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) return;
    _fraction = (_scroll.offset / _scroll.position.maxScrollExtent).clamp(0.0, 1.0).toDouble();
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), _savePosition);
  }

  Future<void> _savePosition() async {
    try { await _prefs?.setDouble('${_key}_position', _fraction); }
    catch (_) { /* Reading must remain available when preference writes fail. */ }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      try { _prefs = await SharedPreferences.getInstance(); } catch (_) { /* Read without storage. */ }
      String? text = _prefs?.getString(_cacheKey);
      bool offline = text != null;
      if (text == null) {
        try {
          final uri = Uri.parse(widget.edition['url'] as String);
          if (uri.scheme != 'https' || uri.host != 'raw.githubusercontent.com') {
            throw const FormatException('Unexpected book host');
          }
          final response = await _client.get(uri).timeout(const Duration(seconds: 25));
          if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
          if (response.bodyBytes.length != widget.edition['bytes']) {
            throw const FormatException('Unexpected edition size');
          }
          text = utf8.decode(response.bodyBytes);
          if (text.trim().isEmpty || text.trimLeft().startsWith('<!DOCTYPE html')) {
            throw const FormatException('Invalid book text');
          }
          try { await _prefs?.setString(_cacheKey, text); } catch (_) { /* Reading can continue uncached. */ }
        } catch (_) {
          // Optional asset path is the same relative path used in the repository.
          final filename = Uri.parse(widget.edition['url'] as String).pathSegments.last;
          text = await rootBundle.loadString('books/tasawwuf/$filename');
          offline = true;
        }
      }
      if (!mounted) return;
      setState(() {
        _text = text;
        _offline = offline;
        _font = (_prefs?.getDouble('${_key}_font') ?? 20).clamp(16.0, 32.0).toDouble();
        _fraction = (_prefs?.getDouble('${_key}_position') ?? 0).clamp(0.0, 1.0).toDouble();
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent * _fraction);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this edition. Connect and retry, or configure the bundled book assets.';
        _loading = false;
      });
    }
  }

  Future<void> _fontSize(double delta) async {
    setState(() { _font = (_font + delta).clamp(16.0, 32.0).toDouble(); });
    try { await _prefs?.setDouble('${_key}_font', _font); } catch (_) { /* Keep reading. */ }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _savePosition();
    _client.close();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = ['ar', 'ur', 'fa'].contains(widget.edition['language_code']);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(tooltip: 'Smaller text', onPressed: () => _fontSize(-2), icon: const Icon(Icons.text_decrease)),
        IconButton(tooltip: 'Larger text', onPressed: () => _fontSize(2), icon: const Icon(Icons.text_increase)),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Padding(
        padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!), const SizedBox(height: 12), ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ]),
      )) : Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Theme.of(context).colorScheme.surface,
          child: Text('${widget.edition['language']} · ${_offline ? 'Saved / bundled copy' : 'Full edition'}\n${widget.edition['edition_note']}', style: const TextStyle(fontSize: 12))),
        Expanded(child: Scrollbar(controller: _scroll, child: SingleChildScrollView(controller: _scroll, padding: const EdgeInsets.all(22),
          child: Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: SelectableText(_text!, style: TextStyle(fontSize: _font, height: 1.9)),
          ),
        ))),
      ]),
    );
  }
}
