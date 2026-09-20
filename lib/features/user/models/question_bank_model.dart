import 'question_model.dart';

// =============================================================================
// INSTITUTION MODEL
// =============================================================================

/// Firestore document: questionBank/{examType}/institutions/{institutionId}
class InstitutionModel {
  final String id;
  final String name;
  final String? logo;
  final int totalSubjects;

  InstitutionModel({
    required this.id,
    required this.name,
    this.logo,
    this.totalSubjects = 0,
  });

  factory InstitutionModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return InstitutionModel(
      id: (data['id'] ?? documentId).toString().toLowerCase(),
      name: (data['name'] ?? documentId.toUpperCase()).toString(),
      logo: data['logo']?.toString(),
      totalSubjects: (data['totalSubjects'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
      'totalSubjects': totalSubjects,
    };
  }
}

// =============================================================================
// SUBJECT MODEL
// =============================================================================

/// Firestore document: .../institutions/{institutionId}/subjects/{subjectId}
class SubjectModel {
  final String id;
  final String name;
  final int totalYears;
  final List<String> sectionIds;
  final List<String> sectionNames;

  SubjectModel({
    required this.id,
    required this.name,
    this.totalYears = 0,
    this.sectionIds = const [],
    this.sectionNames = const [],
  });

  factory SubjectModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    // Handle both new arrays and legacy single string field
    List<String> parsedSectionIds = [];
    if (data['sectionIds'] is List) {
      parsedSectionIds = List<String>.from(data['sectionIds']);
    } else if (data['sectionId'] != null) {
      parsedSectionIds = [data['sectionId'].toString()];
    }

    List<String> parsedSectionNames = [];
    if (data['sectionNames'] is List) {
      parsedSectionNames = List<String>.from(data['sectionNames']);
    } else if (data['sectionName'] != null) {
      parsedSectionNames = [data['sectionName'].toString()];
    }

    return SubjectModel(
      id: (data['id'] ?? documentId).toString().toLowerCase(),
      name: (data['name'] ?? documentId).toString(),
      totalYears: (data['totalYears'] as num?)?.toInt() ?? 0,
      sectionIds: parsedSectionIds,
      sectionNames: parsedSectionNames,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'totalYears': totalYears,
      'sectionIds': sectionIds,
      'sectionNames': sectionNames,
    };
  }

  bool belongsToSection(String sectionId) {
    if (sectionIds.isEmpty) return true; // Legacy subjects belong everywhere unless specified
    return sectionIds.contains(sectionId);
  }
}

// =============================================================================
// YEAR MODEL
// =============================================================================

/// Firestore document: .../subjects/{subjectId}/years/{year}
///
/// The `questions` field is a Map of question objects.
class YearModel {
  final int year;
  final bool hasImage;
  final int totalQuestions;
  final List<Map<String, dynamic>> rawQuestions;
  final Map<String, Passage> passages;
  final Map<String, Instruction> instructions;

  YearModel({
    required this.year,
    this.hasImage = false,
    this.totalQuestions = 0,
    this.rawQuestions = const [],
    this.passages = const {},
    this.instructions = const {},
  });

  factory YearModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final rawQuestionsData = data['questions'];
    final List<Map<String, dynamic>> parsedQuestions = [];

    if (rawQuestionsData is Map) {
      final entries = rawQuestionsData.entries.toList();
      
      // Attempt to sort by question number
      entries.sort((a, b) {
        final aNum = (a.value is Map) ? ((a.value['number'] as num?)?.toInt() ?? 0) : 0;
        final bNum = (b.value is Map) ? ((b.value['number'] as num?)?.toInt() ?? 0) : 0;
        return aNum.compareTo(bNum);
      });

      for (final entry in entries) {
        if (entry.value is Map) {
          parsedQuestions.add(Map<String, dynamic>.from(entry.value));
        }
      }
    } else if (rawQuestionsData is List) {
      // Fallback if data is still a list for any reason
      parsedQuestions.addAll(
        rawQuestionsData
            .whereType<Map<String, dynamic>>()
            .map((q) => Map<String, dynamic>.from(q)),
      );
    }

    final Map<String, Passage> parsedPassages = {};
    if (data['passages'] is List) {
      for (final pItem in (data['passages'] as List)) {
        if (pItem is Map) {
          final pMap = Map<String, dynamic>.from(pItem);
          final passage = Passage.fromJson(pMap);
          parsedPassages[passage.id] = passage;
        }
      }
    }

    final Map<String, Instruction> parsedInstructions = {};
    if (data['instructions'] is List) {
      for (final iItem in (data['instructions'] as List)) {
        if (iItem is Map) {
          final iMap = Map<String, dynamic>.from(iItem);
          final instruction = Instruction.fromJson(iMap);
          parsedInstructions[instruction.id] = instruction;
        }
      }
    }

    return YearModel(
      year: (data['year'] as num?)?.toInt() ?? int.tryParse(documentId) ?? 0,
      hasImage: data['hasImage'] as bool? ?? false,
      totalQuestions:
          (data['totalQuestions'] as num?)?.toInt() ?? parsedQuestions.length,
      rawQuestions: parsedQuestions,
      passages: parsedPassages,
      instructions: parsedInstructions,
    );
  }
}
