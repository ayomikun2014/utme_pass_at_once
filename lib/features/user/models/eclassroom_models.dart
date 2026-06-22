class ClassroomTest {
  final String id;
  final String title;
  final String subject;
  final int totalQuestions;
  final int durationMinutes;
  final String instructions;
  final DateTime deadline;
  final DateTime createdAt;

  ClassroomTest({
    required this.id,
    required this.title,
    required this.subject,
    required this.totalQuestions,
    required this.durationMinutes,
    required this.instructions,
    required this.deadline,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'totalQuestions': totalQuestions,
      'durationMinutes': durationMinutes,
      'instructions': instructions,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ClassroomTest.fromMap(Map<String, dynamic> map) {
    return ClassroomTest(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      totalQuestions: map['totalQuestions'] ?? 0,
      durationMinutes: map['durationMinutes'] ?? 0,
      instructions: map['instructions'] ?? '',
      deadline: DateTime.tryParse(map['deadline'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class Assignment {
  final String id;
  final String title;
  final String subject;
  final String? description;
  final String contentType; // 'pdf' or 'text'
  final String? textContent;
  final String pdfUrl;
  final String? pdfFileName;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Assignment({
    required this.id,
    required this.title,
    required this.subject,
    this.description,
    this.contentType = 'pdf',
    this.textContent,
    required this.dueDate,
    required this.pdfUrl,
    this.pdfFileName,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'contentType': contentType,
      'textContent': textContent,
      'pdfUrl': pdfUrl,
      'pdfFileName': pdfFileName,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      description: map['description'],
      contentType: map['contentType'] ?? 'pdf',
      textContent: map['textContent'],
      pdfUrl: map['pdfUrl'] ?? '',
      pdfFileName: map['pdfFileName'],
      dueDate: DateTime.tryParse(map['dueDate'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }
}

class StudyNote {
  final String id;
  final String title;
  final String subject;
  final String topic;
  final String? description;
  final String contentType; // 'pdf' or 'text'
  final String? textContent;
  final String pdfUrl;
  final String? pdfFileName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StudyNote({
    required this.id,
    required this.title,
    required this.subject,
    required this.topic,
    this.description,
    this.contentType = 'pdf',
    this.textContent,
    required this.pdfUrl,
    this.pdfFileName,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'topic': topic,
      'description': description,
      'contentType': contentType,
      'textContent': textContent,
      'pdfUrl': pdfUrl,
      'pdfFileName': pdfFileName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory StudyNote.fromMap(Map<String, dynamic> map) {
    return StudyNote(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      topic: map['topic'] ?? '',
      description: map['description'],
      contentType: map['contentType'] ?? 'pdf',
      textContent: map['textContent'],
      pdfUrl: map['pdfUrl'] ?? '',
      pdfFileName: map['pdfFileName'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }
}

class Notice {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isUnread;
  final bool isPinned;

  Notice({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isUnread,
    this.isPinned = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isUnread': isUnread,
      'isPinned': isPinned,
    };
  }

  factory Notice.fromMap(Map<String, dynamic> map) {
    return Notice(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      isUnread: map['isUnread'] ?? false,
      isPinned: map['isPinned'] ?? false,
    );
  }
}

class LeaderboardEntry {
  final String studentId;
  final String name;
  final String avatarUrl;
  final int totalScore;
  final int rank;
  final bool isCurrentUser;
  final int testsTaken;

  LeaderboardEntry({
    required this.studentId,
    required this.name,
    required this.avatarUrl,
    required this.totalScore,
    required this.rank,
    this.isCurrentUser = false,
    this.testsTaken = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'name': name,
      'avatarUrl': avatarUrl,
      'totalScore': totalScore,
      'rank': rank,
      'isCurrentUser': isCurrentUser,
      'testsTaken': testsTaken,
    };
  }

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      studentId: map['studentId'] ?? '',
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      totalScore: map['totalScore'] ?? 0,
      rank: map['rank'] ?? 0,
      isCurrentUser: map['isCurrentUser'] ?? false,
      testsTaken: map['testsTaken'] ?? 0,
    );
  }
}
