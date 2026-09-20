import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/utils/custom_app_bar.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_btn.dart';
import '../../../../../core/utils/custom_loader.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  @override
  Widget build(BuildContext context) {
    // We removed the redundant Avatar Header since it now lives in MyAccount.
    // This is now a dedicated, clean Edit Profile screen.
    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.currentUser;

              if (user == null) {
                return const CustomScrollView(
                  slivers: [
                    CustomAppBar(title: 'Edit Profile', isLeading: true),
                    SliverFillRemaining(child: Center(child: CustomLoader())),
                  ],
                );
              }

              final name = user.displayName;
              final email = user.email;
              final gender = user.gender;
              final dob = user.dob;
              final hobbies = user.hobbies;
              final interests = user.interests;
              final phone = user.phone;
              final schoolStatus = user.schoolStatus;

              return CustomScrollView(
                slivers: [
                  const CustomAppBar(
                    title: 'Edit Profile',
                    subtitle: 'Update your personal details and contact info.',
                    isLeading: true,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // --- BASIC INFORMATION ---
                          _buildSectionHeader(
                            context,
                            title: 'Basic Information',
                            onEdit: () => _showEditBottomSheet(
                              context,
                              'Basic Info',
                              {
                                'displayName': name, // Moved name editing here!
                                'gender': gender,
                                'dob': dob,
                                'hobbies': hobbies,
                                'interests': interests,
                              },
                              labels: {
                                'displayName': 'Full Name',
                                'gender': 'Gender',
                                'dob': 'Date of Birth',
                                'hobbies': 'Hobbies',
                                'interests': 'My Interests',
                              },
                            ),
                          ),
                          _buildInfoItem(
                            context,
                            Icons.person_pin_rounded,
                            'Full Name',
                            name,
                          ),
                          _buildInfoItem(
                            context,
                            Icons.person_rounded,
                            'Gender',
                            gender,
                          ),
                          _buildInfoItem(
                            context,
                            Icons.cake_rounded,
                            'Date of Birth',
                            dob,
                          ),
                          _buildInfoItem(
                            context,
                            Icons.star_rounded,
                            'Hobbies',
                            hobbies,
                          ),
                          _buildInfoItem(
                            context,
                            Icons.trending_up_rounded,
                            'My Interests',
                            interests,
                          ),
                          const SizedBox(height: 32),

                          // --- CONTACT INFORMATION ---
                          _buildSectionHeader(
                            context,
                            title: 'Contact Information',
                            onEdit: () => _showEditBottomSheet(
                              context,
                              'Contact Info',
                              {'email': email, 'phone': phone},
                              labels: {
                                'email': 'Email',
                                'phone': 'Mobile Phone',
                              },
                            ),
                          ),
                          _buildInfoItem(
                            context,
                            Icons.mail_rounded,
                            'Email',
                            email,
                          ),
                          _buildInfoItem(
                            context,
                            Icons.phone_rounded,
                            'Mobile Phone',
                            phone,
                          ),
                          const SizedBox(height: 32),

                          // --- SCHOOLING INFORMATION ---
                          _buildSectionHeader(
                            context,
                            title: 'Schooling Information',
                            onEdit: () => _showEditBottomSheet(
                              context,
                              'Schooling Info',
                              {'schoolStatus': schoolStatus},
                              labels: {'schoolStatus': 'School Status'},
                            ),
                          ),
                          _buildInfoItem(
                            context,
                            Icons.school_rounded,
                            'School Status',
                            schoolStatus,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final bool isMissingData =
        value == '--' || value == 'Department of --' || value.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMissingData ? 'Not provided' : value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontStyle: isMissingData
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: isMissingData
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditBottomSheet(
    BuildContext context,
    String sectionTitle,
    Map<String, String> fields, {
    Map<String, String>? labels,
  }) {
    final authProvider = context.read<AuthProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _EditProfileSheet(
          sectionTitle: sectionTitle,
          fields: fields,
          labels: labels,
          authProvider: authProvider,
          parentContext: context,
        );
      },
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final String sectionTitle;
  final Map<String, String> fields;
  final Map<String, String>? labels;
  final AuthProvider authProvider;
  final BuildContext parentContext;

  const _EditProfileSheet({
    required this.sectionTitle,
    required this.fields,
    this.labels,
    required this.authProvider,
    required this.parentContext,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final Map<String, TextEditingController> _controllers = {};
  String? _selectedGender;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final entry in widget.fields.entries) {
      final value = (entry.value == '--' || entry.value == 'Department of --')
          ? ''
          : entry.value;
      _controllers[entry.key] = TextEditingController(text: value);
      if (entry.key == 'gender') _selectedGender = value.isEmpty ? null : value;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        // Clear of the keyboard when it is up, of the gesture bar when it is not.
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Update ${widget.sectionTitle}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ...widget.fields.keys.map((key) {
              final displayLabel = widget.labels?[key] ?? key;

              // Read-only email field
              if (key == 'email') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _controllers[key],
                    readOnly: true,
                    enabled: false,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    decoration: InputDecoration(
                      labelText: displayLabel,
                      prefixIcon: const Icon(Icons.mail_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      filled: true,
                    ),
                  ),
                );
              }

              // Gender Dropdown
              if (key == 'gender') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        ['Male', 'Female', 'Other'].contains(_selectedGender)
                        ? _selectedGender
                        : null,
                    decoration: InputDecoration(
                      labelText: displayLabel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                    items: ['Male', 'Female', 'Other']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                  ),
                );
              }

              // Date Picker
              if (key == 'dob') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _controllers[key],
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: displayLabel,
                      prefixIcon: const Icon(Icons.calendar_today_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().subtract(
                          const Duration(days: 6570),
                        ), // Default ~18 years ago
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _controllers[key]!.text =
                              "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                        });
                      }
                    },
                  ),
                );
              }

              // Phone Number Formatter
              if (key == 'phone') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _controllers[key],
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: InputDecoration(
                      labelText: displayLabel,
                      hintText: 'e.g 08012345678',
                      prefixIcon: const Icon(Icons.phone_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }

              // Standard Text Field (Name, Hobbies, etc)
              int? maxLength;
              if (key == 'displayName') maxLength = 50;
              if (key == 'hobbies' || key == 'interests') maxLength = 150;
              if (key == 'schoolStatus') maxLength = 80;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: _controllers[key],
                  maxLines: (key == 'hobbies' || key == 'interests') ? 2 : 1,
                  inputFormatters: [
                    if (maxLength != null)
                      LengthLimitingTextInputFormatter(maxLength),
                  ],
                  decoration: InputDecoration(
                    labelText: displayLabel,
                    prefixIcon: key == 'displayName'
                        ? const Icon(Icons.person_pin_rounded)
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            CustomBtn(
              label: _isSaving ? 'Saving...' : 'Save Changes',
              icon: _isSaving ? null : Icons.check_circle_rounded,
              backgroundColor: AppColors.primary,
              borderRadius: 16,
              height: 54,
              onPressed: _isSaving
                  ? null
                  : () async {
                      if (_controllers.containsKey('phone')) {
                        final phoneText = _controllers['phone']!.text.trim();
                        if (phoneText.isNotEmpty && phoneText.length != 11) {
                          CustomToast.show(
                            context,
                            'Phone number must be exactly 11 digits.',
                            isError: true,
                          );
                          return;
                        }
                      }

                      setState(() => _isSaving = true);

                      final updates = <String, dynamic>{};
                      for (final entry in _controllers.entries) {
                        if (entry.key == 'email') continue;

                        if (entry.key == 'gender') {
                          updates['gender'] = _selectedGender ?? '--';
                        } else {
                          final newVal = entry.value.text.trim();
                          if (entry.key == 'displayName') {
                            if (newVal.isEmpty) {
                              CustomToast.show(
                                context,
                                'Full Name cannot be empty.',
                                isError: true,
                              );
                              setState(() => _isSaving = false);
                              return;
                            }
                            updates[entry.key] = newVal;
                          } else if (entry.key == 'schoolStatus') {
                            updates[entry.key] = newVal.isEmpty
                                ? 'Department of --'
                                : newVal;
                          } else {
                            updates[entry.key] = newVal.isEmpty ? '--' : newVal;
                          }
                        }
                      }

                      if (updates.isEmpty) {
                        Navigator.pop(context);
                        return;
                      }

                      final navigator = Navigator.of(context);
                      final errorMsg = widget.authProvider.errorMessage;

                      final success = await widget.authProvider.updateProfile(
                        updates,
                      );

                      if (!mounted) return;
                      navigator.pop();

                      if (!widget.parentContext.mounted) return;

                      if (success) {
                        CustomToast.show(
                          widget.parentContext,
                          'Changes saved successfully!',
                        );
                      } else {
                        CustomToast.show(
                          widget.parentContext,
                          errorMsg,
                          isError: true,
                        );
                      }
                    },
            ),
            const SizedBox(height: 12),
            CustomBtn(
              label: 'Cancel',
              backgroundColor: Colors.transparent,
              textColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
