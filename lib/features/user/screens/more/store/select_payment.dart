import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/custom_btn.dart';
import '../../../models/store_item.dart';
import '../../../providers/store_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../providers/paystack_provider.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../../../core/services/network_service.dart';
import '../../../../../core/services/notification_service.dart';
import 'package:flutter/services.dart';

class SelectPayment extends StatefulWidget {
  const SelectPayment({super.key});

  @override
  State<SelectPayment> createState() => _SelectPaymentState();
}


class _SelectPaymentState extends State<SelectPayment> {
  int selectedIndex = 0; // Default to Paystack
  bool _isProcessing = false;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent == 0) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 20) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = context.watch<StoreProvider>().selectedItem;

    return Scaffold(
      bottomSheet: _bottomBuyButton(context, item, theme, isDark),
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              const CustomAppBar(
                title: 'Select Payment',
                subtitle:
                    'Choose how you want to pay for your activation code.',
                isLeading: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildPaymentOption(
                        context: context,
                        isDark: isDark,
                        theme: theme,
                      ),
                      const SizedBox(height: 30),
                      _buildOrderSummary(
                        context: context,
                        isDark: isDark,
                        theme: theme,
                        item: item!,
                      ),
                      const SizedBox(height: 24),
                      _buildPaymentInstructions(
                        theme: theme,
                        isDark: isDark,
                        steps: selectedIndex == 0 ? paystackSteps : bankSteps,
                      ),
                      const SizedBox(height: 100),
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

  // --- REUSABLE WIDGET: PROFILE HEADER CARD ---
  Widget _buildPaymentOption({
    required BuildContext context,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.dividerDark
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 2,
        ),
      ),
      child: Builder(
        builder: (context) {
          final isGatewayEnabled = context.watch<SettingsProvider>().paymentGatewayEnabled;

          return Column(
            children: [
              _buildPaymentItem(
                index: 0,
                title: 'Paystack',
                icon: Icons.credit_card_rounded,
                iconColor: Colors.blue,
                subtitle: isGatewayEnabled ? null : 'Coming soon',
                isDisabled: !isGatewayEnabled,
              ),
              _buildPaymentItem(
                index: 1,
                title: 'Manual Transfer',
                icon: Icons.account_balance_rounded,
                iconColor: Colors.grey,
              ),
            ],
          );
        },
      ),
    );
  }

// --- REUSABLE WIDGET: INDIVIDUAL INFO ROW ITEM ---
  Widget _buildPaymentItem({
    required int index,
    required String title,
    required IconData icon,
    Color? iconColor,
    String? subtitle,
    bool isDisabled = false,
  }) {
    final bool isSelected = selectedIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // --- FIXED: Dark mode selection color is now beautifully translucent ---
    final Color itemBgColor = isSelected
        ? (isDark
        ? AppColors.primary.withValues(alpha: 0.2) // No more glaring surfaceLight flash
        : AppColors.primary.withValues(alpha: 0.1))
        : Colors.transparent;

    final Color contentColor = isSelected && isDark
        ? Colors.white // Keep text white in dark mode
        : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                selectedIndex = index;
                _hasScrolledToBottom = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients && _scrollController.position.maxScrollExtent == 0) {
                  setState(() {
                    _hasScrolledToBottom = true;
                  });
                }
              });
            },
      child: AbsorbPointer(
        absorbing: isDisabled,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: itemBgColor,
            borderRadius: BorderRadius.circular(16),
            border: isDisabled ? Border.all(color: Colors.transparent) : null,
          ),
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Row(
              children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected && isDark
                    ? Colors.black26 // Darker icon background for contrast
                    : iconColor?.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: contentColor,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.withValues(alpha: 0.5),
                  width: isSelected ? 7 : 2,
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  // -- ORDER SUMMARY SECTION ---
  Widget _buildOrderSummary({
    required BuildContext context,
    required bool isDark,
    required ThemeData theme,
    required StoreItem item,
  }) {
    // --- 1. DATA HANDLING ---
    final auth = context.read<AuthProvider>();
    final String orderCode = auth.currentUser?.uid ?? 'UNKNOWN';

    final email = auth.currentUser?.email ?? 'Unknown Email';

    final String noticeText = selectedIndex == 0
        ? 'Auto-generates Activation Code'
        : 'Requires manual verification';

    final List<Map<String, String>> summaryDetails = [
      {'title': 'Order code', 'value': orderCode},
      {'title': 'Email', 'value': email},
      {'title': 'Notice', 'value': noticeText},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.dividerDark
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ---
          Text(
            "Order Summary",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),

          // --- 2. PRODUCT PREVIEW BOX ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // Use a very subtle version of the item's brand color
              color: item.baseColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: item.baseColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                // Small Branded Icon
                Container(
                  height: 50,
                  width: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(item.image, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                // Item Name & Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activation Code - ${item.title}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦${item.price.toInt()}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : item.baseColor,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(
            color: isDark
                ? AppColors.dividerDark
                : theme.dividerColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),

          // --- 3. CUSTOMER DETAILS LIST ---
          // Using .map() to handle the list items dynamically
          ...summaryDetails.map(
            (detail) {
              final bool isNotice = detail['title'] == 'Notice';
              final Color? valueColor = isNotice
                  ? (selectedIndex == 0
                      ? (isDark ? Colors.green.shade400 : Colors.green.shade700)
                      : (isDark ? Colors.orange.shade400 : Colors.orange.shade700))
                  : null;
              final FontWeight valueWeight = isNotice ? FontWeight.bold : FontWeight.w600;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      detail['title']!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        detail['value']!,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: valueWeight,
                          color: valueColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  final List<String> paystackSteps = [
    "Click Complete Checkout below to open the secure portal.",
    "Pay safely using Card, Bank Transfer, QR, or USSD code.",
    "Verify the payment inside the secure gateway window.",
    "Voucher code is generated and activated automatically.",
    "Ensure you do not close the checkout page prematurely.",
  ];

  final List<String> bankSteps = [
    "Review the Order Summary and click Complete Checkout.",
    "Copy the center bank details on the manual payment page.",
    "Transfer the exact amount using your Order Code as narration.",
    "Take a clear screenshot of the transaction receipt.",
    "Upload the screenshot in the app for manual approval.",
  ];

  Widget _buildPaymentInstructions({
    required ThemeData theme,
    required bool isDark,
    required List<String> steps,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Payment Instructions",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppColors.dividerDark
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            children: List.generate(
              steps.length,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[index],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- BOTTOM SHEET ---
  Widget _bottomBuyButton(
    BuildContext context,
    StoreItem? item,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Theme-aware background
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        // In Dark mode, shadows look muddy. We use a subtle top border instead.
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : Colors.transparent,
          ),
        ),
        boxShadow: [
          // Only show shadow in light mode
          if (!isDark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
        ],
      ),
      child: SafeArea(
        child: Consumer<PaymentProvider>(
          builder: (context, payment, _) {
            final isLoading = payment.isLoading || _isProcessing;
            final isButtonEnabled = _hasScrolledToBottom && !isLoading;

            return CustomBtn(
              label: isLoading
                  ? 'Processing...'
                  : (_hasScrolledToBottom ? 'Complete Checkout' : 'Scroll Down to Enable Checkout'),
              backgroundColor: isButtonEnabled ? item!.baseColor : Colors.grey.withValues(alpha: 0.5),
              textColor: isButtonEnabled ? Colors.white : Colors.grey,
              onPressed: isButtonEnabled && item != null
                  ? () async {
                      final isOnline = NetworkService.instance.isOnline;
                      if (!isOnline) {
                        CustomToast.show(context, 'You are offline. Please connect to the internet to proceed with payment.', isError: true);
                        return;
                      }

                      final auth = context.read<AuthProvider>();

                      if (auth.currentUser == null) {
                        CustomToast.show(context, 'Please log in first');
                        return;
                      }

                      if (selectedIndex == 0) {
                        final email = auth.currentUser?.email;
                        if (email == null || email.trim().isEmpty) {
                          CustomToast.show(context, 'No valid email found for this account');
                          return;
                        }

                        setState(() {
                          _isProcessing = true;
                        });

                        try {
                          final success = await payment.initializeCheckout(
                            email: email.trim(),
                            amount: item.price,
                            examType: item.id,
                            uid: auth.currentUser!.uid,
                            userName: auth.currentUser!.displayName,
                          );

                          if (!context.mounted) return;

                          if (!success) {
                            CustomToast.show(context, payment.errorMessage);
                            return;
                          }

                          final result = await Navigator.pushNamed(
                            context,
                            '/paystack_checkout',
                            arguments: {
                              'url': payment.authorizationUrl,
                              'reference': payment.lastReference,
                            },
                          );

                          if (!context.mounted) return;

                          if (result != null && result is Map && result['status'] == 'success') {
                            CustomToast.show(context, 'Verifying payment...');

                            final verified = await payment.verifyCompletedPayment(
                              payment.lastReference!,
                            );

                            if (!context.mounted) return;

                            if (!verified) {
                              // --- AUTOMATED NOTIFICATIONS ---
                              NotificationService.instance.createInAppNotification(
                                uid: auth.currentUser!.uid,
                                title: 'Payment Verification Failed ⚠️',
                                body: 'We could not verify your payment. If you were charged, please contact support.',
                                type: 'payment_failed',
                              );
                              // -----------------------------
                              CustomToast.show(context, payment.errorMessage);
                              return;
                            }

                            if (payment.voucherCode != null &&
                                payment.voucherCode!.trim().isNotEmpty) {
                              // Save notification to Firestore + show local push
                              _savePaymentNotification(
                                uid: auth.currentUser!.uid,
                                examType: item.title,
                                voucherCode: payment.voucherCode!,
                              );
                              _showSuccessDialog(context, payment.voucherCode!);
                            } else {
                              _showPartialSuccessDialog(
                                context,
                                'Payment was successful, but your code is still being processed. Please check your order history shortly.',
                              );
                            }
                          } else if (result != null &&
                              result is Map &&
                              result['status'] == 'cancelled') {
                            // --- AUTOMATED NOTIFICATIONS ---
                            NotificationService.instance.createInAppNotification(
                              uid: auth.currentUser!.uid,
                              title: 'Payment Cancelled 🚫',
                              body: 'Your payment was cancelled and no charges were made.',
                              type: 'payment_cancelled',
                            );
                            // -----------------------------
                            CustomToast.show(context, 'Payment cancelled');
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() {
                              _isProcessing = false;
                            });
                          }
                        }
                      } else if (selectedIndex == 1) {
                        Navigator.pushNamed(context, '/bank_transfer');
                      }
                    }
                  : null,
            );
          },
        ),
      ),
    );
  }

  void _showPartialSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Action Required', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 60,
            ),
            const SizedBox(height: 15),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/purchase');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Order History'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Payment Successful!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 60,
            ),
            const SizedBox(height: 15),
            const Text('Your exam activation code is:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      CustomToast.show(context, 'Code copied to clipboard!');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Go back to store
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/unlock');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlock Now'),
          ),
        ],
      ),
    );
  }

  /// Saves a payment success notification to Firestore and shows a local push notification.
  void _savePaymentNotification({
    required String uid,
    required String examType,
    required String voucherCode,
  }) {
    final title = 'Payment Successful! 🎉';
    final body = 'Your $examType activation code ($voucherCode) is ready. Go to Unlock to activate it.';

    try {
      NotificationService.instance.createInAppNotification(
        uid: uid,
        title: title,
        body: body,
        type: 'payment',
        payload: {
          'route': '/unlock',
          'voucherCode': voucherCode,
        },
        showLocalPush: true,
      );
    } catch (e) {
      debugPrint('Error saving payment notification: $e');
    }
  }
}
