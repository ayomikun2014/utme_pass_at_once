import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../../../../core/constants/app_colors.dart';
import 'eclassroom_pdf_viewer.dart';
import '../../../../core/services/network_service.dart';

class DryPdfButton extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const DryPdfButton({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<DryPdfButton> createState() => _DryPdfButtonState();
}

class _DryPdfButtonState extends State<DryPdfButton> {
  bool _isLocal = false;
  String? _localPath;
  bool _isDownloading = false;
  double _downloadProgress = 0.0; // 0.0 to 1.0
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<String> _getLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final bytes = utf8.encode(widget.pdfUrl);
    final hash = sha256.convert(bytes).toString();
    return '${directory.path}/pdf_cache_$hash.pdf';
  }

  Future<void> _checkCacheStatus() async {
    if (widget.pdfUrl.isEmpty) return;
    try {
      final path = await _getLocalPath();
      final file = File(path);
      if (await file.exists() && await file.length() > 0) {
        if (mounted) {
          setState(() {
            _isLocal = true;
            _localPath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking cache status: $e');
    }
  }

  Future<void> _startDownload() async {
    if (!NetworkService.instance.isOnline) {
      NetworkService.instance.showNoInternetHelper(context);
      return;
    }

    if (widget.pdfUrl.isEmpty) {
      CustomToast.show(context, 'No PDF URL available.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.pdfUrl));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final path = await _getLocalPath();
      final file = File(path);
      final sink = file.openWrite();

      int bytesReceived = 0;

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          bytesReceived += chunk.length;
          if (contentLength > 0 && mounted) {
            setState(() {
              _downloadProgress = bytesReceived / contentLength;
            });
          }
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _isLocal = true;
              _localPath = path;
            });
            // Automatically open PDF after download completes
            _openPdf();
          }
        },
        onError: (error) async {
          await sink.close();
          if (await file.exists()) {
            await file.delete();
          }
          throw error;
        },
        cancelOnError: true,
      ).asFuture();
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        CustomToast.show(context, 'Download failed: $e');
      }
    }
  }

  void _openPdf() {
    if (_localPath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EClassroomPdfViewer(
          title: widget.title,
          filePath: _localPath!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloading) {
      final percentage = (_downloadProgress * 100).round();
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular progress indicator with percentage inside
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              'Downloading PDF ($percentage%)...',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLocal
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          foregroundColor: _isLocal ? Colors.white : AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isLocal ? _openPdf : _startDownload,
        icon: Icon(
          _isLocal ? Icons.visibility_rounded : Icons.picture_as_pdf_rounded,
          size: 18,
        ),
        label: Text(
          _isLocal ? 'View PDF Document' : 'Download & Open PDF',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
