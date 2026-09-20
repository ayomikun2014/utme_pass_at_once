import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/config/hive_setup.dart';
import '../models/syllabus_model.dart';
import '../services/syllabus_service.dart';

class SyllabusProvider extends ChangeNotifier {
  final SyllabusService _syllabusService = SyllabusService();
  
  List<SyllabusModel> _syllabi = [];
  bool _isLoading = false;
  
  // A Map to track progress per syllabus ID (id -> progress 0.0 to 1.0)
  final Map<String, double> _downloadingProgress = {}; 

  List<SyllabusModel> get syllabi => _syllabi;
  bool get isLoading => _isLoading;

  // Helper to check progress in UI
  double? getProgressOf(String id) => _downloadingProgress[id];

  // --- 1. Fetch Syllabi ---
  Future<void> fetchSyllabi(String examType) async {
    _isLoading = true;
    notifyListeners();
    
    // Check network bounds
    final networkItems = await _syllabusService.fetchSyllabi(examType);
    
    // Blend with locally downloaded Hive ones so we know which are already down
    final box = Hive.box<SyllabusModel>(HiveSetup.syllabusBoxName);
    
    _syllabi = networkItems.map((networkSyllabus) {
      if (box.containsKey(networkSyllabus.id)) {
          final local = box.get(networkSyllabus.id)!;
          networkSyllabus.isDownloaded = local.isDownloaded;
          networkSyllabus.localEncryptedPath = local.localEncryptedPath;
      }
      return networkSyllabus;
    }).toList();
    
    _isLoading = false;
    notifyListeners();
  }

  // --- 1.5 Refresh ---
  // New files are registered by the admin panel's syllabus sync; the app just
  // reloads the list.
  Future<void> syncFiles(String examType) async {
    _isLoading = true;
    notifyListeners();
    await fetchSyllabi(examType);
  }

  // --- 2. Start Download (Per Syllabus) ---
  Future<void> startDownload(SyllabusModel syllabus, {VoidCallback? onComplete}) async {
    // Do nothing if already downloading this syllabus
    if (_downloadingProgress.containsKey(syllabus.id)) return;
    
    // Initialize progress at 0
    _downloadingProgress[syllabus.id] = 0.0;
    notifyListeners();

    // Listen to the download stream from the Service
    _syllabusService.downloadAndCacheSyllabus(syllabus).listen(
      (progress) {
        // Update the Map with current progress (0.0 - 1.0)
        _downloadingProgress[syllabus.id] = progress;
        notifyListeners(); // UI updates with percentage
      },
      onDone: () {
        // Remove from downloading map upon completion
        _downloadingProgress.remove(syllabus.id);
        syllabus.isDownloaded = true;
        notifyListeners();
        if (onComplete != null) {
          onComplete();
        }
      },
      onError: (e) {
        debugPrint("Download error: $e");
        _downloadingProgress.remove(syllabus.id);
        notifyListeners();
      }
    );
  }
}
