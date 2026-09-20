import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/config/hive_setup.dart';
import '../../../core/utils/encryption_helper.dart';
import '../models/syllabus_model.dart';
import '../../../core/services/backend_api.dart';


class SyllabusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. Fetch Syllabi List from Firestore ---
  Future<List<SyllabusModel>> fetchSyllabi(String examType) async {
    try {
      final snapshot = await _firestore
          .collection('syllabus')
          .where('examType', isEqualTo: examType.toLowerCase())
          .get();

      return snapshot.docs.map((doc) => SyllabusModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint("Error fetching syllabi: $e");
      return [];
    }
  }

  // --- 2. Download and Cache (with progress) ---
  Stream<double> downloadAndCacheSyllabus(SyllabusModel syllabus) async* {
    // A. Define Local Paths
    final appDir = await getApplicationDocumentsDirectory();
    final encryptedFileName = '${syllabus.id}.enc.pdf';
    final destinationPath = '${appDir.path}/syllabus/$encryptedFileName';
    
    // Create directory if it doesn't exist
    final directory = Directory('${appDir.path}/syllabus');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // B. Download from public storage, reporting progress as it arrives.
    final url = (syllabus.storagePath.startsWith('http'))
        ? syllabus.storagePath
        : BackendApi.publicFileUrl(syllabus.storagePath);
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode}).');
      }
      final total = response.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream) {
        builder.add(chunk);
        received += chunk.length;
        yield total > 0 ? received / total : 0.0;
      }

      // C. Encrypt locally and record it in Hive.
      final Uint8List plainBytes = builder.takeBytes();
      await EncryptionHelper.encryptAndSave(plainBytes, destinationPath);

      final box = Hive.box<SyllabusModel>(HiveSetup.syllabusBoxName);
      syllabus.localEncryptedPath = destinationPath;
      syllabus.isDownloaded = true;
      await box.put(syllabus.id, syllabus);
      yield 1.0;
    } finally {
      client.close();
    }
  }
}
