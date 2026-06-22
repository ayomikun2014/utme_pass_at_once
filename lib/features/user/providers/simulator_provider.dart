import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/question_model.dart';
import '../models/question_bank_model.dart';
import '../services/simulator_service.dart';

class SimulatorProvider extends ChangeNotifier {
  final SimulatorService _service = SimulatorService();

  bool _isLoading = false;
  String _errorMessage = '';
  int _downloadProgress = 0;
  int _downloadTotal = 0;

  bool _isCheckingUpdates = false;

  // Activation download state
  int _activationProgress = 0;
  int _activationTotal = 0;
  String _activationStep = '';

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get downloadProgress => _downloadProgress;
  int get downloadTotal => _downloadTotal;
  bool get isCheckingUpdates => _isCheckingUpdates;

  int get activationProgress => _activationProgress;
  int get activationTotal => _activationTotal;
  String get activationStep => _activationStep;

  bool hasPremiumForExam(AuthProvider authProvider, String examType) {
    if (authProvider.currentUser == null) return false;

    return authProvider.currentUser!.hasActiveExam(
      examType,
      authProvider.currentDeviceId,
    );
  }

  // =========================================================================
  // INSTITUTIONS
  // =========================================================================
// =========================================================================
  // SMART MERGE / UPDATES
  // =========================================================================

  Future<Map<String, dynamic>> checkForUpdates({
    required String examType,
    required String institutionId,
    String? sectionId,
  }) async {
    try {
      _isCheckingUpdates = true;
      _safeNotifyListeners();

      // Calls the new method we wrote in SimulatorService
      final result = await _service.checkForUpdates(
        examType: examType,
        institutionId: institutionId,
        sectionId: sectionId,
      );

      _isCheckingUpdates = false;
      _safeNotifyListeners();

      return result;
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
      _isCheckingUpdates = false;
      _safeNotifyListeners();

      return {
        'updatesAvailable': false,
        'newSubjects': 0,
        'newYears': 0,
        'message': 'Failed to check for updates. Please check your connection.'
      };
    }
  }

  Future<List<InstitutionModel>> getAvailableInstitutions(
      String examType, {
        bool isPremium = false,
      }) async {
    if (isPremium) {
      debugPrint(
        '🔧 [OFFLINE] getAvailableInstitutions: Loading from Hive for $examType',
      );

      return await _service.getCachedInstitutions(examType);
    }

    debugPrint(
      '🌐 [ONLINE] getAvailableInstitutions: Loading from Firestore for $examType',
    );

    return await _service.getAvailableInstitutions(examType);
  }

  // =========================================================================
  // SUBJECTS
  // =========================================================================

  Future<List<SubjectModel>> getAvailableSubjects(
      String examType,
      String institutionId, {
        bool isPremium = false,
        String? sectionId,
      }) async {
    if (isPremium) {
      debugPrint(
        '🔧 [OFFLINE] getAvailableSubjects: Loading from Hive for $examType/$institutionId section=$sectionId',
      );

      return await _service.getCachedSubjects(
        examType,
        institutionId,
        sectionId: sectionId,
      );
    }

    debugPrint(
      '🌐 [ONLINE] getAvailableSubjects: Loading from Firestore for $examType/$institutionId',
    );

    return await _service.getAvailableSubjects(examType, institutionId);
  }

  // =========================================================================
  // YEARS
  // =========================================================================

  Future<List<String>> getAvailableYears(
      String examType,
      String institutionId,
      String subject, {
        bool isPremium = false,
        String? sectionId,
      }) async {
    try {
      // Fast path for free tier aptitude to prevent offline timeout hangs on setup
      if (!isPremium && subject == 'aptitude') {
        debugPrint('🌐 [FREE] getAvailableYears: Instantly returning free aptitude years');
        try {
          final yearsBox = await Hive.openBox<String>('offline_years');
          final data = yearsBox.get('free_aptitude_years');
          if (data != null) {
            final List<dynamic> decoded = json.decode(data);
            final List<String> years = decoded.map((y) => y.toString()).toList();
            if (years.isNotEmpty) return years;
          }
        } catch (e) {
          debugPrint('⚠️ Error loading free aptitude years from Hive: $e');
        }
        return ['2024', '2023'];
      }

      if (isPremium) {
        debugPrint(
          '🔧 [OFFLINE] getAvailableYears: Loading from Hive for $examType/$institutionId/$subject section=$sectionId',
        );

        final cached = await _service.getCachedAvailableYears(
          examType,
          institutionId,
          subject,
          sectionId: sectionId,
        );

        if (cached == null) {
          throw Exception(
            'Offline data not found. Please reconnect and restore your activated package.',
          );
        }

        return cached;
      }

      debugPrint(
        '🌐 [ONLINE] getAvailableYears: Loading from Firestore for $examType/$institutionId/$subject',
      );

      return await _service.getAvailableYears(
        examType,
        institutionId,
        subject,
      );
    } catch (e) {
      debugPrint('❌ getAvailableYears error: $e');
      rethrow;
    }
  }

  // =========================================================================
  // INSTITUTION MAPPING
  // =========================================================================

  Future<Map<String, Map<String, dynamic>>> getInstitutionMapping(
      String examType, {
        bool isPremium = false,
      }) async {
    if (isPremium) {
      debugPrint(
        '🔧 [OFFLINE] getInstitutionMapping: Loading from Hive for $examType',
      );

      return await _service.getCachedInstitutionMapping(examType);
    }

    debugPrint(
      '🌐 [ONLINE] getInstitutionMapping: Loading from Firestore for $examType',
    );

    return await _service.getInstitutionMapping(examType);
  }

// =========================================================================
  // ACTIVATION DOWNLOAD (DYNAMIC)
  // =========================================================================

  Future<bool> downloadActivationData({
    required String examType,
    required String institutionId,
    // REMOVED: required List<String> subjects,
    String? sectionId,
  }) async {
    try {
      _activationProgress = 0;
      _activationTotal = 0;
      _activationStep = 'Preparing dynamic download...';
      _errorMessage = '';
      _safeNotifyListeners();

      debugPrint(
        '⚡ [ACTIVATION] downloadActivationData called: $examType/$institutionId section=$sectionId',
      );

      await _service.downloadAndCacheAllActivationData(
        examType: examType,
        institutionId: institutionId,
        sectionId: sectionId, // Subjects are now discovered dynamically by the service!
        onProgress: (current, total) {
          _activationProgress = current;
          _activationTotal = total;
          _activationStep = 'Processing $current of $total...';

          debugPrint('⚡ [ACTIVATION] Progress: $current/$total');

          _safeNotifyListeners();
        },
      );

      _activationStep = 'Complete!';
      _safeNotifyListeners();

      debugPrint(
        '⚡ [ACTIVATION] ✅ All activation data downloaded successfully',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('⚡ [ACTIVATION] ❌ Error: $e');
      debugPrint('⚡ [ACTIVATION] StackTrace: $stackTrace');

      _errorMessage =
      'Error downloading activation data. Please check your internet connection.';

      _safeNotifyListeners();

      return false;
    }
  }

  Future<bool> isActivatedPackageDownloaded({
    required String examType,
    required String institutionId,
    // REMOVED: required List<String> subjects,
    String? sectionId,
  }) async {
    return await _service.isActivatedPackageDownloaded(
      examType: examType,
      institutionId: institutionId,
      sectionId: sectionId, // Dynamically checks all cached metadata
    );
  }

  // =========================================================================
  // QUESTION CACHE CHECK
  // =========================================================================

  Future<bool> areQuestionsCached({
    required String examType,
    required String institutionId,
    required List<String> subjects,
    required Map<String, String> subjectYears,
  }) async {
    for (final subject in subjects) {
      final year = subjectYears[subject] ?? '2024';

      final isCached = await _service.areQuestionsCached(
        examType: examType,
        institutionId: institutionId,
        year: year,
        subject: subject,
      );

      if (!isCached) return false;
    }

    return true;
  }

  // =========================================================================
  // PREPARE QUESTIONS
  // =========================================================================

  Future<bool> prepareFreeTierQuestions(
      String examType,
      String institutionId,
      String year,
      ) async {
    return await prepareExamQuestions(
      examType: examType,
      institutionId: institutionId,
      subjects: ['aptitude'],
      subjectYears: {'aptitude': year},
    );
  }

  Future<bool> prepareExamQuestions({
    required String examType,
    required String institutionId,
    required List<String> subjects,
    required Map<String, String> subjectYears,
    bool downloadAllYears = false,
    bool isPremium = false,
    String? sectionId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      _downloadProgress = 0;
      _downloadTotal = 0;
      _safeNotifyListeners();

      // --- SKIP REDUNDANT FREE DOWNLOADS ---
      if (!isPremium && subjects.length == 1 && subjects.first == 'aptitude') {
        final year = subjectYears['aptitude'] ?? '2024';
        final cached = await _service.areQuestionsCached(
          examType: examType,
          institutionId: institutionId,
          year: year,
          subject: 'aptitude',
        );
        if (cached) {
          debugPrint('📦 [FREE] prepareExamQuestions: Free aptitude questions for $year are already cached. Instantly returning.');
          _isLoading = false;
          _safeNotifyListeners();
          return true;
        }
      }

      if (downloadAllYears) {
        int total = 0;
        final Map<String, List<String>> allYearsMap = {};

        final List<Future<void>> fetchYearTasks = subjects.map((subject) async {
          final years = await getAvailableYears(
            examType,
            institutionId,
            subject,
            isPremium: isPremium,
            sectionId: sectionId,
          );

          allYearsMap[subject] = years;
          total += years.length;
        }).toList();

        await Future.wait(fetchYearTasks);

        _downloadTotal = total;
        _safeNotifyListeners();

        final List<Future<void>> downloadTasks = [];

        for (final subject in subjects) {
          final years = allYearsMap[subject] ?? [];

          for (final year in years) {
            downloadTasks.add(
              _service
                  .downloadAndCacheQuestions(
                examType: examType,
                institutionId: institutionId,
                year: year,
                subject: subject,
              )
                  .then((_) {
                _downloadProgress++;
                _safeNotifyListeners();
              }),
            );
          }
        }

        await Future.wait(downloadTasks);
      } else {
        _downloadTotal = subjects.length;
        _safeNotifyListeners();

        final List<Future<void>> downloadTasks = subjects.map((subject) async {
          final year = subjectYears[subject] ?? '2024';

          await _service.downloadAndCacheQuestions(
            examType: examType,
            institutionId: institutionId,
            year: year,
            subject: subject,
          );

          _downloadProgress++;
          _safeNotifyListeners();
        }).toList();

        await Future.wait(downloadTasks);
      }

      _isLoading = false;
      _safeNotifyListeners();

      return true;
    } catch (e, stackTrace) {
      debugPrint('SimulatorProvider Error: $e');
      debugPrint('StackTrace: $stackTrace');

      _errorMessage =
      'Error downloading questions. Please check your internet connection.';

      _isLoading = false;
      _safeNotifyListeners();

      return false;
    }
  }

  // =========================================================================
  // HISTORY MANAGEMENT
  // =========================================================================

  Future<void> saveExamResult(
      AuthProvider authProvider, {
        required Map<String, dynamic> examConfig,
        required Map<String, List<QuestionModel>> subjectQuestions,
        required Map<String, Map<int, String>> subjectAnswers,
        required Map<String, dynamic> results,
        required int totalQuestions,
        required Duration timeTaken,
      }) async {
    final user = authProvider.currentUser;

    if (user == null) return;

    await _service.saveExamResult(
      userId: user.uid,
      examConfig: examConfig,
      subjectQuestions: subjectQuestions,
      subjectAnswers: subjectAnswers,
      results: results,
      totalQuestions: totalQuestions,
      timeTaken: timeTaken,
    );

    // Auto-sync in the background right after saving locally.
    // We do not await this Future so that even if the user has no internet connection,
    // they can proceed to the results screen instantly without being blocked by an infinite loading screen.
    unawaited(
      _service.syncPendingResults(user).catchError((e) {
        debugPrint('⚠️ Error in background Firestore sync: $e');
      }),
    );
  }

  Future<List<Map<String, dynamic>>> getExamHistory(
      AuthProvider authProvider,
      ) async {
    final user = authProvider.currentUser;

    if (user == null) return [];

    return await _service.getExamHistory(user.uid);
  }

  Future<void> syncPendingResults(AuthProvider authProvider) async {
    final user = authProvider.currentUser;

    if (user == null) return;

    await _service.syncPendingResults(user);
  }

  Future<void> deleteExamResult(
      AuthProvider authProvider,
      String docId,
      ) async {
    final user = authProvider.currentUser;

    if (user == null) return;

    await _service.deleteExamResult(user.uid, docId);
  }

  // =========================================================================
  // HISTORY PARSING
  // =========================================================================

  Map<String, Map<int, String>> parseSubjectAnswers(
      Map<String, dynamic> rawAnswers,
      ) {
    final Map<String, Map<int, String>> parsed = {};

    rawAnswers.forEach((subject, subjectAns) {
      if (subjectAns is Map) {
        parsed[subject] = {};

        subjectAns.forEach((key, val) {
          final intKey = int.tryParse(key.toString());

          if (intKey != null && val is String) {
            parsed[subject]![intKey] = val;
          }
        });
      }
    });

    return parsed;
  }

  Future<Map<String, List<QuestionModel>>> loadQuestionsForHistory(
      Map<String, dynamic> entry,
      ) async {
    final examConfig = Map<String, dynamic>.from(entry['examConfig'] ?? {});

    final examType = examConfig['examType'] as String? ?? '';
    final institutionId = examConfig['centerCode'] as String? ??
        examConfig['institutionId'] as String? ??
        'default';

    if (entry.containsKey('questionIds')) {
      final Map<String, dynamic> rawIds = Map<String, dynamic>.from(
        entry['questionIds'],
      );

      final Map<String, List<QuestionModel>> reconstructed = {};

      for (final subject in rawIds.keys) {
        final List<String> ids = List<String>.from(rawIds[subject] ?? []);

        final yearMap = examConfig['years'] as Map?;
        final year = yearMap?[subject]?.toString() ?? '2024';

        final allQuestions = await _service.loadCachedQuestions(
          examType: examType,
          institutionId: institutionId,
          subject: subject,
          year: year,
        );

        reconstructed[subject] = ids.map((id) {
          try {
            return allQuestions.firstWhere((q) => q.id == id);
          } catch (e) {
            return QuestionModel(
              id: id,
              examType: examType,
              subject: subject,
              year: year,
              content: [
                ContentBlockModel(
                  type: 'text',
                  value: 'Question data not found in cache.',
                ),
              ],
              options: [],
              answer: '',
            );
          }
        }).toList();
      }

      return reconstructed;
    }

    final rawQuestions = Map<String, dynamic>.from(
      entry['subjectQuestions'] ?? {},
    );

    return await parseSubjectQuestions(rawQuestions);
  }

  static Map<String, List<QuestionModel>> _parseQuestionsIsolate(Map<String, dynamic> rawQuestions) {
    final Map<String, List<QuestionModel>> parsed = {};

    rawQuestions.forEach((subject, questionData) {
      if (questionData is String) {
        try {
          final List<dynamic> decoded = json.decode(questionData);

          parsed[subject] = decoded.map((q) {
            final qMap = Map<String, dynamic>.from(q as Map);

            return QuestionModel.fromFullJson(qMap);
          }).toList();
        } catch (_) {
          parsed[subject] = [];
        }
      } else if (questionData is List) {
        parsed[subject] = questionData.map((q) {
          final qMap = Map<String, dynamic>.from(q as Map);

          return QuestionModel.fromFullJson(qMap);
        }).toList();
      }
    });

    return parsed;
  }

  Future<Map<String, List<QuestionModel>>> parseSubjectQuestions(
      Map<String, dynamic> rawQuestions,
      ) async {
    return await compute(_parseQuestionsIsolate, rawQuestions);
  }

  // =========================================================================
  // BOOKMARK MANAGEMENT
  // =========================================================================

  Future<void> toggleBookmark(
      QuestionModel question,
      String subject,
      String examType,
      String institutionId,
      ) async {
    await _service.toggleBookmark(
      question,
      subject,
      examType,
      institutionId,
    );

    _safeNotifyListeners();
  }

  Future<List<Map<String, dynamic>>> getBookmarks() async {
    return await _service.getBookmarks();
  }

  Future<bool> isBookmarked(QuestionModel question) async {
    final qId = question.id.isNotEmpty
        ? question.id
        : extractPlainText(question.content).hashCode.toString();

    return await _service.isBookmarked(qId);
  }

  Future<void> clearAllBookmarks({
    String? examType,
    String? institutionId,
  }) async {
    await _service.clearBookmarks(
      examType: examType,
      institutionId: institutionId,
    );

    _safeNotifyListeners();
  }

  // =========================================================================
  // SAFE NOTIFY
  // =========================================================================

  void _safeNotifyListeners() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}