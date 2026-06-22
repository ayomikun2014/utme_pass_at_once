import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/features/user/providers/admission_provider.dart';
import 'package:utme_pass_at_once/features/user/models/admission_guideline_model.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/custom_loader.dart';

class AdmissionRequirementsScreen extends StatefulWidget {
  const AdmissionRequirementsScreen({super.key});

  @override
  State<AdmissionRequirementsScreen> createState() => _AdmissionRequirementsScreenState();
}

class _AdmissionRequirementsScreenState extends State<AdmissionRequirementsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late String _institutionId;
  bool _hasLoadedData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedData) {
      _hasLoadedData = true;
      // Retrieve institution ID from route arguments, default to 'oau'
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _institutionId = args?['institutionId'] ?? 'oau';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AdmissionProvider>().loadRequirements(_institutionId);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Admission Requirements',
                isLeading: true,
                centerTitle: true,
              ),
              SliverFillRemaining(
                child: Consumer<AdmissionProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoadingRequirements) {
                      return const Center(child: CustomLoader());
                    }

                    if (provider.requirementsError != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${provider.requirementsError}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => provider.retryRequirements(_institutionId),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final requirements = provider.filteredRequirements;

                    return Column(
                      children: [
                        _buildHeader(provider),
                        Expanded(
                          child: requirements.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: requirements.length,
                            itemBuilder: (context, index) {
                              return _buildCourseCard(requirements[index]);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AdmissionProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: isDark ? AppColors.dividerDark : AppColors.dividerLight)),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: provider.setReqSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search course name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  provider.setReqSearchQuery('');
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All Faculties',
                  isSelected: provider.reqSelectedFacultyId == null,
                  onSelected: (_) => provider.setReqFaculty(null),
                ),
                ...provider.requirementFaculties.map((faculty) {
                  return _buildFilterChip(
                    label: faculty.facultyName,
                    isSelected: provider.reqSelectedFacultyId == faculty.facultyId,
                    onSelected: (_) => provider.setReqFaculty(faculty.facultyId),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        checkmarkColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCourseCard(AdmissionCourseRequirementModel course) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          title: Text(
            course.courseName.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          subtitle: Text('Tap to view requirements', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          childrenPadding: const EdgeInsets.all(20),
          expandedAlignment: Alignment.topLeft,
          children: [
            _buildRequirementSection('UTME Requirements', course.utmeRequirements, AppColors.dynamicColors[0]),
            Divider(height: 30, color: theme.dividerColor.withValues(alpha: 0.5)),
            _buildRequirementSection('O\'Level Requirements', course.olevelRequirements, AppColors.dynamicColors[2]),
            Divider(height: 30, color: theme.dividerColor.withValues(alpha: 0.5)),
            _buildRequirementSection('Direct Entry Requirements', course.directEntryRequirements, AppColors.dynamicColors[4]),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementSection(String title, String content, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.playlist_add_check_rounded, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: TextStyle(height: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No courses found matching your criteria',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}