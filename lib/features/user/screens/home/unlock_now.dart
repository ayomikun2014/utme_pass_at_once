import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';

import '../../providers/simulator_provider.dart';
import 'package:utme_pass_at_once/core/utils/bg.dart';
import 'package:utme_pass_at_once/core/utils/custom_app_bar.dart';
import 'package:utme_pass_at_once/core/utils/custom_btn.dart';
import 'package:utme_pass_at_once/core/utils/hero_card.dart';
import 'package:utme_pass_at_once/core/utils/custom_toast.dart';

import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';
import 'package:utme_pass_at_once/features/auth/models/user_model.dart';
import '../../providers/unlock_provider.dart';
import '../../providers/voucher_provider.dart';
import '../../services/unlock_service.dart';
import '../../utils/activation_bottom_sheet.dart';

class UnlockNow extends StatefulWidget {
  const UnlockNow({super.key});

  @override
  State<UnlockNow> createState() => _UnlockNowState();
}

class _UnlockNowState extends State<UnlockNow>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final UnlockService _unlockService = UnlockService();
  late AnimationController _animController;

  Map<String, Map<String, dynamic>> _centerData = {};
  String _lastFetchedExamType = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UnlockProvider>().resetUnlockState();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _getDisplayCenterName(String centerCode) {
    final data = _centerData[centerCode.toLowerCase()];
    if (data != null && data['name'] != null) {
      return data['name'].toString();
    }
    return centerCode.toUpperCase();
  }

  String? _getDisplayCenterLogo(String centerCode) {
    final data = _centerData[centerCode.toLowerCase()];
    if (data != null && data['logo'] != null) {
      return data['logo'].toString();
    }
    return null;
  }

  // Kept for visual reference only (e.g. graying out owned subjects temporarily)
  List<String> _getOwnedSubjectsSafely(
      UserModel? user,
      String examType,
      String center, {
        String? sectionId,
      }) {
    if (user == null) return [];

    try {
      final selections = user.examSelections;
      final normalizedExamType = examType.toLowerCase().trim();

      for (final key in selections.keys) {
        if (key.toString().toLowerCase().trim() == normalizedExamType) {
          final examData = selections[key];

          if (examData is Map && examData['institutions'] != null) {
            final centersMap = examData['institutions'] as Map;

            final centerKey = sectionId != null && sectionId.trim().isNotEmpty
                ? '${center.toLowerCase().trim()}_${sectionId.toLowerCase().trim()}'
                : center.toLowerCase().trim();

            for (final cKey in centersMap.keys) {
              if (cKey.toString().toLowerCase().trim() == centerKey) {
                final cData = centersMap[cKey];

                if (cData is Map) {
                  final dynamic rawSubjects = cData['initialSubjectsFallback'] ?? cData['subjects'];
                  if (rawSubjects != null && rawSubjects is List) {
                    return rawSubjects
                        .map((e) => e.toString().toLowerCase().trim())
                        .toList();
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Safe Read Error: $e");
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<UnlockProvider>(
      builder: (context, provider, child) {
        if (provider.examType.isNotEmpty &&
            provider.examType != _lastFetchedExamType) {
          _lastFetchedExamType = provider.examType;
          _unlockService.getInstitutionNameMapping(provider.examType).then((
              mapping,
              ) {
            if (mounted) {
              setState(() => _centerData = mapping);
              _animController.forward(from: 0);
            }
          });
        }

        Widget currentStep;
        String title = 'Unlock Now';
        String subtitle = 'Activate your premium package';

        if (provider.isActivationComplete) {
          currentStep = _buildSuccessStep();
          title = 'Success';
          subtitle = 'Package unlocked';
        } else if (provider.selectedCenter.isNotEmpty) {
          if (provider.isPostUtme) {
            currentStep = _buildSectionSelectionStep(
              provider,
              authProvider,
              theme,
              isDark,
            );
            title = 'Select Section';
            subtitle =
            'Choose Science or Art & Commerce for ${_getDisplayCenterName(provider.selectedCenter)}';
          } else {
            currentStep = _buildSubjectSelectionStep(
              provider,
              authProvider,
              theme,
              isDark,
            );
            title = 'Select Subjects';
            subtitle =
            'Pick up to ${provider.maxSubjects} subjects for ${_getDisplayCenterName(provider.selectedCenter)}';
          }
        } else if (provider.availableCenters.isNotEmpty) {
          currentStep = _buildCenterSelectionStep(provider, theme, isDark);
          if (provider.isPostUtme) {
            title = 'Select Institution';
            subtitle = 'Choose your preferred institution';
          } else {
            title = 'Select Center';
            subtitle = 'Choose your preferred exam center';
          }
        } else {
          currentStep = _buildPinEntryStep(provider, theme, isDark);
        }

        return Scaffold(
          body: Stack(
            children: [
              const BlobBackground(),
              CustomScrollView(
                slivers: [
                  CustomAppBar(
                    title: title,
                    subtitle: subtitle,
                    isLeading: true,
                    centerTitle: true,
                    onLeadingPressed: () {
                      if (provider.selectedCenter.isNotEmpty) {
                        provider.resetCenterSelection();
                      } else if (provider.availableCenters.isNotEmpty) {
                        provider.resetUnlockState();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    sliver:
                    currentStep is SliverList ||
                        currentStep is SliverGrid ||
                        currentStep is SliverPadding ||
                        currentStep is SliverToBoxAdapter
                        ? currentStep
                        : SliverToBoxAdapter(child: currentStep),
                  ),
                ],
              ),
              if (provider.selectedCenter.isNotEmpty &&
                  !provider.isPostUtme &&
                  !provider.isActivationComplete)
                _buildStickyBottom(provider, authProvider, theme, isDark),
            ],
          ),
        );
      },
    );
  }

  // --- STEP 1: PIN ENTRY ---
  Widget _buildSectionSelectionStep(
      UnlockProvider provider,
      AuthProvider authProvider,
      ThemeData theme,
      bool isDark,
      ) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildSectionCard(
            context: context,
            title: 'Science',
            icon: Icons.science_rounded,
            color: const Color(0xFF2563EB), // Unified Cobalt Blue
            description:
            'Unlock Physics, Chemistry, Biology, Mathematics and Aptitude Test.',
            isSelected: provider.selectedSectionId == 'science',
            onTap: () => _handleSectionUnlock(
              provider,
              authProvider,
              'science',
              'Science',
            ),
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Art and Commerce',
            icon: Icons.account_balance_rounded,
            color: const Color(0xFF7C3AED), // Unified Royal Violet
            description:
            'Unlock Government, Literature, Economics, Commerce, Mathematics and Aptitude Test.',
            isSelected: provider.selectedSectionId == 'art_commerce',
            onTap: () => _handleSectionUnlock(
              provider,
              authProvider,
              'art_commerce',
              'Art and Commerce',
            ),
            theme: theme,
            isDark: isDark,
          ),
        ]),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF1E2330) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? Colors.white30 : Colors.black26,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSectionUnlock(
      UnlockProvider provider,
      AuthProvider authProvider,
      String sectionId,
      String sectionName,
      ) async {
    // Show a basic loading dialog while fetching section subjects
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CustomLoader(),
              ),
              const SizedBox(height: 24),
              Text(
                "Loading Subjects...",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Please wait while we load exam details.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    try {
      await provider.selectSection(sectionId, sectionName);
      if (!mounted) return;
      Navigator.pop(context); // hide loading dialog

      if (provider.errorMessage.isEmpty) {
        // Show confirmation dialog before proceeding
        final confirmed = await _showConfirmationDialog(
          provider: provider,
          sectionName: sectionName,
        );
        if (!mounted || confirmed != true) return;
        _processUnlock(context, provider, authProvider);
      } else {
        CustomToast.show(context, provider.errorMessage, isError: true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // hide loading dialog
        CustomToast.show(context, 'Error: $e', isError: true);
      }
    }
  }

  Widget _buildPinEntryStep(
      UnlockProvider provider,
      ThemeData theme,
      bool isDark,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HeroCard(
          title: 'Got a Code?',
          subTitle: 'Enter your activation code below to verify your voucher.',
          icon: Icons.vpn_key_rounded,
        ),
        const SizedBox(height: 32),
        AbsorbPointer(
          absorbing: provider.isLoading,
          child: _buildStylizedPinInput(theme, isDark),
        ),
        if (provider.errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              provider.errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 20),
        CustomBtn(
          label: provider.isLoading ? 'Verifying...' : 'Verify Pin',
          onPressed: provider.isLoading
              ? null
              : () {
            FocusManager.instance.primaryFocus?.unfocus();
            provider.validateCode(_pinController.text);
          },
        ),
        const SizedBox(height: 30),
        _buildHelpCard(provider, theme, isDark),
      ],
    );
  }

  Widget _buildStylizedPinInput(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'ACTIVATION PIN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2330) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _pinController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
            decoration: InputDecoration(
              hintText: 'UTME-XXXX-XXXX',
              hintStyle: TextStyle(
                color: Colors.grey.withValues(alpha: 0.4),
                fontSize: 18,
                letterSpacing: 1.0,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.confirmation_number_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: CENTER SELECTION (GRID) ---
  Widget _buildCenterSelectionStep(
      UnlockProvider provider,
      ThemeData theme,
      bool isDark,
      ) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final center = provider.availableCenters[index];
        return _CenterCard(
          index: index,
          centerCode: center,
          displayName: _getDisplayCenterName(center),
          imagePath: _getDisplayCenterLogo(center) ?? '',
          isPremium: true,
          isUnlocked: false,
          isSelectable: true,
          animController: _animController,
          onTap: () {
            provider.selectCenter(center);
            _animController.forward(from: 0);
          },
        );
      }, childCount: provider.availableCenters.length),
    );
  }

  // --- STEP 3: SUBJECT SELECTION (SEARCHABLE GRID) ---
  Widget _buildSubjectSelectionStep(
      UnlockProvider provider,
      AuthProvider authProvider,
      ThemeData theme,
      bool isDark,
      ) {
    final ownedSubjects = _getOwnedSubjectsSafely(
      authProvider.currentUser,
      provider.examType,
      provider.selectedCenter,
    );

    final filteredSubjects = provider.availableSubjects
        .where((s) => s.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2330) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search subjects...',
              border: InputBorder.none,
              icon: Icon(
                Icons.search_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select up to ${provider.maxSubjects} Subjects',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: provider.isValidSubjectCount
                    ? Colors.green.withValues(alpha: 0.1)
                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${provider.selectedSubjects.length}/${provider.maxSubjects}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: provider.isValidSubjectCount
                      ? Colors.green
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: filteredSubjects.length,
          itemBuilder: (context, index) {
            final subject = filteredSubjects[index];
            final normalizedSub = subject.toLowerCase();
            final isOwned = ownedSubjects.contains(normalizedSub);
            final isSelected = provider.isSubjectSelected(subject);

            return InkWell(
              onTap: provider.isLoading
                  ? null
                  : () {
                // We removed the hard block here. If they tap an owned subject
                // but their subscription expired, the backend validation will
                // handle it safely during _processUnlock.
                provider.toggleSubject(subject);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isOwned
                      ? (isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.grey.withValues(alpha: 0.05))
                      : (isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : (isDark
                      ? const Color(0xFF1E2330)
                      : Colors.white)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05)),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        isOwned
                            ? Icons.lock_rounded
                            : (isSelected
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded),
                        size: 18,
                        color: isOwned
                            ? Colors.grey
                            : (isSelected
                            ? theme.colorScheme.primary
                            : Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isOwned
                                ? Colors.grey
                                : (isSelected
                                ? theme.colorScheme.primary
                                : null),
                            decoration: isOwned
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildStickyBottom(
      UnlockProvider provider,
      AuthProvider authProvider,
      ThemeData theme,
      bool isDark,
      ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2330) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.selectedSubjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: provider.selectedSubjects
                        .map(
                          (s) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ),
              ),
            CustomBtn(
              label: 'Unlock Selected Subjects',
              onPressed: provider.isValidSubjectCount && !provider.isLoading
                  ? () async {
                      final confirmed = await _showConfirmationDialog(
                        provider: provider,
                      );
                      if (!mounted || confirmed != true) return;
                      _processUnlock(context, provider, authProvider);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 4: SUCCESS ---
  Widget _buildSuccessStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
        const SizedBox(height: 20),
        const Text(
          'Activation Successful!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Your new subjects have been added to your library.\nYou can now access them in the simulator.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        CustomBtn(label: 'Finish', onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  /// Shows a premium confirmation dialog summarising the unlock details.
  Future<bool?> _showConfirmationDialog({
    required UnlockProvider provider,
    String? sectionName,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final institutionName = _getDisplayCenterName(provider.selectedCenter);
    final examType = provider.examType.toUpperCase();
    final subjects = provider.selectedSubjects;
    final displaySection = sectionName ?? provider.selectedSectionName;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? const Color(0xFF1E2330) : Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Confirm Activation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Please confirm the details below before using your activation code:',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),

              // Institution
              _buildConfirmRow(
                theme: theme,
                isDark: isDark,
                icon: Icons.school_rounded,
                label: 'Institution',
                value: institutionName,
              ),
              const SizedBox(height: 12),

              // Exam Type
              _buildConfirmRow(
                theme: theme,
                isDark: isDark,
                icon: Icons.category_rounded,
                label: 'Exam Type',
                value: examType,
              ),

              // Section (Post-UTME only)
              if (displaySection.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildConfirmRow(
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.bookmark_rounded,
                  label: 'Section',
                  value: displaySection,
                  valueColor: const Color(0xFF8B5CF6),
                ),
              ],

              // Subjects (JAMB / non-Post-UTME)
              if (subjects.isNotEmpty && !provider.isPostUtme) ...[
                const SizedBox(height: 12),
                _buildConfirmRow(
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.menu_book_rounded,
                  label: 'Subjects',
                  value: subjects.join(', '),
                ),
              ],

              const SizedBox(height: 20),

              // Warning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. Your code will be redeemed for the selection above.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Go Back',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Confirm & Unlock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Helper row used inside the confirmation dialog.
  Widget _buildConfirmRow({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 5. show dailog
  void _processUnlock(
      BuildContext context,
      UnlockProvider provider,
      AuthProvider authProvider,
      ) async {
    final examType = provider.examType;
    final institutionId = provider.selectedCenter;

    final sectionId = provider.isPostUtme
        ? provider.selectedSectionId
        : null;

    final GlobalKey<ActivationBottomSheetState> sheetKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ActivationBottomSheet(
        key: sheetKey,
        isUnlockFlow: true,
        task: () async {
          final voucherProvider = context.read<VoucherProvider>();
          final simProvider = context.read<SimulatorProvider>();

          // 1. Activate voucher
          final success = await provider.unlockExam(authProvider);
          if (!success) {
            throw Exception(provider.errorMessage.isNotEmpty ? provider.errorMessage : 'Activation failed.');
          }

          // 2. Fetch purchases (Backend function already handles creating/sending the activation notification)
          await voucherProvider.fetchUserPurchases(authProvider.currentUser!.uid);


          // 3. Advance UI to progress bar
          sheetKey.currentState?.advanceToActivation();

          // 4. Download Activation Data
          final downloadSuccess = await simProvider.downloadActivationData(
            examType: examType,
            institutionId: institutionId,
            sectionId: sectionId,
          );

          if (!downloadSuccess) {
            throw Exception('Failed to download study materials. You can try redownloading later.');
          }

          return true;
        },
        onComplete: () {
          debugPrint('⚡ [UNLOCK] ✅ All activation data processed!');
          // Sheet popped itself upon success confirmation
        },
      ),
    );
  }

  Widget _buildHelpCard(UnlockProvider provider, ThemeData theme, bool isDark) {
    String step3Text = 'Select your center and subjects to unlock.';
    if (provider.examType.isNotEmpty) {
      if (provider.examType.toLowerCase() == 'post_utme') {
        step3Text = 'Select your preferred institution and section to unlock.';
      } else {
        step3Text = 'Select your preferred subjects to unlock.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2330)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to Unlock',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildHelpStep(
            '1',
            'Purchase an activation PIN from our online store.',
            theme,
          ),
          _buildHelpStep('2', 'Enter the PIN in the input field above.', theme),
          _buildHelpStep('3', step3Text, theme),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SUB-WIDGETS ---
class _CenterCard extends StatefulWidget {
  final int index;
  final String centerCode;
  final String displayName;
  final String imagePath;
  final bool isPremium;
  final bool isUnlocked;
  final bool isSelectable;
  final AnimationController animController;
  final VoidCallback onTap;

  const _CenterCard({
    required this.index,
    required this.centerCode,
    required this.displayName,
    required this.imagePath,
    required this.isPremium,
    required this.isUnlocked,
    required this.isSelectable,
    required this.animController,
    required this.onTap,
  });

  @override
  State<_CenterCard> createState() => _CenterCardState();
}

class _CenterCardState extends State<_CenterCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final delay = (widget.index * 0.07).clamp(0.0, 0.6);
    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: widget.animController,
        curve: Interval(
          delay,
          (delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );

    return FadeTransition(
      opacity: fadeAnim,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2330) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _colorsForCode(widget.centerCode),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.imagePath.isEmpty)
                          Center(
                            child: Text(
                              widget.centerCode.substring(0, 2).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        if (widget.imagePath.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CachedNetworkImage(
                              imageUrl: widget.imagePath,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: Icon(
                                  Icons.school_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _colorsForCode(String code) {
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
      [Color(0xFF10B981), Color(0xFF059669)],
    ];
    final idx = code.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
    return palettes[idx];
  }
}