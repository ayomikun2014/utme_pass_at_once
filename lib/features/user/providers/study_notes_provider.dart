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

  bool _hasFetched = false;

  List<StudySubjectModel> get subjects => _subjects;
  bool get isLoading => _isLoading;
  bool get hasFetched => _hasFetched;
  String? get error => _error;

  String get searchQuery => _searchQuery;
  String? get selectedSubjectId => _selectedSubjectId;

  Future<void> loadStudyNotes({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasFetched) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _subjects = _ordered(await _service.fetchStudyNotes());
      _hasFetched = true;
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _hasFetched = true;
    }
    notifyListeners();
  }

  /// Use of English first, then the rest by name.
  ///
  /// It is the note every reader can open without activating anything, so it
  /// leads the list rather than sitting wherever Firestore happened to return
  /// it -- which is by document id, and puts it last.
  List<StudySubjectModel> _ordered(List<StudySubjectModel> subjects) {
    final sorted = [...subjects];
    sorted.sort((a, b) {
      final aFirst = _isUseOfEnglish(a);
      final bFirst = _isUseOfEnglish(b);
      if (aFirst != bFirst) return aFirst ? -1 : 1;
      return a.subjectName.toLowerCase().compareTo(b.subjectName.toLowerCase());
    });
    return sorted;
  }

  /// Matches on the id or the name, so renaming the document does not quietly
  /// send it back down the list. Literature in English is not it.
  static bool _isUseOfEnglish(StudySubjectModel s) {
    final id = s.subjectId.toLowerCase();
    if (id == 'use_of_english') return true;
    final text = '$id ${s.subjectName.toLowerCase()}';
    return text.contains('english') && !text.contains('literature');
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedSubject(String? subjectId) {
    _selectedSubjectId = subjectId;
    notifyListeners();
  }
}
