import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/eclassroom_models.dart';
import '../models/question_model.dart';
import '../../../core/services/network_service.dart';

class EClassroomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> _safeGetDoc(DocumentReference<Map<String, dynamic>> ref) async {
    if (!NetworkService.instance.isOnline) {
      return ref.get(const GetOptions(source: Source.cache));
    }
    try {
      return await ref.get().timeout(const Duration(seconds: 4));
    } catch (_) {
      return ref.get(const GetOptions(source: Source.cache));
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _safeGetQuery(Query<Map<String, dynamic>> query) async {
    if (!NetworkService.instance.isOnline) {
      return query.get(const GetOptions(source: Source.cache));
    }
    try {
      return await query.get().timeout(const Duration(seconds: 4));
    } catch (_) {
      return query.get(const GetOptions(source: Source.cache));
    }
  }

  // Fetch the referred Sub-Admin's profile (Agent details)
  Future<Map<String, dynamic>?> getSubAdminProfile(String adminId) async {
    try {
      final doc = await _safeGetDoc(_firestore.collection('admins').doc(adminId));
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Error fetching sub-admin profile: $e');
    }
    return null;
  }

  // ─── Helper: Parse Timestamp or String into DateTime ─────────────────────
  DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    return fallback ?? DateTime.now();
  }

  // ─── Stream Notice Board notices in real time ────────────────────────────
  Stream<List<Notice>> streamNotices(String adminId) {
    return _firestore
        .collection('admins')
        .doc(adminId)
        .collection('notices')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final notices = snapshot.docs.map((doc) {
        final data = doc.data();
        return Notice(
          id: doc.id,
          title: data['title'] ?? 'No Title',
          message: data['message'] ?? 'No Content',
          timestamp: _parseDate(data['timestamp']),
          isUnread: data['isUnread'] ?? false,
          isPinned: data['isPinned'] ?? false,
        );
      }).toList();

      // Sort: pinned first, then by timestamp descending
      notices.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });

      return notices;
    });
  }

  // ─── Stream classroom Tests ───────────────────────────────────────────────
  Stream<List<ClassroomTest>> streamTests(String adminId) {
    return _firestore
        .collection('admins')
        .doc(adminId)
        .collection('tests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ClassroomTest(
          id: doc.id,
          title: data['title'] ?? 'Test',
          subject: data['subject'] ?? 'General',
          totalQuestions: (data['totalQuestions'] ?? 0) as int,
          durationMinutes: int.tryParse(data['durationMinutes']?.toString() ?? '') ?? 30,
          instructions: data['instructions'] ?? 'Attempt all questions.',
          deadline: _parseDate(data['deadline']),
          createdAt: _parseDate(data['createdAt']),
        );
      }).toList();
    });
  }

  // ─── Fetch classroom Tests (one-shot) ────────────────────────────────────
  Future<List<ClassroomTest>> getTests(String adminId) async {
    try {
      final snapshot = await _safeGetQuery(_firestore
          .collection('admins')
          .doc(adminId)
          .collection('tests')
          .orderBy('createdAt', descending: true));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ClassroomTest(
          id: doc.id,
          title: data['title'] ?? 'Test',
          subject: data['subject'] ?? 'General',
          totalQuestions: (data['totalQuestions'] ?? 0) as int,
          durationMinutes: int.tryParse(data['durationMinutes']?.toString() ?? '') ?? 30,
          instructions: data['instructions'] ?? 'Attempt all questions.',
          deadline: _parseDate(data['deadline']),
          createdAt: _parseDate(data['createdAt']),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting classroom tests: $e');
      return [];
    }
  }

  // ─── Fetch questions for a Classroom Test ────────────────────────────────
  Future<List<QuestionModel>> getClassroomTestQuestions(String adminId, String testId) async {
    try {
      final snapshot = await _safeGetQuery(_firestore
          .collection('admins')
          .doc(adminId)
          .collection('tests')
          .doc(testId)
          .collection('questions')
          .orderBy('number'));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        return QuestionModel.fromFullJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting classroom test questions: $e');
      return [];
    }
  }

  // ─── Check if student has attempted the test ──────────────────────────────
  Future<bool> hasAttempted(String adminId, String testId, String studentId) async {
    try {
      final doc = await _safeGetDoc(_firestore
          .collection('admins')
          .doc(adminId)
          .collection('tests')
          .doc(testId)
          .collection('attempts')
          .doc(studentId));
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking test attempt: $e');
      return false;
    }
  }

  // ─── Get test attempt details ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> getTestAttempt(String adminId, String testId, String studentId) async {
    try {
      final doc = await _safeGetDoc(_firestore
          .collection('admins')
          .doc(adminId)
          .collection('tests')
          .doc(testId)
          .collection('attempts')
          .doc(studentId));
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Error getting test attempt: $e');
    }
    return null;
  }

  // ─── Save test attempt ─────────────────────────────────────────────────────
  Future<void> saveTestAttempt(
    String adminId,
    String testId,
    String studentId, {
    required int score,
    required int totalQuestions,
    required int timeTakenSeconds,
    required Map<String, dynamic> answers,
  }) async {
    try {
      final attemptRef = _firestore
          .collection('admins')
          .doc(adminId)
          .collection('tests')
          .doc(testId)
          .collection('attempts')
          .doc(studentId);

      final submittedAt = FieldValue.serverTimestamp();

      await attemptRef.set({
        'studentId': studentId,
        'score': score,
        'totalQuestions': totalQuestions,
        'timeTakenSeconds': timeTakenSeconds,
        'submittedAt': submittedAt,
        'answers': answers,
      });

      // Also sync to user's exam_history to update classroom leaderboards automatically
      final historyRef = _firestore
          .collection('users')
          .doc(studentId)
          .collection('exam_history')
          .doc('classroom_$testId');

      await historyRef.set({
        'examType': 'classroom_test',
        'institutionId': adminId,
        'subject': 'Classroom Test',
        'year': DateTime.now().year.toString(),
        'totalQuestions': totalQuestions,
        'timeTaken': timeTakenSeconds,
        'date': submittedAt,
        'results': {
          'score': score,
          'correctAnswers': score,
          'wrongAnswers': totalQuestions - score,
          'skippedAnswers': 0,
        },
      });
    } catch (e) {
      debugPrint('Error saving test attempt: $e');
      rethrow;
    }
  }

  // ─── Stream classroom Assignments (real-time, newest first) ──────────────
  Stream<List<Assignment>> streamAssignments(String adminId) {
    return _firestore
        .collection('admins')
        .doc(adminId)
        .collection('assignments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Assignment(
          id: doc.id,
          title: data['title'] ?? 'Assignment',
          subject: data['subject'] ?? 'General',
          description: data['description'],
          contentType: data['contentType'] ?? 'pdf',
          textContent: data['textContent'],
          pdfUrl: data['pdfUrl'] ?? '',
          pdfFileName: data['pdfFileName'],
          dueDate: _parseDate(data['dueDate']),
          createdAt: _parseDate(data['createdAt']),
          updatedAt: data['updatedAt'] != null ? _parseDate(data['updatedAt']) : null,
        );
      }).toList();
    });
  }

  // ─── Legacy: Fetch classroom Assignments (one-shot) ──────────────────────
  Future<List<Assignment>> getAssignments(String adminId) async {
    try {
      final snapshot = await _safeGetQuery(_firestore
          .collection('admins')
          .doc(adminId)
          .collection('assignments')
          .orderBy('createdAt', descending: true));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Assignment(
          id: doc.id,
          title: data['title'] ?? 'Assignment',
          subject: data['subject'] ?? 'General',
          description: data['description'],
          contentType: data['contentType'] ?? 'pdf',
          textContent: data['textContent'],
          pdfUrl: data['pdfUrl'] ?? '',
          pdfFileName: data['pdfFileName'],
          dueDate: _parseDate(data['dueDate']),
          createdAt: _parseDate(data['createdAt']),
          updatedAt: data['updatedAt'] != null ? _parseDate(data['updatedAt']) : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting classroom assignments: $e');
      return [];
    }
  }

  // ─── Stream classroom Study Notes (real-time, newest first) ──────────────
  Stream<List<StudyNote>> streamStudyNotes(String adminId) {
    return _firestore
        .collection('admins')
        .doc(adminId)
        .collection('study_notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StudyNote(
          id: doc.id,
          title: data['title'] ?? 'Study Note',
          subject: data['subject'] ?? 'General',
          topic: data['topic'] ?? data['title'] ?? 'Topic',
          description: data['description'],
          contentType: data['contentType'] ?? 'pdf',
          textContent: data['textContent'],
          pdfUrl: data['pdfUrl'] ?? '',
          pdfFileName: data['pdfFileName'],
          createdAt: _parseDate(data['createdAt']),
          updatedAt: data['updatedAt'] != null ? _parseDate(data['updatedAt']) : null,
        );
      }).toList();
    });
  }

  // ─── Legacy: Fetch classroom Study Notes (one-shot) ──────────────────────
  Future<List<StudyNote>> getStudyNotes(String adminId) async {
    try {
      final snapshot = await _safeGetQuery(_firestore
          .collection('admins')
          .doc(adminId)
          .collection('study_notes')
          .orderBy('createdAt', descending: true));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StudyNote(
          id: doc.id,
          title: data['title'] ?? 'Study Note',
          subject: data['subject'] ?? 'General',
          topic: data['topic'] ?? data['title'] ?? 'Topic',
          description: data['description'],
          contentType: data['contentType'] ?? 'pdf',
          textContent: data['textContent'],
          pdfUrl: data['pdfUrl'] ?? '',
          pdfFileName: data['pdfFileName'],
          createdAt: _parseDate(data['createdAt']),
          updatedAt: data['updatedAt'] != null ? _parseDate(data['updatedAt']) : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting study notes: $e');
      return [];
    }
  }

  // ─── Fetch Classroom Leaderboard ─────────────────────────────────────────
  // 1. Queries all students referred by this sub-admin
  // 2. Queries their exam_history subcollections to compute average scores
  // 3. Ranks them in descending order
  Future<List<LeaderboardEntry>> getClassroomLeaderboard(
    String adminId,
    String currentUserId,
  ) async {
    try {
      final studentsSnap = await _safeGetQuery(_firestore
          .collection('users')
          .where('referredBy', isEqualTo: adminId));

      if (studentsSnap.docs.isEmpty) {
        return [];
      }

      final List<LeaderboardEntry> entries = [];

      // Query exam histories in parallel to optimize load speeds
      final List<Future<LeaderboardEntry?>> futures = studentsSnap.docs.map((doc) async {
        final studentId = doc.id;
        final studentData = doc.data();
        final name = studentData['displayName'] ?? studentData['email'] ?? 'Student';
        final avatarUrl = studentData['photoUrl'] ?? 'https://i.pravatar.cc/150?u=$studentId';

        try {
          final historySnap = await _safeGetQuery(_firestore
              .collection('users')
              .doc(studentId)
              .collection('exam_history')
              .limit(20)); // Limit to last 20 exams for better average and counting

          double totalPercentageSum = 0;
          int examCount = 0;

          for (final histDoc in historySnap.docs) {
            final histData = histDoc.data();
            final results = histData['results'] as Map<String, dynamic>?;
            if (results != null) {
              final score = results['score'] as num? ?? results['correctAnswers'] as num? ?? 0;
              final totalQuestions = histData['totalQuestions'] as num? ?? results['totalQuestions'] as num? ?? 0;
              if (totalQuestions > 0) {
                totalPercentageSum += (score / totalQuestions) * 100;
                examCount++;
              }
            }
          }

          final int averageScore = examCount > 0 
              ? (totalPercentageSum / examCount).round() 
              : 0;

          return LeaderboardEntry(
            studentId: studentId,
            name: name,
            avatarUrl: avatarUrl,
            totalScore: averageScore, // Scaled 0 to 100 as the ranking metric
            rank: 0, // Assigned later after sorting
            isCurrentUser: studentId == currentUserId,
            testsTaken: examCount,
          );
        } catch (e) {
          debugPrint('Error getting history for student $studentId: $e');
          return null;
        }
      }).toList();

      final List<LeaderboardEntry?> results = await Future.wait(futures);

      for (final res in results) {
        if (res != null) {
          entries.add(res);
        }
      }

      // Sort entries descending based on totalScore (average percentage)
      entries.sort((a, b) => b.totalScore.compareTo(a.totalScore));

      // Map dynamic rankings
      final List<LeaderboardEntry> rankedEntries = [];
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        rankedEntries.add(
          LeaderboardEntry(
            studentId: entry.studentId,
            name: entry.name,
            avatarUrl: entry.avatarUrl,
            totalScore: entry.totalScore,
            rank: i + 1,
            isCurrentUser: entry.isCurrentUser,
            testsTaken: entry.testsTaken,
          ),
        );
      }

      return rankedEntries;
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      return [];
    }
  }
}
