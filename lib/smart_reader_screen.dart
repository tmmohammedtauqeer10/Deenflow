import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// pubspec.yaml dependencies needed:
//   syncfusion_flutter_pdfviewer: ^24.2.7
//   shared_preferences: ^2.2.3
//   path_provider: ^2.1.2
//   http: ^1.2.0

class SmartReaderScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String pdfUrl;

  const SmartReaderScreen({
    Key? key,
    required this.bookId,
    required this.bookTitle,
    required this.pdfUrl,
  }) : super(key: key);

  @override
  State<SmartReaderScreen> createState() => _SmartReaderScreenState();
}

class _SmartReaderScreenState extends State<SmartReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  String? _localFilePath;
  bool _isLoading = true;
  double _downloadProgress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  /// Downloads the PDF (if not already cached) and stores it locally.
  Future<void> _loadPdf() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.bookId}.pdf');

      if (!await file.exists()) {
        // Stream download so we can show progress
        final request = http.Request('GET', Uri.parse(widget.pdfUrl));
        final response = await http.Client().send(request);

        if (response.statusCode != 200) {
          throw Exception('Download failed (HTTP ${response.statusCode})');
        }

        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        final bytes = <int>[];

        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && mounted) {
            setState(() {
              _downloadProgress = receivedBytes / totalBytes;
            });
          }
        }

        await file.writeAsBytes(bytes);
      }

      if (mounted) {
        setState(() {
          _localFilePath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Fetches the last read page from local storage.
  Future<void> _loadSavedPage() async {
    final prefs = await SharedPreferences.getInstance();
    final int? savedPage = prefs.getInt('bookmark_${widget.bookId}');

    if (savedPage != null && savedPage > 1) {
      _pdfViewerController.jumpToPage(savedPage);

      // Safe: widget is guaranteed mounted after onDocumentLoaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resumed from page $savedPage'),
              backgroundColor: const Color(0xFF152243),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  /// Silently saves the current page number whenever the user turns a page.
  Future<void> _saveCurrentPage(int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bookmark_${widget.bookId}', pageNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        title: Text(
          widget.bookTitle,
          style: const TextStyle(color: Color(0xFFD4AF37)),
        ),
        backgroundColor: const Color(0xFF152243),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Error state
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                'Could not load book',
                style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37)),
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                    _downloadProgress = 0;
                  });
                  _loadPdf();
                },
                child: const Text('Retry',
                    style: TextStyle(color: Color(0xFF0B132B))),
              ),
            ],
          ),
        ),
      );
    }

    // Loading / downloading state
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              color: const Color(0xFFD4AF37),
            ),
            const SizedBox(height: 16),
            Text(
              _downloadProgress > 0
                  ? 'Downloading… ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                  : 'Opening book…',
              style: const TextStyle(color: Color(0xFFD4AF37)),
            ),
          ],
        ),
      );
    }

    // PDF viewer (offline, from local file)
    return SfPdfViewer.file(
      File(_localFilePath!),
      controller: _pdfViewerController,
      canShowScrollHead: false,
      pageLayoutMode: PdfPageLayoutMode.single,
      onDocumentLoaded: (_) => _loadSavedPage(),
      onPageChanged: (details) => _saveCurrentPage(details.newPageNumber),
      onDocumentLoadFailed: (details) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to render PDF: ${details.error}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        });
      },
    );
  }
}
