import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../models/eclassroom_models.dart';
import '../../services/eclassroom_service.dart';
import 'package:intl/intl.dart';
import 'dry_pdf_button.dart';
import 'widgets/eclassroom_shared_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/services/network_service.dart';

class AssignmentListScreen extends StatefulWidget {
  final String adminId;
  final String subject;
  const AssignmentListScreen({super.key, required this.adminId, required this.subject});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> with SingleTickerProviderStateMixin {
  final EClassroomService _classroomService = EClassroomService();
  TabController? _tabController;
  
  bool _isLoading = true;
  String? _errorMessage;
  
  List<Assignment> _allAssignments = [];
  Map<String, Map<String, dynamic>> _studentSubmissions = {}; // assignmentId -> submissionData

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final isOnline = NetworkService.instance.isOnline;
    if (!isOnline) {
      if (context.mounted) {
        CustomToast.show(context, 'No internet connection. Failed to refresh.', isError: true);
      }
      return;
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.uid ?? '';
      
      // 1. Fetch all classroom assignments
      final assignments = await _classroomService.getAssignments(widget.adminId);
      
      // 2. Fetch student submissions in parallel
      final Map<String, Map<String, dynamic>> submissions = {};
      final querySource = NetworkService.instance.isOnline ? Source.serverAndCache : Source.cache;
      final List<Future<void>> submissionFutures = assignments.map((assignment) async {
        final doc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(widget.adminId)
            .collection('assignments')
            .doc(assignment.id)
            .collection('submissions')
            .doc(studentId)
            .get(GetOptions(source: querySource));
        if (doc.exists && doc.data() != null) {
          submissions[assignment.id] = doc.data()!;
        }
      }).toList();

      await Future.wait(submissionFutures);

      if (mounted) {
        setState(() {
          _allAssignments = assignments;
          _studentSubmissions = submissions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final nowWAT = DateTime.now().toUtc().add(const Duration(hours: 1));

    final activeAssignments = _allAssignments.where((a) {
      if (a.subject.trim().toLowerCase() != widget.subject.trim().toLowerCase()) return false;
      final hasSubmitted = _studentSubmissions.containsKey(a.id);
      final dueDateWAT = a.dueDate.toUtc().add(const Duration(hours: 1));
      final isExpired = dueDateWAT.isBefore(nowWAT);
      return !hasSubmitted && !isExpired;
    }).toList();

    final completedAssignments = _allAssignments.where((a) {
      if (a.subject.trim().toLowerCase() != widget.subject.trim().toLowerCase()) return false;
      final hasSubmitted = _studentSubmissions.containsKey(a.id);
      final dueDateWAT = a.dueDate.toUtc().add(const Duration(hours: 1));
      final isExpired = dueDateWAT.isBefore(nowWAT);
      return hasSubmitted || isExpired;
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: Text(
                    '${widget.subject} Assignments',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  pinned: true,
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                  bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3.5,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Active'),
                      Tab(text: 'Completed & Past'),
                    ],
                  ),
                ),
              ];
            },
            body: _isLoading
                ? const CustomLoader()
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                'Failed to load assignments',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                onPressed: _loadData,
                                child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAssignmentsList(
                            activeAssignments,
                            isDark,
                            const EClassroomEmptyState(
                              icon: Icons.assignment_outlined,
                              message: 'No active assignments',
                            ),
                          ),
                          _buildAssignmentsList(
                            completedAssignments,
                            isDark,
                            const EClassroomEmptyState(
                              icon: Icons.history_rounded,
                              message: 'No completed or past assignments',
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList(List<Assignment> assignments, bool isDark, Widget emptyState) {
    if (assignments.isEmpty) {
      return emptyState;
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return _buildAssignmentCard(context, assignment, isDark);
        },
      ),
    );
  }

  Widget _buildAssignmentCard(BuildContext context, Assignment assignment, bool isDark) {
    final nowWAT = DateTime.now().toUtc().add(const Duration(hours: 1));
    final dueDateWAT = assignment.dueDate.toUtc().add(const Duration(hours: 1));
    final isOverdue = dueDateWAT.isBefore(nowWAT);
    final isText = assignment.contentType == 'text';
    final authProvider = context.watch<AuthProvider>();
    final uid = authProvider.currentUser?.uid ?? '';
    final displayName = authProvider.currentUser?.displayName ?? 'Student';
    final email = authProvider.currentUser?.email ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                  child: Text(
                    assignment.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOverdue ? 'Overdue' : 'Active',
                    style: TextStyle(
                      color: isOverdue ? Colors.red : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (assignment.description != null && assignment.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                assignment.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Due: ${DateFormat('MMM dd, yyyy - hh:mm a').format(assignment.dueDate.toUtc().add(const Duration(hours: 1)))} (WAT)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isText ? Colors.teal : Colors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isText ? Icons.article_rounded : Icons.picture_as_pdf_rounded,
                        size: 12,
                        color: isText ? Colors.teal : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isText ? 'Text' : 'PDF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isText ? Colors.teal : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Primary content viewer/downloader (DRY)
            isText
                ? SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        EClassroomTextContentViewer.show(
                          context,
                          title: assignment.title,
                          subject: assignment.subject,
                          description: assignment.description,
                          textContent: assignment.textContent ?? '',
                          dueDate: assignment.dueDate,
                        );
                      },
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('View Assignment Content', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  )
                : DryPdfButton(
                    pdfUrl: assignment.pdfUrl,
                    title: assignment.title,
                  ),
            const SizedBox(height: 12),
            _buildSubmissionArea(assignment, uid, displayName, email, isDark, isOverdue),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionArea(Assignment assignment, String uid, String displayName, String email, bool isDark, bool isOverdue) {
    final data = _studentSubmissions[assignment.id];
    final hasSubmitted = data != null;

    if (!hasSubmitted) {
      if (isOverdue) {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.shade300, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: Colors.red.shade300,
            ),
            onPressed: null, // Lock it down!
            icon: const Icon(Icons.lock_outline_rounded, size: 18),
            label: const Text(
              'Submission Closed (Deadline Passed)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            foregroundColor: AppColors.primary,
          ),
          onPressed: () {
            _showSubmissionSheet(assignment, uid, displayName, email).then((_) => _loadData());
          },
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text(
            'Submit Assignment Online',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      );
    }

    final status = data['status'] ?? 'submitted';
    final isGraded = status == 'graded';
    final grade = data['grade'] as String?;
    final feedback = data['feedback'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGraded
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGraded
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.orange.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGraded ? Icons.check_circle_rounded : Icons.watch_later_rounded,
                size: 16,
                color: isGraded ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                isGraded ? 'Graded' : 'Awaiting Grading',
                style: TextStyle(
                  color: isGraded ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (isGraded && grade != null && grade.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Grade: $grade',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (isGraded && feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Feedback from Admin:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feedback,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: isGraded ? Colors.green : Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: isGraded
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.08),
              ),
              onPressed: () => _showViewSubmissionSheet(data),
              icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
              label: const Text(
                'View My Submission',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubmissionSheet(Assignment assignment, String uid, String displayName, String email) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        List<File> selectedImages = [];
        final textController = TextEditingController();
        bool isSubmitting = false;
        const int maxImages = 10;

        return StatefulBuilder(
          builder: (context, setSheetState) {

            Future<void> pickFromCamera() async {
              try {
                if (selectedImages.length >= maxImages) {
                  if (context.mounted) {
                    CustomToast.show(context, 'Maximum $maxImages photos allowed.', isError: true);
                  }
                  return;
                }
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  final file = File(pickedFile.path);
                  final size = await file.length();
                  if (size > 5 * 1024 * 1024) {
                    if (context.mounted) {
                      CustomToast.show(context, 'Image file exceeds the 5MB size limit. Please choose a smaller file.', isError: true);
                    }
                    return;
                  }
                  setSheetState(() {
                    selectedImages.add(file);
                  });
                }
              } catch (e) {
                debugPrint('Error picking image: $e');
              }
            }

            Future<void> pickFromGallery() async {
              try {
                final picker = ImagePicker();
                final remaining = maxImages - selectedImages.length;
                if (remaining <= 0) {
                  if (context.mounted) {
                    CustomToast.show(context, 'Maximum $maxImages photos allowed.', isError: true);
                  }
                  return;
                }
                final pickedFiles = await picker.pickMultiImage();
                if (pickedFiles.isNotEmpty) {
                  final filesToAdd = pickedFiles.take(remaining);
                  final List<File> validFiles = [];
                  for (final picked in filesToAdd) {
                    final file = File(picked.path);
                    final size = await file.length();
                    if (size > 5 * 1024 * 1024) {
                      if (context.mounted) {
                        CustomToast.show(context, '"${picked.name}" exceeds 5MB and was skipped.', isError: true);
                      }
                      continue;
                    }
                    validFiles.add(file);
                  }
                  if (validFiles.isNotEmpty) {
                    setSheetState(() {
                      selectedImages.addAll(validFiles);
                    });
                  }
                  if (pickedFiles.length > remaining && context.mounted) {
                    CustomToast.show(context, 'Only $remaining more photo(s) allowed. Extra images were skipped.');
                  }
                }
              } catch (e) {
                debugPrint('Error picking images: $e');
              }
            }

            Future<void> submit() async {
              if (!NetworkService.instance.isOnline) {
                NetworkService.instance.showNoInternetHelper(context);
                return;
              }

              if (textController.text.trim().isEmpty && selectedImages.isEmpty) {
                CustomToast.show(context, 'Please type a response or attach homework photo(s).');
                return;
              }

              setSheetState(() {
                isSubmitting = true;
              });

              try {
                final List<String> attachmentUrls = [];

                for (int i = 0; i < selectedImages.length; i++) {
                  final ref = FirebaseStorage.instance
                      .ref()
                      .child('admins')
                      .child(widget.adminId)
                      .child('assignments')
                      .child(assignment.id)
                      .child('submissions')
                      .child(uid)
                      .child('attachment_$i.jpg');

                  final uploadTask = await ref.putFile(selectedImages[i]);
                  final url = await uploadTask.ref.getDownloadURL();
                  attachmentUrls.add(url);
                }

                await FirebaseFirestore.instance
                    .collection('admins')
                    .doc(widget.adminId)
                    .collection('assignments')
                    .doc(assignment.id)
                    .collection('submissions')
                    .doc(uid)
                    .set({
                  'studentUid': uid,
                  'studentName': displayName,
                  'studentEmail': email,
                  'textContent': textController.text.trim(),
                  'attachmentUrl': attachmentUrls.isNotEmpty ? attachmentUrls.first : null,
                  'attachmentUrls': attachmentUrls,
                  'submittedAt': FieldValue.serverTimestamp(),
                  'status': 'submitted',
                  'grade': null,
                  'feedback': null,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  CustomToast.show(context, 'Assignment submitted successfully online!');
                }
              } catch (e) {
                debugPrint('Error submitting assignment: $e');
                if (context.mounted) {
                  CustomToast.show(context, 'Submission failed: $e', isError: true);
                }
              } finally {
                setSheetState(() {
                  isSubmitting = false;
                });
              }
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.75,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                expand: false,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Submit Assignment',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          assignment.title,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Type Your Response:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: textController,
                          maxLines: 5,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            hintText: 'Type your answers or notes here...',
                            fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text(
                              'Attach Homework Photos (Max 5MB each):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              '${selectedImages.length}/$maxImages',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: selectedImages.length >= maxImages ? Colors.red : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Selected images grid
                        if (selectedImages.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...selectedImages.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final file = entry.value;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        image: DecorationImage(
                                          image: FileImage(file),
                                          fit: BoxFit.cover,
                                        ),
                                        border: Border.all(
                                          color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(9),
                                              topRight: Radius.circular(6),
                                            ),
                                          ),
                                          child: Text(
                                            '${idx + 1}',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: GestureDetector(
                                        onTap: isSubmitting ? null : () {
                                          setSheetState(() {
                                            selectedImages.removeAt(idx);
                                          });
                                        },
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              // Add more button in grid if not at limit
                              if (selectedImages.length < maxImages)
                                GestureDetector(
                                  onTap: isSubmitting ? null : pickFromGallery,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                        style: BorderStyle.solid,
                                        width: 1.5,
                                      ),
                                      color: AppColors.primary.withValues(alpha: 0.05),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 24),
                                        SizedBox(height: 4),
                                        Text('Add More', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: isSubmitting ? null : pickFromCamera,
                                  child: Container(
                                    height: 70,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                                        style: BorderStyle.solid,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                                        SizedBox(height: 4),
                                        Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: isSubmitting ? null : pickFromGallery,
                                  child: Container(
                                    height: 70,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                                        style: BorderStyle.solid,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.photo_library_rounded, color: AppColors.primary),
                                        SizedBox(height: 4),
                                        Text('Gallery (Multi)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isSubmitting ? null : submit,
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CustomLoader(size: 20, color: Colors.white),
                                  )
                                : const Text(
                                    'Submit Homework Online',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showViewSubmissionSheet(Map<String, dynamic> submissionData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final textContent = submissionData['textContent'] as String? ?? '';
        // Support both new multi-image field and legacy single-image field
        final List<String> attachmentUrls = [];
        if (submissionData['attachmentUrls'] != null && submissionData['attachmentUrls'] is List) {
          attachmentUrls.addAll((submissionData['attachmentUrls'] as List).cast<String>());
        } else {
          final legacyUrl = submissionData['attachmentUrl'] as String? ?? '';
          if (legacyUrl.isNotEmpty) attachmentUrls.add(legacyUrl);
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Your Submission Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (textContent.isNotEmpty) ...[
                      const Text(
                        'Your Text Response:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          textContent,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (attachmentUrls.isNotEmpty) ...[
                      Text(
                        'Your Photo Attachment${attachmentUrls.length > 1 ? 's (${attachmentUrls.length})' : ''}:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      ...attachmentUrls.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final url = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (attachmentUrls.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'Photo ${idx + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: InteractiveViewer(
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        height: 200,
                                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                        child: const CustomLoader(),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 120,
                                      color: Colors.red.withValues(alpha: 0.1),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 32),
                                            SizedBox(height: 8),
                                            Text('Could not load attachment.', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
