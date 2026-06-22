import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/features/user/models/admission_guideline_model.dart';
import 'package:utme_pass_at_once/features/user/services/admission_data_service.dart';

class AdmissionProvider extends ChangeNotifier {
  final AdmissionDataService _service = AdmissionDataService();

  List<AdmissionFacultyModel>? _requirements;
  List<AdmissionFacultyModel>? _cutOffs;

  // Separate loading/error state for requirements
  bool _isLoadingRequirements = false;
  String? _requirementsError;
  String? _requirementsInstitutionId;

  // Separate loading/error state for cut offs
  bool _isLoadingCutOffs = false;
  String? _cutOffsError;
  String? _cutOffsInstitutionId;

  bool get isLoadingRequirements => _isLoadingRequirements;
  bool get isLoadingCutOffs => _isLoadingCutOffs;
  String? get requirementsError => _requirementsError;
  String? get cutOffsError => _cutOffsError;

  // Legacy getters for backward compatibility
  bool get isLoading => _isLoadingRequirements || _isLoadingCutOffs;
  String? get error => _requirementsError ?? _cutOffsError;

  // Requirements Filtering
  String _reqSearchQuery = '';
  String? _reqSelectedFacultyId;

  // CutOffs Filtering
  String _cutSearchQuery = '';
  String? _cutSelectedFacultyId;
  String? _selectedState;

  // Getters for filtered data
  List<AdmissionCourseRequirementModel> get filteredRequirements {
    if (_requirements == null) return [];

    List<AdmissionCourseRequirementModel> allCourses = [];
    for (var faculty in _requirements!) {
      if (_reqSelectedFacultyId != null && faculty.facultyId != _reqSelectedFacultyId) continue;
      if (faculty.requirements != null) {
        allCourses.addAll(faculty.requirements!.values);
      }
    }

    if (_reqSearchQuery.isEmpty) return allCourses;
    return allCourses.where((c) => c.courseName.toLowerCase().contains(_reqSearchQuery.toLowerCase())).toList();
  }

  List<AdmissionCutOffModel> get filteredCutOffs {
    if (_cutOffs == null) return [];

    List<AdmissionCutOffModel> allCourses = [];
    for (var faculty in _cutOffs!) {
      if (_cutSelectedFacultyId != null && faculty.facultyId != _cutSelectedFacultyId) continue;
      if (faculty.cutOffs != null) {
        allCourses.addAll(faculty.cutOffs!.values);
      }
    }

    if (_cutSearchQuery.isNotEmpty) {
      allCourses = allCourses.where((c) => c.courseName.toLowerCase().contains(_cutSearchQuery.toLowerCase())).toList();
    }

    return allCourses;
  }

  List<AdmissionFacultyModel> get requirementFaculties => _requirements ?? [];
  List<AdmissionFacultyModel> get cutOffFaculties => _cutOffs ?? [];

  void setReqSearchQuery(String query) {
    _reqSearchQuery = query;
    notifyListeners();
  }

  void setReqFaculty(String? facultyId) {
    _reqSelectedFacultyId = facultyId;
    notifyListeners();
  }

  void setCutSearchQuery(String query) {
    _cutSearchQuery = query;
    notifyListeners();
  }

  void setCutFaculty(String? facultyId) {
    _cutSelectedFacultyId = facultyId;
    notifyListeners();
  }

  void setSelectedState(String? state) {
    _selectedState = state;
    notifyListeners();
  }

  String? get selectedState => _selectedState;
  String? get reqSelectedFacultyId => _reqSelectedFacultyId;
  String? get cutSelectedFacultyId => _cutSelectedFacultyId;

  Future<void> loadRequirements(String institutionId) async {
    // Prevent fetching if we already have this specific school's data
    if (_requirements != null && _requirementsInstitutionId == institutionId) return;

    _isLoadingRequirements = true;
    _requirementsError = null;
    _requirementsInstitutionId = institutionId;
    notifyListeners();

    try {
      _requirements = await _service.fetchRequirements(institutionId);
      debugPrint('[AdmissionProvider] Loaded ${_requirements?.length ?? 0} requirement faculties for "$institutionId"');
      if (_requirements != null) {
        int totalCourses = 0;
        for (var f in _requirements!) {
          totalCourses += f.requirements?.length ?? 0;
        }
        debugPrint('[AdmissionProvider] Total requirement courses: $totalCourses');
      }
    } catch (e, s) {
      _requirementsError = e.toString();
      debugPrint('[AdmissionProvider] Error loading requirements: $e');
      debugPrint('[AdmissionProvider] Stack: $s');
    } finally {
      _isLoadingRequirements = false;
      notifyListeners();
    }
  }

  Future<void> loadCutOffs(String institutionId) async {
    if (_cutOffs != null && _cutOffsInstitutionId == institutionId) return;

    _isLoadingCutOffs = true;
    _cutOffsError = null;
    _cutOffsInstitutionId = institutionId;
    notifyListeners();

    try {
      _cutOffs = await _service.fetchCutOffs(institutionId);
      debugPrint('[AdmissionProvider] Loaded ${_cutOffs?.length ?? 0} cut-off faculties for "$institutionId"');
      if (_cutOffs != null) {
        int totalCourses = 0;
        for (var f in _cutOffs!) {
          totalCourses += f.cutOffs?.length ?? 0;
        }
        debugPrint('[AdmissionProvider] Total cut-off courses: $totalCourses');
      }
    } catch (e, s) {
      _cutOffsError = e.toString();
      debugPrint('[AdmissionProvider] Error loading cut-offs: $e');
      debugPrint('[AdmissionProvider] Stack: $s');
    } finally {
      _isLoadingCutOffs = false;
      notifyListeners();
    }
  }

  void retryRequirements(String institutionId) {
    _requirements = null;
    _requirementsInstitutionId = null;
    loadRequirements(institutionId);
  }

  void retryCutOffs(String institutionId) {
    _cutOffs = null;
    _cutOffsInstitutionId = null;
    loadCutOffs(institutionId);
  }
}