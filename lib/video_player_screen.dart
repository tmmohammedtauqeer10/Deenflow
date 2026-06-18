import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'audio_series_screen.dart' show AudioLang;

// pubspec.yaml dependencies needed:
//   video_player: ^2.8.6
//   chewie: ^1.8.1

const _bg = Color(0xFF0B132B);
const _surface = Color(0xFF152243);
const _gold = Color(0xFFD4AF37);

/// Plays one video series (Islamic speeches) streamed from Archive.org.
class VideoPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> series;

  const VideoPlayerScreen({Key? key, required this.series}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  int _currentIndex = -1;
  bool _preparing = false;
  String? _error;

  List<dynamic> get _episodes =>
      (widget.series['episodes'] as List?) ?? const [];

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  Future<void> _playEpisode(int index) async {
    final ep = _episodes[index];
    final url = (ep['video_url'] ?? '').toString();

    setState(() {
      _currentIndex = index;
      _preparing = true;
      _error = null;
    });
    _disposeControllers();

    try {
      final vc = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController = vc;
      await vc.initialize();
      _chewieController = ChewieController(
        videoPlayerController: vc,
        autoPlay: true,
        looping: false,
        aspectRatio: vc.value.aspectRatio == 0 ? 16 / 9 : vc.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: _gold,
          handleColor: _gold,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
      );
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
            _buildPlayerArea(),
            Expanded(child: _buildEpisodeList()),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerArea() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: _buildPlayerContent(),
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            AudioLang.isUrdu
                ? 'ویڈیو چلانے میں مسئلہ ہوا'
                : 'Could not play this video',
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_preparing) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }
    // Nothing selected yet
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_display, color: Colors.white24, size: 56),
          const SizedBox(height: 8),
          Text(
            AudioLang.isUrdu
                ? 'دیکھنے کے لیے کوئی ویڈیو منتخب کریں'
                : 'Select a video to watch',
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeList() {
    if (_episodes.isEmpty) {
      return Center(
        child: Text(
          AudioLang.isUrdu ? 'کوئی ویڈیو موجود نہیں' : 'No videos yet',
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
            isCurrent ? Icons.play_arrow : Icons.ondemand_video,
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
}
