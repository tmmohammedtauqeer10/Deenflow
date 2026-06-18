import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_player_screen.dart';

// pubspec.yaml dependencies needed:
//   just_audio: ^0.9.40
//   http: ^1.2.0
//   shared_preferences: ^2.2.3
//
// Raw GitHub "API" that feeds this screen:
//   https://raw.githubusercontent.com/tmmohammedtauqeer10/Deenflow/main/audio_api.json

// ---- Shared palette (matches SmartReaderScreen) ----
const _bg = Color(0xFF0B132B);
const _surface = Color(0xFF152243);
const _gold = Color(0xFFD4AF37);

const String _audioApiUrl =
    'https://raw.githubusercontent.com/tmmohammedtauqeer10/Deenflow/main/audio_api.json';

/// App-wide language for the audio section. 'en' or 'ur'.
class AudioLang {
  static const prefKey = 'audio_lang';
  static String current = 'en';

  static bool get isUrdu => current == 'ur';

  /// Reads a bilingual `{ "en": ..., "ur": ... }` field, falling back to
  /// whichever side is present.
  static String pick(dynamic field) {
    if (field is Map) {
      final v = field[current] ?? field['en'] ?? field['ur'];
      return (v ?? '').toString();
    }
    return (field ?? '').toString();
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    current = prefs.getString(prefKey) ?? 'en';
  }

  static Future<void> set(String lang) async {
    current = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, lang);
  }
}

class AudioSeriesScreen extends StatefulWidget {
  const AudioSeriesScreen({Key? key}) : super(key: key);

  @override
  State<AudioSeriesScreen> createState() => _AudioSeriesScreenState();
}

class _AudioSeriesScreenState extends State<AudioSeriesScreen> {
  bool _isLoading = true;
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await AudioLang.load();
    await _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    List<dynamic> cats = [];
    try {
      final res = await http.get(Uri.parse(_audioApiUrl));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        cats = (data['categories'] as List?) ?? [];
      }
      // Any non-200 (e.g. catalog not published yet -> 404) just leaves
      // cats empty, which renders the friendly "coming soon" view.
    } catch (_) {
      // Network error / offline: also fall back to "coming soon".
      cats = [];
    }
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  void _toggleLang() async {
    await AudioLang.set(AudioLang.isUrdu ? 'en' : 'ur');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // Urdu is right-to-left.
      textDirection: AudioLang.isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(
            AudioLang.isUrdu ? 'آڈیو سلسلے' : 'Audio Series',
            style: const TextStyle(color: _gold),
          ),
          backgroundColor: _surface,
          iconTheme: const IconThemeData(color: _gold),
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _toggleLang,
              child: Text(
                AudioLang.isUrdu ? 'EN' : 'اردو',
                style: const TextStyle(
                    color: _gold, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }

    // Catalog not published yet (or unreachable) -> show clean "coming soon".
    if (_categories.isEmpty) {
      return _buildComingSoon();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _categories.length,
      itemBuilder: (context, i) => _buildCategory(_categories[i]),
    );
  }

  /// Friendly placeholder shown when the GitHub catalog has no content yet.
  /// Pull-to-refresh re-checks, so the real content appears once published.
  Widget _buildComingSoon() {
    final placeholders = AudioLang.isUrdu
        ? const ['نشید و نعت', 'لیکچرز و بیان', 'تفسیر', 'اذکار و دعا', 'پوڈکاسٹ']
        : const [
            'Nasheed & Naat',
            'Lectures & Bayan',
            'Tafsir',
            'Azkar & Du\'a',
            'Podcasts',
          ];
    return RefreshIndicator(
      color: _gold,
      backgroundColor: _surface,
      onRefresh: _loadCatalog,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.library_music_outlined, color: _gold, size: 48),
          const SizedBox(height: 12),
          Text(
            AudioLang.isUrdu ? 'جلد آرہا ہے' : 'Coming soon',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _gold, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            AudioLang.isUrdu
                ? 'نئے آڈیو سلسلے تیار کیے جا رہے ہیں۔'
                : 'New audio series are on the way.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ...placeholders.map(_buildSoonCard),
        ],
      ),
    );
  }

  Widget _buildSoonCard(String title) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.headphones, color: Colors.white30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                AudioLang.isUrdu ? 'جلد' : 'Soon',
                style: const TextStyle(
                    color: _gold, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(dynamic cat) {
    final series = (cat['series'] as List?) ?? [];
    final color = _hex(cat['color'], const Color(0xFF6b46c1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AudioLang.pick(cat['category_name']),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        ...series.map((s) => _buildSeriesCard(s, color)),
      ],
    );
  }

  Widget _buildSeriesCard(dynamic s, Color accent) {
    final episodes = (s['episodes'] as List?) ?? [];
    final coverColor = _hex(s['cover_color'], accent);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AudioPlayerScreen(series: s),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 64,
                  height: 64,
                  color: coverColor,
                  child: _coverImage(s['cover_url'], coverColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AudioLang.pick(s['title']),
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AudioLang.pick(s['narrator']),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _pill(AudioLang.pick(s['badge']), accent),
                        const SizedBox(width: 6),
                        _pill(
                          AudioLang.isUrdu
                              ? '${episodes.length} اقساط'
                              : '${episodes.length} episodes',
                          Colors.white24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill, color: _gold, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverImage(dynamic url, Color fallback) {
    final u = (url ?? '').toString();
    if (u.isEmpty) return Icon(Icons.headphones, color: Colors.white.withOpacity(0.8));
    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.headphones, color: Colors.white.withOpacity(0.8)),
    );
  }

  Widget _pill(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }

  static Color _hex(dynamic value, Color fallback) {
    try {
      final s = (value ?? '').toString().replaceAll('#', '');
      if (s.length == 6) return Color(int.parse('FF$s', radix: 16));
    } catch (_) {}
    return fallback;
  }
}
