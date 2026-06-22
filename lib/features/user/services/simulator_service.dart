import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/question_model.dart';
import '../models/question_bank_model.dart';
import '../../auth/models/user_model.dart';

class SimulatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _boxName = 'offline_questions';
  final String _historyBoxName = 'exam_history_local';

  final String _institutionsBoxName = 'offline_institutions';
  final String _subjectsBoxName = 'offline_subjects';
  final String _yearsBoxName = 'offline_years';

  // =========================================================================
  // HELPERS
  // =========================================================================



  String _getBaseInstitutionId(String id) {
    if (id.contains('_')) {
      return id.split('_')[0].toLowerCase().trim();
    }

    return id.toLowerCase().trim();
  }

  String _normalizeSubjectId(String subject) {
    return subject.toLowerCase().trim().replaceAll(' ', '_');
  }

  String _buildPackageKey({
    required String examType,
    required String institutionId,
    String? sectionId,
  }) {
    final normalized = examType.toLowerCase().trim();
    final baseId = _getBaseInstitutionId(institutionId);

    if (normalized == 'post_utme' &&
        sectionId != null &&
        sectionId.trim().isNotEmpty) {
      return '${normalized}_${baseId}_${sectionId.toLowerCase().trim()}';
    }

    return '${normalized}_$baseId';
  }

  String _buildQuestionCacheKey({
    required String examType,
    required String institutionId,
    required String year,
    required String subject,
  }) {
    final normalized = examType.toLowerCase().trim();
    final baseId = _getBaseInstitutionId(institutionId);
    final subjectId = _normalizeSubjectId(subject);

    return '${normalized}_${baseId}_${year}_$subjectId';
  }

  // =========================================================================
  // CACHE WRITE
  // =========================================================================

  Future<void> cacheInstitutions(
      String examType,
      List<InstitutionModel> institutions,
      ) async {
    final normalized = examType.toLowerCase().trim();
    final box = await Hive.openBox<String>(_institutionsBoxName);
    final jsonList = institutions.map((i) => i.toMap()).toList();

    await box.put(normalized, json.encode(jsonList));

    debugPrint(
      '📦 [CACHE] Saved ${institutions.length} institutions for $normalized',
    );
  }

  Future<void> cacheSubjects(
      String examType,
      String institutionId,
      List<SubjectModel> subjects, {
        String? sectionId,
      }) async {
    final key = _buildPackageKey(
      examType: examType,
      institutionId: institutionId,
      sectionId: sectionId,
    );

    final box = await Hive.openBox<String>(_subjectsBoxName);
    final jsonList = subjects.map((s) => s.toMap()).toList();

    await box.put(key, json.encode(jsonList));

    debugPrint('📦 [CACHE] Saved ${subjects.length} subjects for $key');
  }

  Future<void> cacheAvailableYears(
      String examType,
      String institutionId,
      String subject,
      List<String> years, {
        String? sectionId,
      }) async {
    final packageKey = _buildPackageKey(
      examType: examType,
      institutionId: institutionId,
      sectionId: sectionId,
    );

    final subjectId = _normalizeSubjectId(subject);
    final key = '${packageKey}_$subjectId';

    final box = await Hive.openBox<String>(_yearsBoxName);

    await box.put(key, json.encode(years));

    debugPrint('📦 [CACHE] Saved ${years.length} years for $key: $years');
  }

  // =========================================================================
  // CACHE READ
  // =========================================================================

  Future<List<InstitutionModel>> getCachedInstitutions(String examType) async {
    final normalized = examType.toLowerCase().trim();
    final box = await Hive.openBox<String>(_institutionsBoxName);
    final data = box.get(normalized);

    if (data == null) {
      debugPrint('🔧 [OFFLINE] No cached institutions for $normalized');
      return [];
    }

    final List<dynamic> decoded = json.decode(data);

    final institutions = decoded.map((item) {
      return InstitutionModel.fromFirestore(
        Map<String, dynamic>.from(item),
        item['id'] ?? '',
      );
    }).toList();

    debugPrint(
      '🔧 [OFFLINE] Loaded ${institutions.length} cached institutions for $normalized',
    );

    return institutions;
  }

  Future<List<SubjectModel>> getCachedSubjects(
      String examType,
      String institutionId, {
        String? sectionId,
      }) async {
    final key = _buildPackageKey(
      examType: examType,
      institutionId: institutionId,
      sectionId: sectionId,
    );

    final box = await Hive.openBox<String>(_subjectsBoxName);
    final data = box.get(key);

    if (data == null) {
      debugPrint('🔧 [OFFLINE] No cached subjects for $key');
      return [];
    }

    final List<dynamic> decoded = json.decode(data);

    final subjects = decoded.map((item) {
      return SubjectModel.fromFirestore(
        Map<String, dynamic>.from(item),
        item['id'] ?? '',
      );
    }).toList();

    debugPrint(
      '🔧 [OFFLINE] Loaded ${subjects.length} cached subjects for $key',
    );

    return subjects;
  }

  Future<List<String>?> getCachedAvailableYears(
      String examType,
      String institutionId,
      String subject, {
        String? sectionId,
      }) async {
    final packageKey = _buildPackageKey(
      examType: examType,
      institutionId: institutionId,
      sectionId: sectionId,
    );

    final subjectId = _normalizeSubjectId(subject);
    final key = '${packageKey}_$subjectId';

    final box = await Hive.openBox<String>(_yearsBoxName);
    final data = box.get(key);

    if (data == null) {
      debugPrint('🔧 [OFFLINE] No cached years for $key');
      return null;
    }

    final List<dynamic> decoded = json.decode(data);
    final years = decoded.map((y) => y.toString()).toList();

    debugPrint(
      '🔧 [OFFLINE] Loaded ${years.length} cached years for $key: $years',
    );

    return years;
  }

  Future<bool> hasLocalMetadata(
      String examType,
      String institutionId, {
        String? sectionId,
      }) async {
    final key = _buildPackageKey(
      examType: examType,
      institutionId: institutionId,
      sectionId: sectionId,
    );

    final box = await Hive.openBox<String>(_subjectsBoxName);
    final hasData = box.containsKey(key);

    debugPrint('🔧 [OFFLINE] hasLocalMetadata($key) = $hasData');

    return hasData;
  }

  Future<Map<String, Map<String, dynamic>>> getCachedInstitutionMapping(
      String examType,
      ) async {
    final institutions = await getCachedInstitutions(examType);

    final Map<String, Map<String, dynamic>> mapping = {};

    for (final inst in institutions) {
      mapping[inst.id.toLowerCase()] = {
        'name': inst.name,
        'logo': inst.logo,
      };
    }

    debugPrint(
      '🔧 [OFFLINE] getCachedInstitutionMapping: ${mapping.length} institutions',
    );

    return mapping;
  }

// =========================================================================
  // FULL ACTIVATION DOWNLOAD (DYNAMIC ARCHITECTURE)
  // =========================================================================

  Future<void> downloadAndCacheAllActivationData({
    required String examType,
    required String institutionId,
    // REMOVED: required List<String> subjects, (We fetch dynamically now)
    String? sectionId,
    required void Function(int current, int total) onProgress,
  }) async {
    final normalized = examType.toLowerCase().trim();
    final baseInstitutionId = _getBaseInstitutionId(institutionId);

    debugPrint(
      '⚡ [ACTIVATION] Starting dynamic data download for $normalized/$baseInstitutionId section=$sectionId',
    );

    int currentStep = 0;

    // Step 1: Institutions
    final institutions = await getAvailableInstitutions(normalized);
    await cacheInstitutions(normalized, institutions);
    currentStep++;

    // Step 2: Subjects metadata (DYNAMIC FETCH)
    final allSubjects = await getAvailableSubjects(
      normalized,
      baseInstitutionId,
    );

    final subjectsToCache = normalized == 'post_utme' &&
        sectionId != null &&
        sectionId.trim().isNotEmpty
        ? allSubjects.where((subjectModel) {
      final raw = subjectModel.toMap();
      final sectionIds = raw['sectionIds'];
      if (sectionIds is List) {
        return sectionIds
            .map((e) => e.toString().toLowerCase().trim())
            .contains(sectionId.toLowerCase().trim());
      }
      return false;
    }).toList()
        : allSubjects;

    await cacheSubjects(
      normalized,
      baseInstitutionId,
      subjectsToCache,
      sectionId: sectionId,
    );
    currentStep++;

    // EXTRACT dynamic subject list directly from Firestore data
    final dynamicSubjects = subjectsToCache.map((s) => s.id).toList();
    debugPrint('⚡ [ACTIVATION] Dynamically found subjects: $dynamicSubjects');

    // Step 3: Available years
    final Map<String, List<String>> allYearsMap = {};
    int totalYearDocs = 0;

    for (final subject in dynamicSubjects) {
      final years = await getAvailableYears(
        normalized,
        baseInstitutionId,
        subject,
      );

      allYearsMap[subject] = years;

      await cacheAvailableYears(
        normalized,
        baseInstitutionId,
        subject,
        years,
        sectionId: sectionId,
      );

      totalYearDocs += years.length;
      currentStep++;
    }

    final totalSteps = 2 + dynamicSubjects.length + totalYearDocs;
    onProgress(currentStep, totalSteps);

    debugPrint(
      '⚡ [ACTIVATION] Total question downloads needed: $totalYearDocs',
    );

    // Step 4: Questions
    for (final subject in dynamicSubjects) {
      final years = allYearsMap[subject] ?? [];

      for (final year in years) {
        // --- NEW: RESUME CAPABILITY ---
        // Before downloading, check if this specific year is already perfectly cached!
        final isAlreadyCached = await areQuestionsCached(
          examType: normalized,
          institutionId: baseInstitutionId,
          year: year,
          subject: subject,
        );

        if (isAlreadyCached) {
          debugPrint('⚡ [ACTIVATION] Skipping $subject/$year (Already cached)');
          currentStep++;
          onProgress(currentStep, totalSteps);
          continue; // Skip the download!
        }
        // ------------------------------

        debugPrint(
          '⚡ [ACTIVATION] Downloading questions: $subject/$year...',
        );

        try {
          await downloadAndCacheQuestions(
            examType: normalized,
            institutionId: baseInstitutionId,
            year: year,
            subject: subject,
          );
        } catch (e) {
          debugPrint(
            '⚡ [ACTIVATION] ⚠️ Failed to download $subject/$year: $e',
          );
          // If a download fails, you might want to throw the error up so the UI
          // knows the overall download did not complete successfully.
          rethrow;
        }

        currentStep++;
        onProgress(currentStep, totalSteps);
      }
    }
    debugPrint(
      '⚡ [ACTIVATION] ✅ Full activation download complete! ($currentStep/$totalSteps steps)',
    );
  }

  Future<bool> isActivatedPackageDownloaded({
    required String examType,
    required String institutionId,
    // REMOVED: required List<String> subjects,
    String? sectionId,
  }) async {
    final normalized = examType.toLowerCase().trim();
    final baseInstitutionId = _getBaseInstitutionId(institutionId);

    // 1. Check if we even have metadata for this package
    final hasMetadata = await hasLocalMetadata(
      normalized,
      baseInstitutionId,
      sectionId: sectionId,
    );

    if (!hasMetadata) return false;

    // 2. Fetch what subjects *should* be in this package based on cache
    final cachedSubjects = await getCachedSubjects(
        normalized,
        baseInstitutionId,
        sectionId: sectionId
    );

    if (cachedSubjects.isEmpty) return false;

    // 3. Verify every year for every dynamic subject is downloaded
    for (final subjectModel in cachedSubjects) {
      final subject = subjectModel.id;
      final years = await getCachedAvailableYears(
        normalized,
        baseInstitutionId,
        subject,
        sectionId: sectionId,
      );

      if (years == null) return false;

      for (final year in years) {
        final cached = await areQuestionsCached(
          examType: normalized,
          institutionId: baseInstitutionId,
          year: year,
          subject: subject,
        );

        if (!cached) return false;
      }
    }

    return true;
  }

// =========================================================================
  // SMART MERGE / UPDATES
  // =========================================================================

  Future<Map<String, dynamic>> checkForUpdates({
    required String examType,
    required String institutionId,
    String? sectionId,
  }) async {
    final normalized = examType.toLowerCase().trim();
    final baseInstitutionId = _getBaseInstitutionId(institutionId);

    int newSubjectsCount = 0;
    int newYearsCount = 0;
    int removedSubjectsCount = 0; // <--- NEW: Track deletions

    // 1. Fetch Latest Subjects from Firestore
    final allOnlineSubjects = await getAvailableSubjects(normalized, baseInstitutionId);
    final onlineSubjectsToCheck = normalized == 'post_utme' && sectionId != null && sectionId.trim().isNotEmpty
        ? allOnlineSubjects.where((s) {
      final raw = s.toMap();
      final sectionIds = raw['sectionIds'];
      return sectionIds is List && sectionIds.map((e) => e.toString().toLowerCase().trim()).contains(sectionId.toLowerCase().trim());
    }).toList()
        : allOnlineSubjects;

    // 2. Fetch Locally Cached Subjects
    final localSubjects = await getCachedSubjects(normalized, baseInstitutionId, sectionId: sectionId);
    final localSubjectIds = localSubjects.map((s) => s.id).toSet();

    final dynamicOnlineSubjects = onlineSubjectsToCheck.map((s) => s.id).toList();

    // --- NEW: Check for REMOVED subjects ---
    for (final localSub in localSubjectIds) {
      if (!dynamicOnlineSubjects.contains(localSub)) {
        removedSubjectsCount++;
      }
    }
    // ---------------------------------------

    // 3. Compare Subjects and Years (Additions)
    for (final subject in dynamicOnlineSubjects) {
      if (!localSubjectIds.contains(subject)) {
        newSubjectsCount++;
      }

      final onlineYears = await getAvailableYears(normalized, baseInstitutionId, subject);
      final localYears = await getCachedAvailableYears(normalized, baseInstitutionId, subject, sectionId: sectionId) ?? [];

      final localYearsSet = localYears.toSet();

      for (final year in onlineYears) {
        if (!localYearsSet.contains(year)) {
          newYearsCount++;
        } else {
          final isCached = await areQuestionsCached(
              examType: normalized,
              institutionId: baseInstitutionId,
              year: year,
              subject: subject
          );
          if (!isCached) {
            newYearsCount++;
          }
        }
      }
    }

    // Update the boolean to include removed subjects!
    final bool updatesAvailable = newSubjectsCount > 0 || newYearsCount > 0 || removedSubjectsCount > 0;

    String message = 'Your offline content is up to date.';
    if (updatesAvailable) {
      message = 'Updates found: ';
      if (newSubjectsCount > 0) message += '$newSubjectsCount new subjects. ';
      if (newYearsCount > 0) message += '$newYearsCount new years. ';
      if (removedSubjectsCount > 0) message += 'Syncing removed content. ';
    }

    return {
      'updatesAvailable': updatesAvailable,
      'newSubjects': newSubjectsCount,
      'newYears': newYearsCount,
      'message': message
    };
  }

  // =========================================================================
  // ONLINE FETCH
  // =========================================================================

  Future<List<InstitutionModel>> getAvailableInstitutions(
      String examType,
      ) async {
    try {
      final normalized = examType.toLowerCase().trim();

      final snapshot = await _firestore
          .collection('questionBank')
          .doc(normalized)
          .collection('institutions')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          return InstitutionModel.fromFirestore(doc.data(), doc.id);
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching institutions: $e');
      return [];
    }
  }

  Future<List<SubjectModel>> getAvailableSubjects(
      String examType,
      String institutionId,
      ) async {
    try {
      final normalized = examType.toLowerCase().trim();
      final baseInstitutionId = _getBaseInstitutionId(institutionId);

      final snapshot = await _firestore
          .collection('questionBank')
          .doc(normalized)
          .collection('institutions')
          .doc(baseInstitutionId)
          .collection('subjects')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          return SubjectModel.fromFirestore(doc.data(), doc.id);
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching subjects: $e');
      return [];
    }
  }

  Future<List<String>> getAvailableYears(
      String examType,
      String institutionId,
      String subject,
      ) async {
    try {
      final normalized = examType.toLowerCase().trim();
      final baseInstitutionId = _getBaseInstitutionId(institutionId);
      final subjectId = _normalizeSubjectId(subject);

      final path =
          'questionBank/$normalized/institutions/$baseInstitutionId/subjects/$subjectId';

      debugPrint('📅 getAvailableYears: Querying subject doc: $path');

      final doc = await _firestore
          .collection('questionBank')
          .doc(normalized)
          .collection('institutions')
          .doc(baseInstitutionId)
          .collection('subjects')
          .doc(subjectId)
          .get(const GetOptions(source: Source.serverAndCache));

      if (doc.exists) {
        final data = doc.data();

        if (data != null && data.containsKey('availableYears')) {
          final List<dynamic> rawYears =
              data['availableYears'] as List<dynamic>? ?? [];

          final years = rawYears.map((y) => y.toString()).toList();

          if (years.isNotEmpty) {
            years.sort((a, b) => b.compareTo(a));

            debugPrint('📅 getAvailableYears: Years for $subject: $years');

            return years;
          }
        }
      }

      debugPrint(
        '⚠️ getAvailableYears: No availableYears array found for $subject',
      );

      return [];
    } catch (e) {
      debugPrint('❌ getAvailableYears error for $subject: $e');
      return [];
    }
  }

  Future<List<QuestionModel>> fetchQuestionsOnline({
    required String examType,
    required String institutionId,
    required String subject,
    required String year,
  }) async {
    final normalized = examType.toLowerCase().trim();
    final baseInstitutionId = _getBaseInstitutionId(institutionId);
    final subjectId = _normalizeSubjectId(subject);

    final docRef = _firestore
        .collection('questionBank')
        .doc(normalized)
        .collection('institutions')
        .doc(baseInstitutionId)
        .collection('subjects')
        .doc(subjectId)
        .collection('years')
        .doc(year);

    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw Exception('No questions found for $subject $year.');
    }

    final yearData = docSnapshot.data() ?? {};
    final yearModel = YearModel.fromFirestore(yearData, year);

    if (yearModel.rawQuestions.isEmpty) {
      throw Exception('No questions found for $subject $year.');
    }

    return yearModel.rawQuestions.map((qMap) {
      return QuestionModel.fromJson(
        qMap,
        examType: normalized,
        institutionId: baseInstitutionId,
        subjectId: subjectId,
        year: int.tryParse(year) ?? 0,
      );
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> getInstitutionMapping(
      String examType,
      ) async {
    try {
      final normalized = examType.toLowerCase().trim();

      final snapshot = await _firestore
          .collection('questionBank')
          .doc(normalized)
          .collection('institutions')
          .get();

      final Map<String, Map<String, dynamic>> mapping = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        String? name;

        if (data.containsKey('name')) {
          name = data['name']?.toString();
        } else if (data.containsKey('Name')) {
          name = data['Name']?.toString();
        }

        mapping[doc.id.toLowerCase()] = {
          'name': name ?? doc.id.toUpperCase(),
          'logo': data['logo']?.toString(),
        };
      }

      return mapping;
    } catch (e) {
      debugPrint('Error fetching institution data: $e');
      return {};
    }
  }

  // =========================================================================
  // QUESTION CACHE
  // =========================================================================

  Future<bool> areQuestionsCached({
    required String examType,
    required String institutionId,
    required String year,
    required String subject,
  }) async {
    final cacheKey = _buildQuestionCacheKey(
      examType: examType,
      institutionId: institutionId,
      year: year,
      subject: subject,
    );

    final box = await Hive.openBox<String>(_boxName);

    if (box.containsKey(cacheKey)) {
      final existingData = box.get(cacheKey);

      if (existingData != null) {
        final List<dynamic> decodedList = json.decode(existingData);

        if (decodedList.isNotEmpty) return true;
      }
    }

    // --- FALLBACK FOR FREE PRE-DOWNLOADED QUESTIONS ---
    if (subject == 'aptitude') {
      final freeKey = 'free_aptitude_$year';
      if (box.containsKey(freeKey)) {
        final existingData = box.get(freeKey);
        if (existingData != null) {
          final List<dynamic> decodedList = json.decode(existingData);
          if (decodedList.isNotEmpty) return true;
        }
      }
    }

    return false;
  }

  Future<void> downloadAndCacheQuestions({
    required String examType,
    required String institutionId,
    required String year,
    required String subject,
  }) async {
    final normalized = examType.toLowerCase().trim();
    final baseInstitutionId = _getBaseInstitutionId(institutionId);
    final subjectId = _normalizeSubjectId(subject);

    final cacheKey = _buildQuestionCacheKey(
      examType: normalized,
      institutionId: baseInstitutionId,
      year: year,
      subject: subject,
    );

    final box = await Hive.openBox<String>(_boxName);

    if (box.containsKey(cacheKey)) {
      final existingData = box.get(cacheKey);

      if (existingData != null) {
        if (existingData.contains('TO_BE_UPLOADED')) {
          debugPrint(
            '🧹 Force re-downloading to replace stale placeholders...',
          );
        } else {
          final List<dynamic> decodedList = json.decode(existingData);

          if (decodedList.isNotEmpty) {
            debugPrint('✅ Questions already cached for $cacheKey');
            return;
          }
        }
      }
    }

    final docRef = _firestore
        .collection('questionBank')
        .doc(normalized)
        .collection('institutions')
        .doc(baseInstitutionId)
        .collection('subjects')
        .doc(subjectId)
        .collection('years')
        .doc(year);

    debugPrint('Fetching year document from: ${docRef.path}');

    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      debugPrint('WARNING: No year document found at path: ${docRef.path}');
      throw Exception('No questions found for this subject/year combination.');
    }

    final yearData = docSnapshot.data() ?? {};
    final yearModel = YearModel.fromFirestore(yearData, year);

    if (yearModel.rawQuestions.isEmpty) {
      debugPrint(
        'WARNING: Year document has empty questions array at: ${docRef.path}',
      );
      throw Exception('No questions found for this subject/year combination.');
    }

    debugPrint(
      'Found ${yearModel.rawQuestions.length} questions in year document at: ${docRef.path}',
    );

    final questions = yearModel.rawQuestions.map((qMap) {
      return QuestionModel.fromJson(
        qMap,
        examType: normalized,
        institutionId: baseInstitutionId,
        subjectId: subjectId,
        year: int.tryParse(year) ?? 0,
      );
    }).toList();

    if (yearModel.hasImage && !kIsWeb) {
      final List<Future<dynamic>> imageDownloads = [];
      const bucket = 'utme-pass-at-once-36340.firebasestorage.app';

      for (final q in questions) {
        void addDownloadTask(String? rawSrc) {
          if (rawSrc == null || rawSrc.isEmpty) return;

          String src = rawSrc;

          if (!rawSrc.startsWith('http') && !rawSrc.startsWith('assets/')) {
            final encodedPath = Uri.encodeComponent(rawSrc);
            src =
            'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
          }

          if (src.startsWith('http')) {
            imageDownloads.add(() async {
              try {
                await DefaultCacheManager().downloadFile(src);
              } catch (e) {
                debugPrint('Error downloading image: $e');
              }
            }());
          }
        }

        for (final block in q.content) {
          if (block.isImage) {
            addDownloadTask(block.src);
          }
        }

        for (final option in q.options) {
          for (final block in option.content) {
            if (block.isImage) {
              addDownloadTask(block.src);
            }
          }
        }

        addDownloadTask(q.imageUrl);
      }

      if (imageDownloads.isNotEmpty) {
        await Future.wait(imageDownloads);
      }
    }

    final jsonList = questions.map((q) => q.toMap()).toList();

    await box.put(cacheKey, json.encode(jsonList));

    debugPrint('✅ Cached ${questions.length} questions for $cacheKey');
  }

  Future<List<QuestionModel>> loadCachedQuestions({
    required String examType,
    required String institutionId,
    required String subject,
    required String year,
  }) async {
    final cacheKey = _buildQuestionCacheKey(
      examType: examType,
      institutionId: institutionId,
      year: year,
      subject: subject,
    );

    final box = await Hive.openBox<String>(_boxName);

    var data = box.get(cacheKey);

    // --- FALLBACK FOR FREE PRE-DOWNLOADED QUESTIONS ---
    if (data == null && subject == 'aptitude') {
      final freeKey = 'free_aptitude_$year';
      data = box.get(freeKey);
      if (data != null) {
        debugPrint('📦 [OFFLINE] Loaded free aptitude questions from key: $freeKey');
      }
    }

    if (data == null) return [];

    final List<dynamic> decodedList = json.decode(data);

    return decodedList.map((item) {
      return QuestionModel.fromFullJson(item);
    }).toList();
  }

  Future<int> getCachedQuestionCount({
    required String examType,
    required String institutionId,
    required String subject,
    required String year,
  }) async {
    final cacheKey = _buildQuestionCacheKey(
      examType: examType,
      institutionId: institutionId,
      year: year,
      subject: subject,
    );

    final box = await Hive.openBox<String>(_boxName);

    final data = box.get(cacheKey);

    if (data == null) return 0;

    final List<dynamic> decodedList = json.decode(data);

    return decodedList.length;
  }

  // =========================================================================
  // HISTORY
  // =========================================================================

  Future<void> saveExamResult({
    required String userId,
    required Map<String, dynamic> examConfig,
    required Map<String, List<QuestionModel>> subjectQuestions,
    required Map<String, Map<int, String>> subjectAnswers,
    required Map<String, dynamic> results,
    required int totalQuestions,
    required Duration timeTaken,
  }) async {
    final localId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';

    final questionIds = subjectQuestions.map(
          (key, value) => MapEntry(
        key,
        value.map((q) => q.id).toList(),
      ),
    );

    final rawAnswers = subjectAnswers.map(
          (key, value) => MapEntry(
        key,
        value.map((k, v) => MapEntry(k.toString(), v)),
      ),
    );

    final historyEntry = {
      'id': localId,
      'examConfig': examConfig,
      'questionIds': questionIds,
      'subjectAnswers': rawAnswers,
      'results': results,
      'totalQuestions': totalQuestions,
      'timeTakenSeconds': timeTaken.inSeconds,
      'completedAt': DateTime.now().toIso8601String(),
      'isSynced': false,
    };

    await _saveToLocalHistory(userId, localId, historyEntry);

    debugPrint('✅ Exam result saved locally: $localId');
  }

  Future<void> _saveToLocalHistory(
      String userId,
      String localId,
      Map<String, dynamic> entry,
      ) async {
    final box = await Hive.openBox<String>(_historyBoxName);
    final key = '${userId}_$localId';

    await box.put(key, json.encode(entry));
  }

  Future<List<Map<String, dynamic>>> getExamHistory(String userId) async {
    final Map<String, Map<String, dynamic>> mergedHistory = {};

    try {
      final box = await Hive.openBox<String>(_historyBoxName);
      final prefix = '${userId}_';

      for (final key in box.keys) {
        if (key.toString().startsWith(prefix)) {
          final data = box.get(key);

          if (data != null) {
            final entry = Map<String, dynamic>.from(json.decode(data));
            final id = entry['id']?.toString() ?? key.toString();

            mergedHistory[id] = entry;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading local exam history: $e');
    }

    final list = mergedHistory.values.toList();

    list.sort((a, b) {
      final timeA = a['completedAt']?.toString() ?? '';
      final timeB = b['completedAt']?.toString() ?? '';

      return timeB.compareTo(timeA);
    });

    return list;
  }

  Future<void> syncPendingResults(UserModel user) async {
    final userId = user.uid;
    debugPrint('🔍 [SYNC] Starting syncPendingResults for user: $userId');
    
    // Fallback: If referredBy is lost due to local Hive caching, fetch it directly from Firestore
    String? currentReferredBy = user.referredBy;
    if (currentReferredBy == null || currentReferredBy.trim().isEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists) {
          currentReferredBy = doc.data()?['referredBy'] as String?;
          debugPrint('🔍 [SYNC] Fetched missing referredBy from Firestore: "$currentReferredBy"');
        }
      } catch (e) {
        debugPrint('🔍 [SYNC] Could not fetch referredBy fallback from Firestore: $e');
      }
    } else {
      debugPrint('🔍 [SYNC] User referredBy value (from cache): "$currentReferredBy"');
    }

    try {
      final box = await Hive.openBox<String>(_historyBoxName);
      final prefix = '${userId}_';
      
      final keys = box.keys.toList();
      debugPrint('🔍 [SYNC] Found ${keys.length} total keys in $_historyBoxName');

      int pendingCount = 0;

      for (final key in keys) {
        if (!key.toString().startsWith(prefix)) continue;

        final data = box.get(key);
        if (data == null) continue;

        final entry = Map<String, dynamic>.from(json.decode(data));
        final isSynced = entry['isSynced'] as bool? ?? false;

        if (!isSynced) {
          pendingCount++;
          debugPrint('🔍 [SYNC] Processing pending result key: $key');
          try {
            // Check if user is referred by a sub-admin
            final bool isReferred = currentReferredBy != null && currentReferredBy.trim().isNotEmpty;
            debugPrint('🔍 [SYNC] isReferred: $isReferred (from "$currentReferredBy")');

            if (!isReferred) {
              debugPrint('🔍 [SYNC] User is NOT referred. Skipping Firestore upload and marking as synced locally to save costs.');
              // For normal users, we don't sync to the cloud to save space.
              // Just mark it as synced locally so we don't keep checking it.
              entry['isSynced'] = true;
              await box.put(key, json.encode(entry));
              continue;
            }

            debugPrint('🔍 [SYNC] User IS referred. Uploading to Firestore...');
            // For referred users, we sync a stripped-down version to save cloud space
            final docRef = _firestore
                .collection('users')
                .doc(userId)
                .collection('exam_history')
                .doc();

            final firestoreEntry = {
              'id': docRef.id,
              'results': entry['results'],
              'timeTakenSeconds': entry['timeTakenSeconds'],
              'completedAt': entry['completedAt'],
              'timestamp': entry['completedAt'], // alias for ordering
              'totalQuestions': entry['totalQuestions'],
              'isSynced': true,
            };

            await docRef.set(firestoreEntry);

            // Mark local full history entry as synced
            entry['isSynced'] = true;
            await box.put(key, json.encode(entry));

            debugPrint('✅ [SYNC] Successfully uploaded result to Firestore! Doc ID: ${docRef.id}');
          } catch (e) {
            debugPrint('❌ [SYNC] Failed to sync result $key: $e');
          }
        }
      }
      
      if (pendingCount == 0) {
        debugPrint('🔍 [SYNC] No pending (isSynced=false) results found for this user.');
      } else {
        debugPrint('🔍 [SYNC] Finished processing $pendingCount pending results.');
      }
    } catch (e) {
      debugPrint('❌ [SYNC] Error syncing pending results: $e');
    }
  }

  Future<void> deleteExamResult(String userId, String docId) async {
    try {
      final box = await Hive.openBox<String>(_historyBoxName);
      final keysToDelete = <dynamic>[];

      for (final key in box.keys) {
        final data = box.get(key);

        if (data != null) {
          final entry = Map<String, dynamic>.from(json.decode(data));

          if (entry['id'] == docId || key == '${userId}_$docId') {
            keysToDelete.add(key);
          }
        }
      }

      await box.deleteAll(keysToDelete);
    } catch (e) {
      debugPrint('Error deleting local exam history: $e');
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('exam_history')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting Firestore exam history: $e');
    }
  }

  // =========================================================================
  // BOOKMARKS
  // =========================================================================

  final String _bookmarkBox = 'bookmarked_questions';

  Future<void> toggleBookmark(
      QuestionModel question,
      String subject,
      String examType,
      String institutionId,
      ) async {
    final box = await Hive.openBox<String>(_bookmarkBox);

    final qId = question.id.isNotEmpty
        ? question.id
        : extractPlainText(question.content).hashCode.toString();

    if (box.containsKey(qId)) {
      await box.delete(qId);
    } else {
      final data = {
        'id': qId,
        'subject': subject,
        'examType': examType,
        'institutionId': institutionId,
        'centerCode': institutionId,
        'question': question.toMap(),
        'savedAt': DateTime.now().toIso8601String(),
      };

      await box.put(qId, json.encode(data));
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final box = await Hive.openBox<String>(_bookmarkBox);

    final list = box.values.map((item) {
      return json.decode(item) as Map<String, dynamic>;
    }).toList();

    list.sort((a, b) {
      return (b['savedAt'] ?? '').compareTo(a['savedAt'] ?? '');
    });

    return list;
  }

  Future<bool> isBookmarked(String qId) async {
    final box = await Hive.openBox<String>(_bookmarkBox);

    return box.containsKey(qId);
  }

  Future<void> clearBookmarks({
    String? examType,
    String? institutionId,
  }) async {
    final box = await Hive.openBox<String>(_bookmarkBox);

    if (examType == null && institutionId == null) {
      await box.clear();
      return;
    }

    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      final item = box.get(key);

      if (item != null) {
        final data = json.decode(item) as Map<String, dynamic>;

        bool matchesExam = true;

        if (examType != null) {
          matchesExam =
              data['examType']?.toString().toLowerCase() ==
                  examType.toLowerCase();
        }

        bool matchesInst = true;

        if (institutionId != null && examType?.toLowerCase() == 'post_utme') {
          final bInst = (data['institutionId'] ?? data['centerCode']) as String?;
          matchesInst = bInst?.toLowerCase() == institutionId.toLowerCase();
        }

        if (matchesExam && matchesInst) {
          keysToDelete.add(key);
        }
      }
    }

    await box.deleteAll(keysToDelete);
  }

  Future<void> predownloadFreeAptitudeQuestions() async {
    try {
      final years = ['2023', '2024'];
      final box = await Hive.openBox<String>(_boxName);
      final yearsBox = await Hive.openBox<String>(_yearsBoxName);

      // Save available years for free offline aptitude
      await yearsBox.put('free_aptitude_years', json.encode(years));

      // --- Caching institutions for free offline use ---
      try {
        debugPrint('⏳ [PRE-DOWNLOAD] Caching institutions for free users...');
        final institutions = await getAvailableInstitutions('post_utme');
        if (institutions.isNotEmpty) {
          await cacheInstitutions('post_utme', institutions);
          
          // Cache logos locally
          for (final inst in institutions) {
            if (inst.logo != null && inst.logo!.trim().isNotEmpty) {
              try {
                await DefaultCacheManager().downloadFile(inst.logo!);
                debugPrint('⚡ [PRE-DOWNLOAD] Cached logo for ${inst.id}: ${inst.logo}');
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [PRE-DOWNLOAD] Failed to cache institutions: $e');
      }

      // Try 'oau' as the primary source for aptitude questions
      final primaryInst = 'oau';

      for (final year in years) {
        debugPrint('⏳ [PRE-DOWNLOAD] Checking if free aptitude questions for $year are cached...');
        final cacheKey = 'free_aptitude_$year';
        if (box.containsKey(cacheKey)) {
          final cachedData = box.get(cacheKey);
          if (cachedData != null && cachedData.isNotEmpty) {
            debugPrint('📦 [PRE-DOWNLOAD] Aptitude $year is already cached. Skipping.');
            continue;
          }
        }

        debugPrint('⏳ [PRE-DOWNLOAD] Downloading free aptitude questions for $year...');
        List<QuestionModel> questions = [];
        try {
          questions = await fetchQuestionsOnline(
            examType: 'post_utme',
            institutionId: primaryInst,
            subject: 'aptitude',
            year: year,
          );
        } catch (e) {
          debugPrint('⚠️ [PRE-DOWNLOAD] Failed to download from $primaryInst for $year: $e');
          // Try 'ui' as a backup fallback
          try {
            questions = await fetchQuestionsOnline(
              examType: 'post_utme',
              institutionId: 'ui',
              subject: 'aptitude',
              year: year,
            );
          } catch (e2) {
            debugPrint('⚠️ [PRE-DOWNLOAD] Fallback download failed: $e2');
          }
        }

        if (questions.isNotEmpty) {
          final jsonList = questions.map((q) => q.toJson()).toList();
          await box.put(cacheKey, json.encode(jsonList));
          debugPrint('📦 [PRE-DOWNLOAD] Successfully saved ${questions.length} questions under $cacheKey');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PRE-DOWNLOAD] General pre-download failure: $e');
    }
  }
}