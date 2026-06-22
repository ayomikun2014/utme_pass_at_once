import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/custom_btn.dart';
import '../../../../core/utils/custom_loader.dart';
import '../../providers/simulator_provider.dart';
import '../../services/simulator_service.dart';

class SimulatorSessionSetup extends StatefulWidget {
  final String examType;
  final String institutionId;
  final String institutionName;
  final List<String> subjects;
  final bool isPremium;
  final String? logoUrl;
  final String? sectionId;

  const SimulatorSessionSetup({
    super.key,
    required this.examType,
    required this.institutionId,
    required this.institutionName,
    required this.subjects,
    required this.isPremium,
    this.logoUrl,
    this.sectionId,
  });
  @override
  State<SimulatorSessionSetup> createState() => _SimulatorSessionSetupState();
}

class _SimulatorSessionSetupState extends State<SimulatorSessionSetup> {
  final Map<String, List<String>> _availableYearsMap = {};
  bool _isLoading = true;
  bool _isPreparing = false;
  String? _preparationError;

  // Global Setup State
  int _globalQuestionCount = 40; // 20, 40, 60, -1 (All)
  String _globalYearMode = 'latest_1'; // latest_1, latest_2, latest_3, random
  String _globalExamMode = 'practice'; // practice, suffix
  String _timerMode = 'auto'; // auto, custom
  double _customTimeMinutes = 60;
  final Map<String, String> _selectedYearsMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllYears();
  }

  Future<void> _loadAllYears() async {
    final simProvider = context.read<SimulatorProvider>();

    for (final subject in widget.subjects) {
      try {
        List<String> years = await simProvider
            .getAvailableYears(
          widget.examType,
          widget.institutionId,
          subject,
          isPremium: widget.isPremium,
          sectionId: widget.sectionId,
        )
            .timeout(
          Duration(seconds: widget.isPremium ? 2 : 15),
          onTimeout: () => ['2024', '2023', '2022'],
        );

        if (!widget.isPremium && years.length > 2) {
          years = years.take(2).toList();
        }

        years.sort((a, b) => b.compareTo(a));
        _availableYearsMap[subject] = years;
        _selectedYearsMap[subject] = years.first;
      } catch (e) {
        _availableYearsMap[subject] = ['2023', '2022'];
        _selectedYearsMap[subject] = '2023';
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _prepareAndShowSummary() async {
    if (widget.subjects.isEmpty) return;
    setState(() {
      _isPreparing = true;
      _preparationError = null;
    });

    try {
      // 1. Calculate Selected Years
      Map<String, Set<String>> calculatedShuffleYears = {};
      Map<String, String> calculatedSingleYears = {};
      bool isShuffle = _globalExamMode == 'suffix' || _globalYearMode != 'latest_1';

      for (final subject in widget.subjects) {
        if (_globalExamMode == 'practice') {
          final selectedYear = _selectedYearsMap[subject] ?? '';
          calculatedSingleYears[subject] = selectedYear;
          calculatedShuffleYears[subject] = {selectedYear};
          isShuffle = false;
        } else {
          final years = _availableYearsMap[subject] ?? [];
          if (years.isEmpty) continue;

          if (_globalYearMode == 'latest_1') {
            calculatedSingleYears[subject] = years.first;
            calculatedShuffleYears[subject] = {years.first};
          } else if (_globalYearMode == 'latest_2') {
            calculatedShuffleYears[subject] = years.take(2).toSet();
          } else if (_globalYearMode == 'latest_3') {
            calculatedShuffleYears[subject] = years.take(3).toSet();
          } else if (_globalYearMode == 'random') {
            final shuffledYears = List<String>.from(years)..shuffle();
            calculatedShuffleYears[subject] = shuffledYears.take(4).toSet();
          }
        }
      }

      // 2. Fetch Max Questions for Smart Balancing
      final simulatorService = SimulatorService();
      Map<String, int> maxQuestionsMap = {};

      for (final subject in widget.subjects) {
        int total = 0;
        final yearsToCount = calculatedShuffleYears[subject] ?? {};
        if (widget.isPremium) {
          for (final year in yearsToCount) {
            total += await simulatorService.getCachedQuestionCount(
              examType: widget.examType,
              institutionId: widget.institutionId,
              subject: subject,
              year: year,
            );
          }
        } else {
          total = yearsToCount.length * 40; 
        }
        maxQuestionsMap[subject] = total;
      }

      // 3. Smart Balancing Algorithm
      int totalRequested = _globalQuestionCount;
      int totalAvailable = maxQuestionsMap.values.fold(0, (a, b) => a + b);

      if (_globalExamMode == 'practice') {
        totalRequested = totalAvailable;
      } else {
        if (totalRequested == -1 || totalRequested > totalAvailable) {
          totalRequested = totalAvailable;
        }
      }
      
      if (totalRequested == 0) totalRequested = 40; // fallback

      int numSubjects = widget.subjects.length;
      int basePerSubject = totalRequested ~/ numSubjects;
      int remainder = totalRequested % numSubjects;
      
      Map<String, int> questionsPerSubject = {};
      int totalShortfall = 0;
      
      for (final subject in widget.subjects) {
        int alloc = basePerSubject + (remainder > 0 ? 1 : 0);
        if (remainder > 0) remainder--;
        
        int available = maxQuestionsMap[subject] ?? alloc;
        if (alloc > available && available > 0) {
          totalShortfall += (alloc - available);
          questionsPerSubject[subject] = available;
        } else {
          questionsPerSubject[subject] = alloc;
        }
      }
      
      if (totalShortfall > 0) {
        bool changed = true;
        while (totalShortfall > 0 && changed) {
          changed = false;
          for (final subject in widget.subjects) {
            int alloc = questionsPerSubject[subject]!;
            int available = maxQuestionsMap[subject] ?? alloc;
            if (alloc < available && totalShortfall > 0) {
              questionsPerSubject[subject] = alloc + 1;
              totalShortfall--;
              changed = true;
            }
          }
        }
      }

      // 4. Timer Calculation
      int examDurationMinutes = 120;
      if (_timerMode == 'auto') {
        examDurationMinutes = totalRequested; 
      } else {
        examDurationMinutes = _customTimeMinutes.toInt();
      }

      // Ensure data is cached (if premium)
      if (!mounted) return;
      final simProvider = context.read<SimulatorProvider>();
      if (widget.isPremium) {
        for (final subject in widget.subjects) {
           final years = isShuffle 
               ? (calculatedShuffleYears[subject]?.toList() ?? [])
               : [calculatedSingleYears[subject] ?? ''];
               
           for (final year in years) {
             if (year.isEmpty) continue;
             final isCached = await simProvider.areQuestionsCached(
               examType: widget.examType,
               institutionId: widget.institutionId,
               subjects: [subject],
               subjectYears: {subject: year},
             );
             if (!isCached) {
               throw Exception('Offline data missing for $subject $year. Please reconnect and restore your activated package.');
             }
           }
        }
      }

      if (!mounted) return;
      setState(() => _isPreparing = false);

      // Show Summary Dialog
      _showSummaryDialog(
        questionsPerSubject,
        calculatedShuffleYears,
        calculatedSingleYears,
        isShuffle,
        examDurationMinutes,
      );

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _preparationError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showSummaryDialog(
    Map<String, int> questionsPerSubject,
    Map<String, Set<String>> shuffleYearsMap,
    Map<String, String> singleYearsMap,
    bool isShuffle,
    int examDurationMinutes,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalQ = questionsPerSubject.values.fold(0, (a, b) => a + b);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E2330) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.analytics_rounded, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              const Text('Exam Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildSummaryRow(Icons.menu_book_rounded, 'Subjects', '${widget.subjects.length} selected'),
               const SizedBox(height: 12),
               _buildSummaryRow(Icons.format_list_numbered_rounded, 'Total Questions', '$totalQ Questions'),
               const SizedBox(height: 12),
               _buildSummaryRow(
                  Icons.date_range_rounded, 
                  'Year Configuration', 
                  _globalExamMode == 'practice' ? 'Specific Years Selected' :
                  _globalYearMode == 'latest_1' ? 'Latest 1 Year' : 
                  _globalYearMode == 'latest_2' ? 'Latest 2 Years' :
                  _globalYearMode == 'latest_3' ? 'Latest 3 Years' : 'Mixed Random',
               ),
               const SizedBox(height: 12),
               _buildSummaryRow(
                  Icons.timer_rounded, 
                  'Duration', 
                  examDurationMinutes == 0 ? 'Untimed (Practice)' : '$examDurationMinutes Minutes',
               ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _startExam(
                  questionsPerSubject,
                  shuffleYearsMap,
                  singleYearsMap,
                  isShuffle,
                  examDurationMinutes,
                );
              },
              child: const Text('Start Exam', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  void _startExam(
    Map<String, int> questionsPerSubject,
    Map<String, Set<String>> shuffleYearsMap,
    Map<String, String> singleYearsMap,
    bool isShuffle,
    int examDurationMinutes,
  ) {
    // Convert Set<String> to List<String> and sort for the simulator argument
    Map<String, List<String>> convertedShuffleYears = {};
    if (isShuffle) {
      for (final key in shuffleYearsMap.keys) {
         convertedShuffleYears[key] = shuffleYearsMap[key]!.toList()..sort((a,b) => b.compareTo(a));
      }
    }

    Navigator.pushNamed(
      context,
      '/utme_simulator',
      arguments: {
        'examType': widget.examType,
        'institutionId': widget.institutionId,
        'institutionName': widget.institutionName,
        'subjects': widget.subjects,
        'subjectYears': singleYearsMap,
        'shuffleMode': isShuffle,
        'shuffleYears': convertedShuffleYears,
        'questionsPerSubjectMap': questionsPerSubject,
        'isFree': !widget.isPremium,
        'timePerSubject': examDurationMinutes == 0 ? 0 : (examDurationMinutes / widget.subjects.length).round(),
        'totalTime': examDurationMinutes,
        'logoUrl': widget.logoUrl,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              CustomAppBar(
                title: 'Exam Setup',
                subtitle: 'Configure your simulation globally',
                isLeading: true,
              ),
              if (_isLoading)
                const SliverFillRemaining(child: Center(child: CustomLoader()))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSectionTitle(theme, 'Exam Mode'),
                      const SizedBox(height: 12),
                      _buildExamModeSelector(theme),
                      const SizedBox(height: 32),

                      if (_globalExamMode == 'practice') ...[
                        _buildSectionTitle(theme, 'Select Years'),
                        const SizedBox(height: 12),
                        _buildPerSubjectYearSelectors(theme),
                        const SizedBox(height: 32),
                      ],

                      if (_globalExamMode == 'suffix') ...[
                        _buildSectionTitle(theme, 'Year Mode'),
                        const SizedBox(height: 12),
                        _buildYearModeSelector(theme),
                        const SizedBox(height: 32),

                        _buildSectionTitle(theme, 'Question Count'),
                        const SizedBox(height: 12),
                        _buildQuestionCountSelector(theme),
                        const SizedBox(height: 32),
                      ],

                      _buildSectionTitle(theme, 'Timer Settings'),
                      const SizedBox(height: 12),
                      _buildTimerSettings(theme),
                      const SizedBox(height: 32),

                      const SizedBox(height: 120),
                    ]),
                  ),
                ),
            ],
          ),
          
          if (!_isLoading)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [theme.scaffoldBackgroundColor.withValues(alpha: 0), theme.scaffoldBackgroundColor],
                  ),
                ),
                child: CustomBtn(
                  label: 'Start Setup',
                  onPressed: _isPreparing ? null : _prepareAndShowSummary,
                ),
              ),
            ),

          if (_isPreparing) 
             Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(child: CustomLoader()),
             ),
             
          if (_preparationError != null)
             Container(
                color: Colors.black.withValues(alpha: 0.8),
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2330) : Colors.white, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         const Icon(Icons.error_outline, color: Colors.red, size: 48),
                         const SizedBox(height: 16),
                         Text(_preparationError!, textAlign: TextAlign.center),
                         const SizedBox(height: 24),
                         ElevatedButton(onPressed: () => setState(() => _preparationError = null), child: const Text('Close'))
                      ]
                    )
                  )
                )
             )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildQuestionCountSelector(ThemeData theme) {
    final options = [
      {'val': 20, 'label': '20'},
      {'val': 40, 'label': '40'},
      {'val': 60, 'label': '60'},
      {'val': -1, 'label': 'Max'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: options.map((opt) {
        final isSelected = _globalQuestionCount == opt['val'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _globalQuestionCount = opt['val'] as int),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.grey.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                opt['label'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYearModeSelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final options = [
      {'val': 'latest_1', 'label': 'Latest 1 Year', 'desc': 'Single recent year'},
      {'val': 'latest_2', 'label': 'Latest 2 Years', 'desc': 'Merge 2 recent years'},
      {'val': 'latest_3', 'label': 'Latest 3 Years', 'desc': 'Merge 3 recent years'},
      {'val': 'random', 'label': 'Mixed Random', 'desc': 'Randomly merge years'},
    ];

    return Column(
      children: options.map((opt) {
        final isSelected = _globalYearMode == opt['val'];
        return GestureDetector(
          onTap: () => setState(() => _globalYearMode = opt['val'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : (isDark ? const Color(0xFF1E2330) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? theme.colorScheme.primary : Colors.grey,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opt['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(opt['desc'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExamModeSelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final options = [
      {'val': 'practice', 'label': 'Practice Mode', 'icon': Icons.menu_book_rounded},
      {'val': 'suffix', 'label': 'Suffix Mode', 'icon': Icons.school_rounded},
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = _globalExamMode == opt['val'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _globalExamMode = opt['val'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : (isDark ? const Color(0xFF1E2330) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(opt['icon'] as IconData, color: isSelected ? Colors.white : Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    opt['label'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPerSubjectYearSelectors(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: widget.subjects.map((subject) {
        final years = _availableYearsMap[subject] ?? [];
        if (years.isEmpty) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2330) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subject.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              DropdownButton<String>(
                value: _selectedYearsMap[subject] ?? years.first,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down_rounded),
                items: years.map((year) {
                  return DropdownMenuItem<String>(
                    value: year,
                    child: Text(year, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedYearsMap[subject] = val;
                    });
                  }
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimerSettings(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _timerMode = 'auto'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _timerMode == 'auto' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _timerMode == 'auto' ? theme.colorScheme.primary : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('Auto (1 min/q)', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _timerMode = 'custom'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _timerMode == 'custom' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _timerMode == 'custom' ? theme.colorScheme.primary : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('Custom Time', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_timerMode == 'custom') ...[
          const SizedBox(height: 12),
          Slider(
            value: _customTimeMinutes,
            min: 30, max: 180, divisions: 15,
            label: '${_customTimeMinutes.toInt()} mins',
            activeColor: theme.colorScheme.primary,
            onChanged: (val) => setState(() => _customTimeMinutes = val),
          ),
        ]
      ],
    );
  }
}
