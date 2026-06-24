import 'package:flutter/material.dart';

import '../../auth/providers/auth_provider.dart';
import '../services/unlock_service.dart';
import '../../../core/services/network_service.dart';


class UnlockProvider extends ChangeNotifier {
  final UnlockService _service = UnlockService();

  bool _isLoading = false;
  String _errorMessage = '';
  String _voucherCode = '';
  String _examType = '';

  List<String> _availableInstitutions = [];
  List<String> _availableSubjects = [];
  String _selectedInstitution = '';
  final List<String> _selectedSubjects = [];

  // Post UTME section state
  String _selectedSectionId = '';
  String _selectedSectionName = '';
  List<String> _sectionSubjects = [];

  bool _isActivationComplete = false;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get examType => _examType;

  List<String> get availableInstitutions => _availableInstitutions;
  List<String> get availableSubjects => _availableSubjects;

  String get selectedInstitution => _selectedInstitution;
  List<String> get selectedSubjects => List.unmodifiable(_selectedSubjects);

  String get selectedSectionId => _selectedSectionId;
  String get selectedSectionName => _selectedSectionName;
  List<String> get sectionSubjects => List.unmodifiable(_sectionSubjects);

  bool get isActivationComplete => _isActivationComplete;

  bool get isPostUtme => _examType.toLowerCase().trim() == 'post_utme';

  // Backward compatible getters
  List<String> get availableCenters => _availableInstitutions;
  String get selectedCenter => _selectedInstitution;

  int get maxSubjects {
    final lowerType = _examType.toLowerCase().trim();

    if (lowerType == 'waec' || lowerType == 'neco') {
      return 9;
    }

    return 4;
  }

  bool get isValidSubjectCount {
    final lowerType = _examType.toLowerCase().trim();

    if (lowerType == 'waec' || lowerType == 'neco') {
      return _selectedSubjects.isNotEmpty && _selectedSubjects.length <= 9;
    }

    return _selectedSubjects.isNotEmpty && _selectedSubjects.length <= 4;
  }

  List<String> get subjectsToUnlock {
    if (isPostUtme) {
      return List.unmodifiable(_sectionSubjects);
    }

    return List.unmodifiable(_selectedSubjects);
  }

  String get selectedPackageInstitutionKey {
    if (_selectedInstitution.isEmpty) return '';

    final baseInstitution = _selectedInstitution.toLowerCase().trim();

    if (isPostUtme && _selectedSectionId.trim().isNotEmpty) {
      return '${baseInstitution}_${_selectedSectionId.toLowerCase().trim()}';
    }

    return baseInstitution;
  }

  void resetUnlockState() {
    _isLoading = false;
    _errorMessage = '';
    _examType = '';
    _voucherCode = '';

    _availableInstitutions = [];
    _availableSubjects = [];

    _selectedInstitution = '';
    _selectedSubjects.clear();

    _selectedSectionId = '';
    _selectedSectionName = '';
    _sectionSubjects.clear();

    _isActivationComplete = false;

    notifyListeners();
  }

  void setActivationComplete(bool value) {
    _isActivationComplete = value;
    notifyListeners();
  }

  void resetInstitutionSelection() {
    _selectedInstitution = '';
    _availableSubjects = [];
    _selectedSubjects.clear();

    _selectedSectionId = '';
    _selectedSectionName = '';
    _sectionSubjects.clear();

    _errorMessage = '';

    notifyListeners();
  }

  void resetCenterSelection() => resetInstitutionSelection();

  void resetSectionSelection() {
    _selectedSectionId = '';
    _selectedSectionName = '';
    _sectionSubjects.clear();
    _errorMessage = '';

    notifyListeners();
  }

  Future<bool> validateCode(String code) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      _isActivationComplete = false;
      notifyListeners();

      final hasInternet = await NetworkService.instance.hasInternet();

      if (!hasInternet) {
        _errorMessage =
        'No internet connection. Please check your network and try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _voucherCode = code.trim().toUpperCase();

      final validatedExamType = await _service.validateActivationCode(
        _voucherCode,
      );

      _examType = validatedExamType.toLowerCase().trim();

      _availableInstitutions = await _service.fetchInstitutions(_examType);

      _selectedInstitution = '';
      _selectedSubjects.clear();

      _selectedSectionId = '';
      _selectedSectionName = '';
      _sectionSubjects.clear();

      _availableSubjects = [];

      if (!isPostUtme && _availableInstitutions.isNotEmpty) {
        await selectInstitution(_availableInstitutions.first);
      } else {
        _isLoading = false;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> selectInstitution(String institutionId) async {
    try {
      _selectedInstitution = institutionId.toLowerCase().trim();

      _selectedSubjects.clear();

      _selectedSectionId = '';
      _selectedSectionName = '';
      _sectionSubjects.clear();

      _availableSubjects = [];
      _errorMessage = '';

      _isLoading = true;
      notifyListeners();

      if (!isPostUtme) {
        _availableSubjects = await _service.fetchSubjects(
          _examType,
          _selectedInstitution,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectCenter(String center) {
    return selectInstitution(center);
  }

  Future<void> selectSection(String sectionId, String sectionName) async {
    try {
      if (_selectedInstitution.isEmpty) {
        _errorMessage = 'Please select an institution first.';
        notifyListeners();
        return;
      }

      _selectedSectionId = sectionId.toLowerCase().trim();
      _selectedSectionName = sectionName.trim();

      _sectionSubjects.clear();
      _selectedSubjects.clear();

      _errorMessage = '';
      _isLoading = true;
      notifyListeners();

      _sectionSubjects = await _service.fetchSubjectsBySection(
        _examType,
        _selectedInstitution,
        _selectedSectionId,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleSubject(String subject) {
    if (_selectedSubjects.contains(subject)) {
      _selectedSubjects.remove(subject);
      _errorMessage = '';
    } else {
      if (_selectedSubjects.length < maxSubjects) {
        _selectedSubjects.add(subject);
        _errorMessage = '';
      } else {
        _errorMessage = 'You can only select $maxSubjects subjects.';
      }
    }

    notifyListeners();
  }

  bool isSubjectSelected(String subject) {
    return _selectedSubjects.contains(subject);
  }

  Future<bool> unlockExam(AuthProvider authProvider) async {
    if (_selectedInstitution.isEmpty) {
      _errorMessage = 'Please select an institution.';
      notifyListeners();
      return false;
    }

    if (isPostUtme) {
      if (_selectedSectionId.isEmpty || _sectionSubjects.isEmpty) {
        _errorMessage = 'Please select a section to unlock subjects.';
        notifyListeners();
        return false;
      }
    } else {
      if (!isValidSubjectCount) {
        final lowerType = _examType.toLowerCase().trim();

        if (lowerType == 'waec' || lowerType == 'neco') {
          _errorMessage = 'Please select 1 to 9 subjects.';
        } else {
          _errorMessage = 'Please select 1 to 4 subjects.';
        }

        notifyListeners();
        return false;
      }
    }

    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      _errorMessage = 'Please log in first.';
      notifyListeners();
      return false;
    }

    final lowerExamType = _examType.toLowerCase().trim();

    // REMOVED the restrictive local `alreadyUnlocked` check.
    // We now rely entirely on the UnlockService to determine if the
    // existing package has expired or is still active.

    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      final hasInternet = await NetworkService.instance.hasInternet();

      if (!hasInternet) {
        _errorMessage =
        'No internet connection. Please check your network and try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final selectedSubjectsToUnlock = subjectsToUnlock;

      // This service will now throw an error if they have an ACTIVE, unexpired subscription.
      // If it's expired, it will safely overwrite it with the new code and new 10-month timer.
      await _service.activateExam(
        voucherCode: _voucherCode,
        userId: currentUser.uid,
        examType: lowerExamType,
        institutionId: _selectedInstitution,
        subjects: selectedSubjectsToUnlock,
        userName: currentUser.displayName,
        selectedSectionId: isPostUtme ? _selectedSectionId : null,
        selectedSectionName: isPostUtme ? _selectedSectionName : null,
      );


      _isLoading = false;
      notifyListeners();

      authProvider.refreshUser().catchError((e) {
        debugPrint('Background sync failed: $e');
      });

      return true;
    } catch (e) {
      // The exception from UnlockService ("You already have an active subscription...")
      // will be caught and displayed here.
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}