import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/features/user/providers/admission_provider.dart';
import 'package:utme_pass_at_once/features/user/models/admission_guideline_model.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/custom_loader.dart';

class AdmissionCutOffsScreen extends StatefulWidget {
  const AdmissionCutOffsScreen({super.key});

  @override
  State<AdmissionCutOffsScreen> createState() => _AdmissionCutOffsScreenState();
}

class _AdmissionCutOffsScreenState extends State<AdmissionCutOffsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late String _institutionId;
  bool _hasLoadedData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedData) {
      _hasLoadedData = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _institutionId = args?['institutionId'] ?? 'oau';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AdmissionProvider>().loadCutOffs(_institutionId);
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Cut Off Marks',
                isLeading: true,
                centerTitle: true,
              ),
              SliverFillRemaining(
                child: Consumer<AdmissionProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoadingCutOffs) {
                      return const Center(child: CustomLoader());
                    }

                    if (provider.cutOffsError != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error: ${provider.cutOffsError}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => provider.retryCutOffs(_institutionId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final cutOffs = provider.filteredCutOffs;

                    return Column(
                      children: [
                        _buildHeader(provider),
                        Expanded(
                          child: cutOffs.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                                  itemCount: cutOffs.length,
                                  itemBuilder: (context, index) {
                                    return _buildCutOffCard(cutOffs[index]);
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: provider.setCutSearchQuery,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search courses...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.setCutSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48,
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.cutSelectedFacultyId,
                isExpanded: true,
                icon: Icon(Icons.filter_list_rounded, color: theme.colorScheme.primary, size: 20),
                hint: Text(
                  'Faculties',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                selectedItemBuilder: (BuildContext context) {
                  return [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'All Faculties',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    ...provider.cutOffFaculties.map((faculty) {
                      return DropdownMenuItem<String>(
                        value: faculty.facultyId,
                        child: Text(
                          faculty.facultyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    }),
                  ];
                },
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Faculties',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...provider.cutOffFaculties.map((faculty) {
                    return DropdownMenuItem<String>(
                      value: faculty.facultyId,
                      child: Text(
                        faculty.facultyName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: provider.setCutFaculty,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCutOffCard(AdmissionCutOffModel cutOff) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.trending_up_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            title: Text(
              cutOff.courseName.toUpperCase(),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildCutOffStat('MERIT', cutOff.merit, AppColors.dynamicColors[0]),
                  _buildCutOffStat('ELDS', cutOff.elds, AppColors.dynamicColors[3]),
                ],
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            expandedAlignment: Alignment.topLeft,
            children: [
              const SizedBox(height: 12),
              Text(
                'Catchment State Cut Offs',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 10),
              if (cutOff.catchment.isEmpty)
                Text(
                  'No state catchment cut-off marks specified.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cutOff.catchment.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${entry.key.toUpperCase()}: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            entry.value,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCutOffStat(String label, String value, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isDark ? color.withValues(alpha: 0.7) : color,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isDark ? color.withValues(alpha: 0.9) : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No cut off marks found matching your criteria',
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}