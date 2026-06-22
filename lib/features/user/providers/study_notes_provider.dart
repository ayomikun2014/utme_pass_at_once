import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/features/user/models/study_notes_model.dart';
import 'package:utme_pass_at_once/features/user/services/study_notes_service.dart';

class StudyNotesProvider with ChangeNotifier {
  final StudyNotesService _service = StudyNotesService();

  List<StudySubjectModel> _subjects = [];
  bool _isLoading = false;
  String? _error;

  String _searchQuery = '';
  String? _selectedSubjectId;

  // Track current context to prevent unnecessary re-fetching
  String? _currentExamType;
  String? _currentInstitutionId;

  bool _hasFetched = false;

  List<StudySubjectModel> get subjects => _subjects;
  bool get isLoading => _isLoading;
  bool get hasFetched => _hasFetched;
  String? get error => _error;

  String get searchQuery => _searchQuery;
  String? get selectedSubjectId => _selectedSubjectId;

  Future<void> loadStudyNotes({
    required String examType,
    String? institutionId,
    bool forceRefresh = false,
  }) async {
    // Use cache if we already have the exact data for this exam/institution
    if (!forceRefresh && _hasFetched &&
        _currentExamType == examType &&
        _currentInstitutionId == institutionId) {
      return;
    }

    _isLoading = true;
    _error = null;
    _currentExamType = examType;
    _currentInstitutionId = institutionId;
    notifyListeners();

    try {
      _subjects = await _service.fetchStudyNotes(
        examType: examType,
        institutionId: institutionId,
      );
      _hasFetched = true;
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _hasFetched = true;
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedSubject(String? subjectId) {
    _selectedSubjectId = subjectId;
    notifyListeners();
  }

  List<StudyTopicModel> get filteredTopics {
    List<StudyTopicModel> allTopics = [];

    // 1. Filter by subject
    if (_selectedSubjectId == null) {
      for (var subject in _subjects) {
        allTopics.addAll(subject.topics.values);
      }
    } else {
      final selected = _subjects.firstWhere(
            (s) => s.subjectId == _selectedSubjectId,
        orElse: () => StudySubjectModel(subjectId: '', subjectName: '', topics: {}),
      );
      allTopics.addAll(selected.topics.values);
    }

    // 2. Filter by search query
    if (_searchQuery.isEmpty) return allTopics;

    return allTopics.where((topic) {
      return topic.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String getSubjectName(String topicId) {
    for (var subject in _subjects) {
      if (subject.topics.containsKey(topicId)) {
        return subject.subjectName;
      }
    }
    return 'General';
  }
}