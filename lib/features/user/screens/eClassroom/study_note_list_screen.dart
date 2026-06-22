import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../models/eclassroom_models.dart';
import '../../services/eclassroom_service.dart';
import 'dry_pdf_button.dart';
import 'widgets/eclassroom_shared_widgets.dart';

class StudyNoteListScreen extends StatefulWidget {
  final String adminId;
  final String subject;
  const StudyNoteListScreen({super.key, required this.adminId, required this.subject});

  @override
  State<StudyNoteListScreen> createState() => _StudyNoteListScreenState();
}

class _StudyNoteListScreenState extends State<StudyNoteListScreen> {
  final EClassroomService _classroomService = EClassroomService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: Text(
                    '${widget.subject} Study Notes',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  pinned: true,
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                ),
              ];
            },
            body: StreamBuilder<List<StudyNote>>(
              stream: _classroomService.streamStudyNotes(widget.adminId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CustomLoader(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load study notes',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final notes = snapshot.data ?? [];
                final filteredNotes = notes.where((note) {
                  return note.subject.trim().toLowerCase() == widget.subject.trim().toLowerCase();
                }).toList();

                if (filteredNotes.isEmpty) {
                  return const EClassroomEmptyState(
                    icon: Icons.menu_book_outlined,
                    message: 'No study notes yet',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    return _buildNoteCard(context, note, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, StudyNote note, bool isDark) {
    final isText = note.contentType == 'text';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.5) : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.dividerDark : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Topic: ${note.topic}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Content type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isText ? Colors.teal : Colors.purple).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isText ? Icons.article_rounded : Icons.picture_as_pdf_rounded,
                        size: 12,
                        color: isText ? Colors.teal : Colors.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isText ? 'Text' : 'PDF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isText ? Colors.teal : Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (note.description != null && note.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isText
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        EClassroomTextContentViewer.show(
                          context,
                          title: note.title,
                          subject: note.subject,
                          topic: note.topic,
                          description: note.description,
                          textContent: note.textContent ?? '',
                        );
                      },
                      icon: const Icon(
                        Icons.visibility_rounded,
                        size: 18,
                      ),
                      label: const Text('View Notes'),
                    )
                  : DryPdfButton(
                      pdfUrl: note.pdfUrl,
                      title: note.title,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

