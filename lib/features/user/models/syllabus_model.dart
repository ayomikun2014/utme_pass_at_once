import 'package:hive/hive.dart';

part 'syllabus_model.g.dart';

@HiveType(typeId: 2) // Sequence: User=0, Questions=1, Syllabus=2
class SyllabusModel extends HiveObject {
  @HiveField(0)
  final String id; // Use Firestore document ID

  @HiveField(1)
  final String name; // e.g., 'WAEC English 2026'

  @HiveField(2)
  final String examType; // 'waec', 'jamb', 'neco'

  @HiveField(3)
  final String storagePath; // Path inside Firebase Storage (e.g., 'syllabus/waec/eng.pdf')

  @HiveField(4)
  String localEncryptedPath; // If downloaded, path to the encrypted file

  @HiveField(5)
  bool isDownloaded;

  SyllabusModel({
    required this.id,
    required this.name,
    required this.examType,
    required this.storagePath,
    this.localEncryptedPath = '',
    this.isDownloaded = false,
  });

  // Factory to create from Firestore document
  factory SyllabusModel.fromMap(Map<String, dynamic> data, String docId) {
    return SyllabusModel(
      id: docId,
      name: data['name'] ?? '',
      examType: data['examType'] ?? 'jamb',
      storagePath: data['storagePath'] ?? '',
    );
  }
}