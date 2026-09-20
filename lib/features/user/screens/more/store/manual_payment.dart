import 'dart:math' as math;
import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:utme_pass_at_once/features/user/services/manual_payment_service.dart';
import 'package:utme_pass_at_once/core/utils/contact_helper.dart';
import 'package:utme_pass_at_once/features/user/models/store_item.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/custom_btn.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../providers/store_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../providers/voucher_provider.dart';

// --- NEW IMPORT ---
import '../../../providers/manual_payment_provider.dart';

class ManualPayment extends StatefulWidget {
  const ManualPayment({super.key});

  @override
  State<ManualPayment> createState() => _ManualPaymentState();
}

class _ManualPaymentState extends State<ManualPayment> {
  bool _hasReadInstructions = false;

  // Image Picker Variables
  XFile? _proofImageFile;
  Uint8List? _proofImageBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      // Shrunk as it is picked: plenty to read a bank slip, and quick to
      // upload on a slow connection.
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 60,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > ManualPaymentService.maxUploadBytes) {
          if (mounted) {
            CustomToast.show(
              context,
              'That receipt is still too large to send. Please crop it, or take a '
              'clearer photo of just the receipt.',
              isError: true,
            );
          }
          return;
        }
        setState(() {
          _proofImageFile = image;
          _proofImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = context.watch<StoreProvider>().selectedItem;
    final settingsProvider = context.watch<SettingsProvider>();

    if (item == null) {
      return const Scaffold(body: Center(child: Text("No item selected")));
    }

    if (settingsProvider.isLoading) {
      return const Scaffold(body: CustomLoader());
    }

    final banks = settingsProvider.settings.bankDetails;

    return Scaffold(
      bottomNavigationBar: _buildBottomBar(
        context,
        isDark,
        theme,
        settingsProvider.settings.whatsappNumber,
        item,
      ),
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Pay via Bank Transfer',
                isLeading: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(item: item, context: context),
                      const SizedBox(height: 24),

                      // --- BANK ACCOUNTS ---
                      _buildSectionTitle(theme, "Bank Information"),
                      const SizedBox(height: 12),
                      if (banks.isEmpty)
                        const Text("No bank accounts available at this time.")
                      else
                        ...banks.map(
                          (bank) => _buildBankCard(
                            theme: theme,
                            isDark: isDark,
                            bankName: bank.bankName,
                            accountName: bank.accountName,
                            accountNumber: bank.accountNumber,
                            baseColor: item.baseColor,
                          ),
                        ),
                      const SizedBox(height: 24),

                      // --- ATTACH RECEIPT ---
                      _buildSectionTitle(theme, "Attach Receipt"),
                      const SizedBox(height: 12),
                      _buildReceiptPicker(theme, isDark, item.baseColor),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 1. HEADER & WARNING ---
  Widget _buildHeader({
    required BuildContext context,
    required StoreItem item,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.read<AuthProvider>();
    final String orderCode = auth.currentUser?.uid ?? 'UNKNOWN';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark
            : item.baseColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.dividerDark
              : item.baseColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Amount To Pay',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦${item.price.toInt()}',
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : item.baseColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your Order Code',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: orderCode));
              CustomToast.show(context, "Order code copied!");
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    orderCode,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.copy_rounded, size: 16, color: item.baseColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION TITLE ---
  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  // --- 3. BANK CARDS ---
  Widget _buildBankCard({
    required ThemeData theme,
    required bool isDark,
    required String bankName,
    required String accountName,
    required String accountNumber,
    required Color baseColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark
            : baseColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.dividerDark
              : baseColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Account Name", style: theme.textTheme.bodySmall),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  accountName,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  maxLines: 2,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Bank Name", style: theme.textTheme.bodySmall),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  bankName,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  maxLines: 2,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Account Number", style: theme.textTheme.bodySmall),
                    Text(
                      accountNumber,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      maxLines: 1,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: accountNumber));
                  CustomToast.show(context, "Account number copied!");
                },
                icon: Icon(Icons.copy_rounded, size: 16, color: baseColor),
                label: Text(
                  "Copy",
                  style: TextStyle(
                    color: baseColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: baseColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- RECEIPT PICKER ---
  Widget _buildReceiptPicker(ThemeData theme, bool isDark, Color baseColor) {
    if (_proofImageBytes == null) {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 40, color: baseColor),
              const SizedBox(height: 12),
              Text(
                "Tap to upload receipt image",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Supports JPG, PNG (Max 5MB)",
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _proofImageBytes!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _proofImageFile?.name ?? "Receipt Image",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${(_proofImageBytes!.length / 1024).toStringAsFixed(1)} KB",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () {
              setState(() {
                _proofImageFile = null;
                _proofImageBytes = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // --- 5. BOTTOM BAR ---
  Widget _buildBottomBar(
    BuildContext context,
    bool isDark,
    ThemeData theme,
    String whatsappNumber,
    StoreItem item,
  ) {
    // Read the provider to listen to its loading state
    final manualPaymentProvider = context.watch<ManualPaymentProvider>();
    final isProcessing = manualPaymentProvider.isLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        math.max(24.0, MediaQuery.of(context).padding.bottom + 16.0),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.dividerDark
                : theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _hasReadInstructions = !_hasReadInstructions),
            child: Row(
              children: [
                Checkbox(
                  value: _hasReadInstructions,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (val) =>
                      setState(() => _hasReadInstructions = val!),
                ),
                const Expanded(
                  child: Text(
                    "I have made the transfer and attached my receipt.",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CustomBtn(
            label: isProcessing ? "Processing..." : "Submit",
            onPressed:
                _hasReadInstructions &&
                    _proofImageBytes != null &&
                    !isProcessing
                ? () async {
                    final auth = context.read<AuthProvider>();
                    final user = auth.currentUser;
                    if (user == null) {
                      CustomToast.show(context, 'Please log in first');
                      return;
                    }

                    String ext = _proofImageFile?.name.split('.').last ?? 'jpg';

                    if (!context.mounted) return;
                    final manualPaymentProvider = context
                        .read<ManualPaymentProvider>();

                    // 3. Submit Payment
                    final success = await manualPaymentProvider.submitPayment(
                      uid: user.uid,
                      email: user.email,
                      userName: user.displayName,
                      amount: item.price,
                      examType: item.id,
                      imageBytes: _proofImageBytes!,
                      imageExtension: ext,
                    );

                    if (!context.mounted) return;

                    if (success) {
                      // Refresh purchases list
                      context.read<VoucherProvider>().fetchUserPurchases(
                        user.uid,
                      );

                      CustomToast.show(
                        context,
                        'Payment submitted successfully! Waiting for admin approval.',
                      );

                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacementNamed('/purchase');
                    } else {
                      // Retrieve the error message from the provider
                      final errorMsg = context
                          .read<ManualPaymentProvider>()
                          .errorMessage;
                      CustomToast.show(
                        context,
                        errorMsg.isNotEmpty
                            ? errorMsg
                            : 'Error processing request.',
                        isError: true,
                      );
                    }
                  }
                : null,
            backgroundColor: _hasReadInstructions && _proofImageBytes != null
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.5),
            textColor: _hasReadInstructions && _proofImageBytes != null
                ? Colors.white
                : Colors.grey,
          ),

          // Fallback WhatsApp link just in case
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              final auth = context.read<AuthProvider>();
              final user = auth.currentUser;
              final target = whatsappNumber.isNotEmpty
                  ? whatsappNumber
                  : "2349133733736";
              ContactHelper.openWhatsApp(
                target,
                "Hi, I made a manual bank transfer for ${item.title}.\nOrder Code: ${user?.uid}\nI am having trouble uploading the receipt in the app.",
              );
            },
            child: const Text(
              "Can't upload? Send via WhatsApp instead.",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
