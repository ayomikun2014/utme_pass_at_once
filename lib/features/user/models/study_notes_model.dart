/// A study note: one subject, one PDF.
///
/// Notes used to come in two shapes -- a PDF per subject, and an older format
/// of inline topics built from paragraphs, bullets, LaTeX and tables. Only the
/// PDFs are shown now, so the topic types have gone, along with the Firebase
/// Storage path that went with them: the file is fetched from its URL.
class StudySubjectModel {
  final String subjectId;
  final String subjectName;
  final String? fileUrl;

  StudySubjectModel({
    required this.subjectId,
    required this.subjectName,
    this.fileUrl,
  });

  factory StudySubjectModel.fromMap(Map<String, dynamic> map, String id) {
    return StudySubjectModel(
      subjectId: id,
      subjectName: map['subjectName'] ?? map['name'] ?? 'Unknown Subject',
      fileUrl: map['fileUrl'],
    );
  }
}
