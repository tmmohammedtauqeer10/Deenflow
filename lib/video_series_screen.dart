import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'audio_series_screen.dart' show AudioLang;
import 'video_player_screen.dart';

// pubspec.yaml dependencies needed:
//   video_player: ^2.8.6
//   chewie: ^1.8.1
//   http: ^1.2.0
//   shared_preferences: ^2.2.3
//
// Raw GitHub "API" that feeds this screen:
//   https://raw.githubusercontent.com/tmmohammedtauqeer10/Deenflow/main/video_api.json

const _bg = Color(0xFF0B132B);
const _surface = Color(0xFF152243);
const _gold = Color(0xFFD4AF37);

const String _videoApiUrl =
    'https://raw.githubusercontent.com/tmmohammedtauqeer10/Deenflow/main/video_api.json';

class VideoSeriesScreen extends StatefulWidget {
  const VideoSeriesScreen({Key? key}) : super(key: key);

  @override
  State<VideoSeriesScreen> createState() => _VideoSeriesScreenState();
}

class _VideoSeriesScreenState extends State<VideoSeriesScreen> {
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
      final res = await http.get(Uri.parse(_videoApiUrl));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        cats = (data['categories'] as List?) ?? [];
      }
      // Non-200 (e.g. catalog not published yet -> 404) -> "coming soon".
    } catch (_) {
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
      textDirection: AudioLang.isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(
            AudioLang.isUrdu ? 'ویڈیو سلسلے' : 'Video Series',
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

    // Catalog not published yet (or unreachable) -> clean "coming soon".
    if (_categories.isEmpty) {
      return _buildComingSoon();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _categories.length,
      itemBuilder: (context, i) => _buildCategory(_categories[i]),
    );
  }

  /// Friendly placeholder shown when the GitHub video catalog has no
  /// content yet. Pull-to-refresh re-checks once it is published.
  Widget _buildComingSoon() {
    final placeholders = AudioLang.isUrdu
        ? const ['اسلامی تقاریر (انگریزی)', 'اسلامی تقاریر (اردو)', 'تفسیر ویڈیو']
        : const [
            'Islamic Speeches (English)',
            'Islamic Speeches (Urdu)',
            'Tafsir Videos',
          ];
    return RefreshIndicator(
      color: _gold,
      backgroundColor: _surface,
      onRefresh: _loadCatalog,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.smart_display_outlined, color: _gold, size: 48),
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
                ? 'نئی اسلامی ویڈیوز تیار کی جا رہی ہیں۔'
                : 'New Islamic videos are on the way.',
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.white10,
              child: const Center(
                child: Icon(Icons.videocam_outlined,
                    color: Colors.white30, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    AudioLang.isUrdu ? 'جلد' : 'Soon',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(dynamic cat) {
    final series = (cat['series'] as List?) ?? [];
    final color = _hex(cat['color'], const Color(0xFF1a6b3c));
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VideoPlayerScreen(series: s)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 thumbnail with a play overlay
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumbnail(s['thumbnail'], accent),
                  Container(color: Colors.black.withOpacity(0.15)),
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 52),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
                    AudioLang.pick(s['speaker']),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _pill(AudioLang.pick(s['badge']), accent),
                      const SizedBox(width: 6),
                      _pill(
                        AudioLang.isUrdu
                            ? '${episodes.length} ویڈیوز'
                            : '${episodes.length} videos',
                        Colors.white24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(dynamic url, Color fallback) {
    final u = (url ?? '').toString();
    if (u.isEmpty) return Container(color: fallback);
    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: fallback,
        child: const Icon(Icons.videocam, color: Colors.white70, size: 40),
      ),
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
      child:
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
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
