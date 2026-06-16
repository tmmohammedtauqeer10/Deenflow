import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_series_screen.dart' show AudioLang;

// pubspec.yaml dependency needed:
//   just_audio: ^0.9.40

const _bg = Color(0xFF0B132B);
const _surface = Color(0xFF152243);
const _gold = Color(0xFFD4AF37);

/// Plays one series of episodes (streamed from Archive.org).
/// Remembers the listener's position per episode, like the PDF reader
/// remembers the last page.
class AudioPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> series;

  const AudioPlayerScreen({Key? key, required this.series}) : super(key: key);

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  int _currentIndex = -1;
  bool _preparing = false;
  String? _error;

  List<dynamic> get _episodes =>
      (widget.series['episodes'] as List?) ?? const [];

  @override
  void initState() {
    super.initState();
    // Save position roughly every few seconds while playing.
    _player.positionStream.listen((pos) {
      if (_currentIndex >= 0 && pos.inSeconds % 5 == 0) {
        _savePosition(_episodes[_currentIndex]['id'], pos.inMilliseconds);
      }
    });
  }

  @override
  void dispose() {
    if (_currentIndex >= 0) {
      _savePosition(_episodes[_currentIndex]['id'],
          _player.position.inMilliseconds);
    }
    _player.dispose();
    super.dispose();
  }

  String _posKey(String episodeId) => 'audio_pos_$episodeId';

  Future<void> _savePosition(String episodeId, int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_posKey(episodeId), ms);
  }

  Future<int> _loadPosition(String episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_posKey(episodeId)) ?? 0;
  }

  Future<void> _playEpisode(int index) async {
    final ep = _episodes[index];
    final url = (ep['audio_url'] ?? '').toString();
    setState(() {
      _currentIndex = index;
      _preparing = true;
      _error = null;
    });
    try {
      await _player.setUrl(url);
      final saved = await _loadPosition(ep['id'].toString());
      if (saved > 1000) {
        await _player.seek(Duration(milliseconds: saved));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AudioLang.isUrdu
                  ? 'وہیں سے جاری جہاں چھوڑا تھا'
                  : 'Resumed where you left off'),
              backgroundColor: _surface,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      await _player.play();
      if (mounted) setState(() => _preparing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _preparing = false;
          _error = e.toString();
        });
      }
    }
  }

  void _togglePlay() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AudioLang.isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(
            AudioLang.pick(widget.series['title']),
            style: const TextStyle(color: _gold),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: _surface,
          iconTheme: const IconThemeData(color: _gold),
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(child: _buildEpisodeList()),
            _buildPlayerBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeList() {
    if (_episodes.isEmpty) {
      return Center(
        child: Text(
          AudioLang.isUrdu ? 'کوئی قسط موجود نہیں' : 'No episodes yet',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _episodes.length,
      itemBuilder: (context, i) {
        final ep = _episodes[i];
        final isCurrent = i == _currentIndex;
        return ListTile(
          leading: Icon(
            isCurrent && _player.playing
                ? Icons.equalizer
                : Icons.play_circle_outline,
            color: isCurrent ? _gold : Colors.white54,
          ),
          title: Text(
            AudioLang.pick(ep['title']),
            style: TextStyle(
              color: isCurrent ? _gold : Colors.white,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () => _playEpisode(i),
        );
      },
    );
  }

  Widget _buildPlayerBar() {
    if (_currentIndex < 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: _surface,
        child: Text(
          AudioLang.isUrdu
              ? 'سننے کے لیے کوئی قسط منتخب کریں'
              : 'Select an episode to listen',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AudioLang.isUrdu
                    ? 'آڈیو چلانے میں مسئلہ ہوا'
                    : 'Could not play this audio',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          // Seek bar driven by position/duration streams.
          StreamBuilder<Duration?>(
            stream: _player.durationStream,
            builder: (context, durSnap) {
              final duration = durSnap.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, posSnap) {
                  var position = posSnap.data ?? Duration.zero;
                  if (position > duration) position = duration;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _gold,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: _gold,
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          min: 0,
                          max: duration.inMilliseconds.toDouble().clamp(
                              1, double.infinity),
                          value: position.inMilliseconds
                              .toDouble()
                              .clamp(0, duration.inMilliseconds.toDouble()),
                          onChanged: (v) =>
                              _player.seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                          Text(_fmt(duration),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () => _player.seek(
                    _player.position - const Duration(seconds: 10)),
              ),
              const SizedBox(width: 8),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snap) {
                  final playing = snap.data?.playing ?? false;
                  final processing = snap.data?.processingState;
                  if (_preparing ||
                      processing == ProcessingState.loading ||
                      processing == ProcessingState.buffering) {
                    return const SizedBox(
                      width: 56,
                      height: 56,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(color: _gold),
                      ),
                    );
                  }
                  return IconButton(
                    iconSize: 56,
                    icon: Icon(
                      playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: _gold,
                    ),
                    onPressed: _togglePlay,
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.forward_30, color: Colors.white),
                onPressed: () => _player.seek(
                    _player.position + const Duration(seconds: 30)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
