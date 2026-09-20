import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/institution_logos.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/custom_loader.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/simulator_provider.dart';
import '../../services/simulator_service.dart';
import '../../../../core/services/network_service.dart';

// ============================================================================
// Constants
// ============================================================================

class _Constants {
  static const double cardBorderRadius = 18;
  static const double searchBorderRadius = 16;
  static const double cardAspectRatio = 0.78;
  static const int gridCrossAxisCount = 2;
  static const double gridSpacing = 14;
  static const int animationDuration = 600;
  static const double cardScalePressed = 0.96;
  static const int maxNameLines = 2;

  static const EdgeInsets searchPadding = EdgeInsets.fromLTRB(20, 16, 20, 8);
  static const EdgeInsets gridPadding = EdgeInsets.fromLTRB(20, 8, 20, 100);
  static const EdgeInsets cardNamePadding = EdgeInsets.all(12);
}

// ============================================================================
// Main Screen
// ============================================================================

class InstitutionSelectionScreen extends StatefulWidget {
  final String examType;

  const InstitutionSelectionScreen({super.key, this.examType = 'post_utme'});

  @override
  State<InstitutionSelectionScreen> createState() =>
      _InstitutionSelectionScreenState();
}

class _InstitutionSelectionScreenState extends State<InstitutionSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, Map<String, dynamic>> _institutions = {};
  String _searchQuery = '';
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadInstitutionsAsync();
  }

  void _initializeAnimation() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _Constants.animationDuration),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String? _extractSectionId(String institutionKey) {
    final lower = institutionKey.toLowerCase().trim();

    if (widget.examType.toLowerCase() != 'post_utme') return null;
    if (!lower.contains('_')) return null;

    final parts = lower.split('_');
    if (parts.length < 2) return null;

    return parts.sublist(1).join('_');
  }

  String _extractBaseInstitutionId(String institutionKey) {
    final lower = institutionKey.toLowerCase().trim();

    if (!lower.contains('_')) return lower;

    return lower.split('_').first;
  }

  Future<void> _loadInstitutionsAsync() async {
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInstitutions());
  }

  Future<void> _loadInstitutions() async {
    _setLoading(true);

    try {
      final authProvider = context.read<AuthProvider>();
      final simProvider = context.read<SimulatorProvider>();

      _isPremium = simProvider.hasPremiumForExam(authProvider, widget.examType);
      debugPrint(
        '🔧 [INSTITUTION] isPremium=$_isPremium for examType=${widget.examType}',
      );

      if (_isPremium) {
        // Premium user: load from local Hive cache, filtered to activated institutions only
        debugPrint(
          '🔧 [OFFLINE] Loading institutions from local cache (premium user)',
        );

        final user = authProvider.currentUser;
        final activatedCenters = user?.getExamCenters(widget.examType) ?? [];
        debugPrint('🔧 [OFFLINE] User activated centers: $activatedCenters');

        // Load full institution mapping from Hive cache
        final allMapping = await simProvider.getInstitutionMapping(
          widget.examType,
          isPremium: true,
        );

        // Filter to only show activated institutions
        final Map<String, Map<String, dynamic>> filteredMapping = {};
        for (final centerId in activatedCenters) {
          final lowerCenterId = centerId.toLowerCase();
          // Extract base ID (e.g., 'oau' from 'oau_science')
          final baseId = lowerCenterId.contains('_')
              ? lowerCenterId.split('_')[0]
              : lowerCenterId;

          if (allMapping.containsKey(baseId)) {
            final baseData = allMapping[baseId]!;
            final section = user?.getSectionForInstitution(
              widget.examType,
              centerId,
            );

            // Create a unique entry for this specific activation
            final displayData = Map<String, dynamic>.from(baseData);
            if (section != null) {
              // Append section name to display title (e.g. OAU (Science))
              final baseName = baseData['name'] ?? baseId.toUpperCase();
              displayData['name'] = "$baseName (${section['name']})";
            }

            filteredMapping[lowerCenterId] = displayData;
            debugPrint(
              '🔧 [OFFLINE] ✅ Found cached data for activated institution: $lowerCenterId (Base: $baseId)',
            );
          }
        }

        if (!mounted) return;
        setState(() {
          _institutions = filteredMapping;
          _isLoading = false;
        });

        _animController.forward(from: 0);
        debugPrint(
          '🔧 [OFFLINE] Showing ${filteredMapping.length} activated institutions',
        );

        // If only one institution, skip selection and go directly to dashboard
        if (filteredMapping.length == 1) {
          final entry = filteredMapping.entries.first;
          debugPrint(
            '🔧 [OFFLINE] Only 1 institution, auto-navigating to dashboard (Replacing route)',
          );

          Future.microtask(() {
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                '/exam_dashboard',
                arguments: {
                  'examType': widget.examType,
                  'schoolId': entry.key,
                  'schoolName': (entry.value['name'] ?? entry.key).toString(),
                  'logoUrl': entry.value['logo'] as String?,
                },
              );
            }
          });
          return;
        }
      } else {
        // Free user: load from local Hive cache if available, fallback to online Firestore
        debugPrint(
          '🔧 [OFFLINE] Loading institutions from local cache (free user)',
        );
        Map<String, Map<String, dynamic>> mapping = await simProvider
            .getInstitutionMapping(widget.examType, isPremium: true);

        if (mapping.isEmpty && NetworkService.instance.isOnline) {
          debugPrint(
            '🌐 [ONLINE] Local cache empty, loading institutions from Firestore (free user)',
          );
          mapping = await simProvider.getInstitutionMapping(
            widget.examType,
            isPremium: false,
          );

          // Cache them locally so they work offline next time!
          final onlineInsts = await simProvider.getAvailableInstitutions(
            widget.examType,
            isPremium: false,
          );
          if (onlineInsts.isNotEmpty) {
            await SimulatorService().cacheInstitutions(
              widget.examType,
              onlineInsts,
            );
          }
        }

        if (!mounted) return;
        setState(() {
          _institutions = mapping;
          _isLoading = false;
        });

        debugPrint('🌐 Loaded ${mapping.length} institutions for free user');
        _animController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('❌ [INSTITUTION] Error loading institutions: $e');
      if (!mounted) return;

      _setError('Failed to load institutions. Please try again.');
    }
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() {
      _isLoading = value;
      if (value) _errorMessage = '';
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  List<MapEntry<String, Map<String, dynamic>>> get _filteredInstitutions {
    if (_searchQuery.isEmpty) return _institutions.entries.toList();

    final query = _searchQuery.toLowerCase();
    return _institutions.entries.where((entry) {
      final institutionName = (entry.value['name'] ?? '')
          .toString()
          .toLowerCase();
      return entry.key.toLowerCase().contains(query) ||
          institutionName.contains(query);
    }).toList();
  }

  void _onInstitutionSelected(String code, String name, String? logo) {
    final sectionId = _extractSectionId(code);
    final baseInstitutionId = widget.examType.toLowerCase() == 'post_utme'
        ? _extractBaseInstitutionId(code)
        : code;

    Navigator.pushNamed(
      context,
      '/exam_dashboard',
      arguments: {
        'examType': widget.examType,
        'schoolId': code, // keep full key like oau_science
        'baseSchoolId': baseInstitutionId, // base key like oau
        'sectionId': sectionId,
        'schoolName': name,
        'logoUrl': logo,
      },
    );
  }

  Widget _buildWatermark() {
    String? imagePath;
    if (widget.examType == 'jamb') {
      imagePath = 'assets/images/jamb.webp';
    } else if (widget.examType == 'post_utme') {
      imagePath = 'assets/images/post_utme.webp';
    }

    if (imagePath == null) return const SizedBox();

    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: 0.05,
          child: Image.asset(
            imagePath,
            width: 280,
            height: 280,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          _buildWatermark(),
          _buildContentArea(theme),
        ],
      ),
    );
  }

  Widget _buildContentArea(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadInstitutions,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [_buildAppBar(), _buildSearchBar(), _buildMainContent(theme)],
      ),
    );
  }

  Widget _buildAppBar() {
    return CustomAppBar(
      title: widget.examType == 'post_utme'
          ? 'Post-UTME'
          : widget.examType.toUpperCase(),
      subtitle: 'Choose your institution to get started.',
      color: AppColors.dynamicColors[0].withValues(
        alpha: 0.9,
      ), // Pulling from dynamicColors
      isLeading: true,
      centerTitle: true,
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: _Constants.searchPadding,
        child: _SearchBarWidget(
          onChanged: (value) => setState(() => _searchQuery = value),
          theme: Theme.of(context),
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    if (_isLoading) {
      return const SliverFillRemaining(child: Center(child: CustomLoader()));
    }

    if (_errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: _ErrorStateWidget(
          message: _errorMessage,
          theme: theme,
          onRetry: _loadInstitutions,
        ),
      );
    }

    if (_filteredInstitutions.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyStateWidget(
          isSearching: _searchQuery.isNotEmpty,
          theme: theme,
        ),
      );
    }

    return _buildInstitutionGrid();
  }

  Widget _buildInstitutionGrid() {
    return SliverPadding(
      padding: _Constants.gridPadding,
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _Constants.gridCrossAxisCount,
          crossAxisSpacing: _Constants.gridSpacing,
          mainAxisSpacing: _Constants.gridSpacing,
          childAspectRatio: _Constants.cardAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildInstitutionCard(index),
          childCount: _filteredInstitutions.length,
        ),
      ),
    );
  }

  Widget _buildInstitutionCard(int index) {
    final entry = _filteredInstitutions[index];
    final institutionData = entry.value;

    return _InstitutionCard(
      index: index,
      code: entry.key,
      name: (institutionData['name'] ?? entry.key).toString(),
      logo: institutionData['logo'] as String?,
      animController: _animController,
      onTap: () => _onInstitutionSelected(
        entry.key,
        (institutionData['name'] ?? entry.key).toString(),
        institutionData['logo'] as String?,
      ),
    );
  }
}

// ============================================================================
// Search Bar Widget
// ============================================================================

class _SearchBarWidget extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final ThemeData theme;

  const _SearchBarWidget({required this.onChanged, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final hintColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(_Constants.searchBorderRadius),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search university...',
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: hintColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Empty State Widget
// ============================================================================

class _EmptyStateWidget extends StatelessWidget {
  final bool isSearching;
  final ThemeData theme;

  const _EmptyStateWidget({required this.isSearching, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildEmptyIcon(),
          const SizedBox(height: 24),
          _buildEmptyTitle(),
          const SizedBox(height: 8),
          _buildEmptySubtitle(),
        ],
      ),
    );
  }

  Widget _buildEmptyIcon() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isSearching ? Icons.search_off_rounded : Icons.school_rounded,
        size: 64,
        color: theme.colorScheme.primary.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildEmptyTitle() {
    return Text(
      isSearching ? 'No Results Found' : 'No Institutions Available',
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildEmptySubtitle() {
    return Text(
      isSearching ? 'Try a different search term.' : 'Pull down to refresh.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: 15,
        height: 1.4,
      ),
    );
  }
}

// ============================================================================
// Error State Widget
// ============================================================================

class _ErrorStateWidget extends StatelessWidget {
  final String message;
  final ThemeData theme;
  final VoidCallback onRetry;

  const _ErrorStateWidget({
    required this.message,
    required this.theme,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildErrorIcon(),
          const SizedBox(height: 24),
          _buildErrorTitle(),
          const SizedBox(height: 8),
          _buildErrorMessage(),
          const SizedBox(height: 20),
          _buildRetryButton(),
        ],
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.error_outline_rounded,
        size: 64,
        color: Colors.red.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildErrorTitle() {
    return Text(
      'Something went wrong',
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildErrorMessage() {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildRetryButton() {
    return TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Retry'),
    );
  }
}

// ============================================================================
// Institution Card
// ============================================================================

class _InstitutionCard extends StatefulWidget {
  final int index;
  final String code;
  final String name;
  final String? logo;
  final AnimationController animController;
  final VoidCallback onTap;

  const _InstitutionCard({
    required this.index,
    required this.code,
    required this.name,
    this.logo,
    required this.animController,
    required this.onTap,
  });

  @override
  State<_InstitutionCard> createState() => _InstitutionCardState();
}

class _InstitutionCardState extends State<_InstitutionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- NEW DYNAMIC GRADIENT LOGIC ---
    final List<Color> colors = _getColorsForCode(widget.code);
    final animations = _buildAnimations(colors);

    return AnimatedBuilder(
      animation: widget.animController,
      builder: (context, child) => FadeTransition(
        opacity: animations.fadeAnimation,
        child: SlideTransition(
          position: animations.slideAnimation,
          child: child,
        ),
      ),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) {
          _setPressed(false);
          widget.onTap();
        },
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _isPressed ? _Constants.cardScalePressed : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: _buildCardContainer(isDark, colors),
        ),
      ),
    );
  }

  void _setPressed(bool value) {
    if (mounted) {
      setState(() => _isPressed = value);
    }
  }

  Widget _buildCardContainer(bool isDark, List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(_Constants.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : colors[0].withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_Constants.cardBorderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildBackgroundGradient(colors),
                  _buildLogoImage(),
                  _buildInitials(),
                ],
              ),
            ),
            _buildNameAndBadge(isDark, colors[0]),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGradient(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }

  Widget _buildLogoImage() {
    // A bundled logo wins: the URL on the record points at Firebase Storage,
    // which this project cannot serve.
    final asset = InstitutionLogos.assetFor(widget.code);
    if (asset != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(asset, fit: BoxFit.contain),
      );
    }

    final hasLogo = widget.logo != null && widget.logo!.trim().isNotEmpty;

    if (!hasLogo) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CachedNetworkImage(
        imageUrl: widget.logo!,
        fit: BoxFit.contain,
        placeholder: (context, url) => Center(
          child: Icon(
            Icons.school_rounded,
            color: Colors.white.withValues(alpha: 0.5),
            size: 40,
          ),
        ),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildInitials() {
    final hasLogo =
        InstitutionLogos.assetFor(widget.code) != null ||
        (widget.logo != null && widget.logo!.trim().isNotEmpty);
    if (hasLogo) return const SizedBox.shrink();

    final initials = widget.code.length >= 2
        ? widget.code.substring(0, 2).toUpperCase()
        : widget.code.toUpperCase();

    return Center(
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w900,
          fontSize: 36,
          letterSpacing: 3,
          shadows: const [
            Shadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
      ),
    );
  }

  Widget _buildNameAndBadge(bool isDark, Color brandColor) {
    return Padding(
      padding: _Constants.cardNamePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNameText(isDark),
          const SizedBox(height: 6),
          _buildExploreBadge(isDark, brandColor),
        ],
      ),
    );
  }

  Widget _buildNameText(bool isDark) {
    return Text(
      widget.name,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF111827),
        height: 1.25,
      ),
      maxLines: _Constants.maxNameLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildExploreBadge(bool isDark, Color brandColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? brandColor.withValues(alpha: 0.2)
            : brandColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brandColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Explore',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? Colors.white : brandColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.arrow_forward_rounded,
            size: 11,
            color: isDark ? Colors.white : brandColor,
          ),
        ],
      ),
    );
  }

  // --- NEW: DYNAMICALLY GENERATES GRADIENTS USING APPCOLORS ---
  List<Color> _getColorsForCode(String code) {
    final codeSum = code.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final paletteIndex = codeSum % AppColors.dynamicColors.length;
    final Color baseColor = AppColors.dynamicColors[paletteIndex];

    // Create a beautiful subtle gradient from the single dynamic color
    return [baseColor, baseColor.withValues(alpha: 0.75)];
  }

  _CardAnimations _buildAnimations(List<Color> colors) {
    final delay = (widget.index * 0.07).clamp(0.0, 0.6);
    final curveInterval = Interval(
      delay,
      (delay + 0.4).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );

    final slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
          CurvedAnimation(parent: widget.animController, curve: curveInterval),
        );

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

    return _CardAnimations(slideAnimation: slideAnim, fadeAnimation: fadeAnim);
  }
}

class _CardAnimations {
  final Animation<Offset> slideAnimation;
  final Animation<double> fadeAnimation;

  _CardAnimations({required this.slideAnimation, required this.fadeAnimation});
}
