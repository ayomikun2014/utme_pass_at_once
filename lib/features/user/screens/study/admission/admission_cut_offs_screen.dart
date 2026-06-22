import 'package:flutter/material.dart';
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
      // Retrieve institution ID from route arguments, default to 'oau'
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${provider.cutOffsError}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => provider.retryCutOffs(_institutionId),
                              child: const Text('Retry'),
                            ),
                          ],
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
                            padding: const EdgeInsets.all(16),
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
            onChanged: provider.setCutSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search course name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  provider.setCutSearchQuery('');
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: provider.cutSelectedFacultyId,
                hint: const Text('All Faculties'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Faculties'),
                  ),
                  ...provider.cutOffFaculties.map((faculty) {
                    return DropdownMenuItem<String>(
                      value: faculty.facultyId,
                      child: Text(faculty.facultyName),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cutOff.courseName.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCutOffStat('MERIT', cutOff.merit, AppColors.dynamicColors[0]),
                const SizedBox(width: 12),
                _buildCutOffStat('ELDS', cutOff.elds, AppColors.dynamicColors[3]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCutOffStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
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
            'No cut off marks found matching your criteria',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}