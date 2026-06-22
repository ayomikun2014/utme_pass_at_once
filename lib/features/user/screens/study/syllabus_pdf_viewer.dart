import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/utils/encryption_helper.dart';
import '../../models/syllabus_model.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';

class SyllabusPdfViewer extends StatefulWidget {
  final SyllabusModel syllabus;
  const SyllabusPdfViewer({super.key, required this.syllabus});

  @override
  State<SyllabusPdfViewer> createState() => _SyllabusPdfViewerState();
}

class _SyllabusPdfViewerState extends State<SyllabusPdfViewer> {
  String? _tempPath;
  bool _isLoading = true;
  String _errorMessage = '';
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _decryptAndPrepare();
  }

  Future<void> _decryptAndPrepare() async {
    try {
      // Decode the protected local file
      final bytes = await EncryptionHelper.readAndDecrypt(widget.syllabus.localEncryptedPath);
      if (bytes.isEmpty) {
        setState(() {
          _errorMessage = "Could not decrypt syllabus. Please delete and re-download.";
          _isLoading = false;
        });
        return;
      }

      // Save to temporary memory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${widget.syllabus.id}_temp.pdf');
      await tempFile.writeAsBytes(bytes);

      setState(() {
        _tempPath = tempFile.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error opening syllabus: $e";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // SECURITY: Delete temp file immediately when leaving the screen
    if (_tempPath != null) {
      final file = File(_tempPath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Beautiful dark background for reading
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.syllabus.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CustomLoader())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      )
          : PDFView(
        filePath: _tempPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        onRender: (pages) {
          setState(() {
            _totalPages = pages!;
          });
        },
        onPageChanged: (page, total) {
          setState(() {
            _currentPage = page!;
          });
        },
        onError: (error) {
          debugPrint('PDF Error: $error');
        },
        onPageError: (page, error) {
          debugPrint('$page: $error');
        },
      ),
    );
  }
}