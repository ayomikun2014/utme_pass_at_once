import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../../../core/utils/custom_loader.dart';

class EClassroomPdfViewer extends StatefulWidget {
  final String title;
  final String filePath;

  const EClassroomPdfViewer({
    super.key,
    required this.title,
    required this.filePath,
  });

  @override
  State<EClassroomPdfViewer> createState() => _EClassroomPdfViewerState();
}

class _EClassroomPdfViewerState extends State<EClassroomPdfViewer> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Premium dark theme for reading
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
              widget.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            onRender: (pages) {
              setState(() {
                _totalPages = pages ?? 0;
                _ready = true;
              });
            },
            onPageChanged: (page, total) {
              setState(() {
                _currentPage = page ?? 0;
              });
            },
            onError: (error) {
              debugPrint('PDF view error: $error');
            },
            onPageError: (page, error) {
              debugPrint('PDF view page error on page $page: $error');
            },
          ),
          if (!_ready)
            const Center(
              child: CustomLoader(),
            ),
        ],
      ),
    );
  }
}
