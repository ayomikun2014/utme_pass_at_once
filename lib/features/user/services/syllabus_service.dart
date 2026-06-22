import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/config/hive_setup.dart';
import '../../../core/utils/encryption_helper.dart';
import '../models/syllabus_model.dart';


class SyllabusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  // --- 1.5. Auto-Sync Storage -> Firestore ---
// --- 1.5. Auto-Sync Storage -> Firestore ---
  Future<void> syncSyllabusFromStorage(String examType) async {
    try {
      final storageRef = _storage.ref('syllabus/${examType.toLowerCase()}');
      final ListResult result = await storageRef.listAll();

      for (var ref in result.items) {
        // Skip non-PDFs if any
        if (!ref.name.toLowerCase().endsWith('.pdf')) continue;

        // Check if already in Firestore
        final existing = await _firestore
            .collection('syllabus')
            .where('storagePath', isEqualTo: ref.fullPath)
            .limit(1)
            .get();

        if (existing.docs.isEmpty) {
          // --- UPGRADED BULLETPROOF NAMING LOGIC ---
          // This handles spaces, underscores, dashes, and accidental double spaces perfectly!
          String name = ref.name
              .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '') // Remove .pdf
              .replaceAll('_', ' ') // Convert underscores to spaces
              .replaceAll('-', ' ') // Convert dashes to spaces
              .replaceAll(RegExp(r'\s+'), ' ') // Fix accidental double spaces
              .trim() // Remove leading/trailing spaces
              .split(' ')
              .map((word) {
            if (word.isEmpty) return '';
            // Capitalize the first letter of each word
            return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
          })
              .join(' ');

          await _firestore.collection('syllabus').add({
            'name': name,
            'examType': examType.toLowerCase(),
            'storagePath': ref.fullPath,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint("Synced new syllabus: $name");
        }
      }
    } catch (e) {
      debugPrint("Error syncing storage to firestore: $e");
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

    // B. Start Firebase Storage Download
    final ref = _storage.ref(syllabus.storagePath);
    final tempFilePath = '${appDir.path}/temp_download_${syllabus.id}.pdf';
    final tempFile = File(tempFilePath);
    final DownloadTask task = ref.writeToFile(tempFile);
    
    // C. Monitor Progress (Firebase Task Snapshot events)
    await for (TaskSnapshot snapshot in task.snapshotEvents) {
      // Calculate percentage (0.0 to 1.0)
      double progress = snapshot.totalBytes > 0 
          ? snapshot.bytesTransferred / snapshot.totalBytes 
          : 0.0;
      
      yield progress; // Send the percentage back to the provider

      // D. On Success: Encrypt and Update Hive
      if (snapshot.state == TaskState.success) {
        // 1. Get the raw bytes from temporary file
        final Uint8List plainBytes = await tempFile.readAsBytes();

        // 2. Encrypt locally
        await EncryptionHelper.encryptAndSave(plainBytes, destinationPath);
        
        // 3. Delete temporary file
        if (await tempFile.exists()) {
            await tempFile.delete();
        }

        // 4. Update the Syllabus Model status
        final box = Hive.box<SyllabusModel>(HiveSetup.syllabusBoxName);
        syllabus.localEncryptedPath = destinationPath;
        syllabus.isDownloaded = true;
        await box.put(syllabus.id, syllabus); // Update Hive Box
      }
    }
  }
}
