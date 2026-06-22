class AdmissionFacultyModel {
  final String facultyId;
  final String facultyName;
  final Map<String, AdmissionCourseRequirementModel>? requirements;
  final Map<String, AdmissionCutOffModel>? cutOffs;

  AdmissionFacultyModel({
    required this.facultyId,
    required this.facultyName,
    this.requirements,
    this.cutOffs,
  });

  factory AdmissionFacultyModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AdmissionFacultyModel(
      facultyId: id,
      facultyName: data['facultyName'] ?? 'Unknown Faculty',
    );
  }
}

class AdmissionCourseRequirementModel {
  final String courseName;
  final String utmeRequirements;
  final String olevelRequirements;
  final String directEntryRequirements;

  AdmissionCourseRequirementModel({
    required this.courseName,
    required this.utmeRequirements,
    required this.olevelRequirements,
    required this.directEntryRequirements,
  });

  factory AdmissionCourseRequirementModel.fromMap(Map<String, dynamic> map) {
    return AdmissionCourseRequirementModel(
      courseName: map['courseName']?.toString() ?? 'Unknown Course',
      utmeRequirements: map['utmeRequirements']?.toString() ?? 'Not provided',
      olevelRequirements: map['olevelRequirements']?.toString() ?? 'Not provided',
      directEntryRequirements: map['directEntryRequirements']?.toString() ?? 'Not provided',
    );
  }
}

class AdmissionCutOffModel {
  final String courseName;
  final String merit;
  final Map<String, String> catchment;
  final String elds;

  AdmissionCutOffModel({
    required this.courseName,
    required this.merit,
    required this.catchment,
    required this.elds,
  });

  factory AdmissionCutOffModel.fromMap(Map<String, dynamic> map) {
    final catchmentRaw = map['catchment'] as Map<String, dynamic>? ?? {};
    final catchment = catchmentRaw.map((key, value) => MapEntry(key, value.toString()));
    
    return AdmissionCutOffModel(
      courseName: map['courseName']?.toString() ?? 'Unknown Course',
      merit: map['merit']?.toString() ?? 'Not provided',
      catchment: catchment,
      elds: map['elds']?.toString() ?? 'Not provided',
    );
  }
}
