import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/contact_helper.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/custom_loader.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../models/purchase_model.dart';
import '../../../providers/voucher_provider.dart';
import '../../../../../core/utils/network_helper.dart';

class MyPurchase extends StatefulWidget {
  const MyPurchase({super.key});

  @override
  State<MyPurchase> createState() => _MyPurchaseState();
}

class _MyPurchaseState extends State<MyPurchase> {
  late Future<List<PurchaseModel>> _purchasesFuture;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  void _loadPurchases() {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? '';

    if (uid.isNotEmpty) {
      _purchasesFuture = context.read<VoucherProvider>().fetchUserPurchases(
        uid,
      );
    } else {
      _purchasesFuture = Future.value([]);
    }
  }

  Future<void> _refreshData() async {
    final hasInternet = await NetworkHelper.hasInternet();
    if (!hasInternet) {
      if (mounted) {
        CustomToast.show(context, 'No internet connection. Failed to refresh.', isError: true);
      }
      return;
    }
    setState(() {
      _loadPurchases();
    });
    await _purchasesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          RefreshIndicator(
            onRefresh: _refreshData,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const CustomAppBar(title: 'Order History', isLeading: true),
                FutureBuilder<List<PurchaseModel>>(
                  future: _purchasesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(child: CustomLoader()),
                      );
                    }

                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: Center(child: Text('Error: ${snapshot.error}')),
                      );
                    }

                    final purchases = snapshot.data ?? [];

                    if (purchases.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'You have no purchases yet. Check out the store!',
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final purchase = purchases[index];
                          return Dismissible(
                            key: Key(purchase.id),
                            direction: DismissDirection.horizontal,

                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove from history?'),
                                  content: const Text(
                                    'This will hide this transaction from your history.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                            },

                            onDismissed: (_) async {
                              final auth = context.read<AuthProvider>();
                              final provider = context.read<VoucherProvider>();

                              final success = await provider.hideUserPurchase(
                                transactionId: purchase.id,
                                uid: auth.currentUser!.uid,
                              );

                              if (!context.mounted) return;

                              CustomToast.show(context, 
                                    success
                                        ? 'Removed from history'
                                        : provider.errorMessage,
                                  );

                              setState(() {
                                purchases.removeAt(index);
                              });
                            },

                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),

                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),

                            child: _buildPurchaseCard(
                              context: context,
                              isDark: isDark,
                              purchase: purchase,
                              theme: theme,
                            ),
                          );
                        }, childCount: purchases.length),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard({
    required BuildContext context,
    required bool isDark,
    required PurchaseModel purchase,
    required ThemeData theme,
  }) {
    String image;
    Color baseColor;

    // Normalize exam type and select appropriate assets
    final normalized = purchase.examType.toLowerCase().trim();
    switch (normalized) {
      case 'waec':
        image = 'assets/images/waec.webp';
        baseColor = AppColors.dynamicColors[1];
        break;
      case 'neco':
        image = 'assets/images/neco.webp';
        baseColor = AppColors.dynamicColors[3];
        break;
      case 'post_utme':
        image = 'assets/images/post_utme.webp';
        baseColor = AppColors.dynamicColors[0];
        break;
      case 'jamb':
      default:
        image = 'assets/images/jamb.webp';
        baseColor = AppColors.dynamicColors[2];
        break;
    }

    final displayPrice = purchase.amount.toInt().toString().replaceAll(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      ',',
    );

    final title = 'Activation Code - ${_formatExamType(purchase.examType)} CBT';
    final statusLabel = purchase.statusLabel;

    // 1. Foolproof check: If it has a voucher or is used, it is NEVER pending.
    final isActuallyPending =
        purchase.isPending && !purchase.isVoucherGenerated && !purchase.isUsed;

    // --- Custom message specifically for Manual Transfers ---
    String message = purchase.effectiveMessage;
    if (purchase.paymentMethod == 'bank_transfer' && isActuallyPending) {
      message =
          'Your receipt is under review. Please click the button below to notify the admin on WhatsApp for faster confirmation.';
    }

    Color statusColor;
    if (purchase.isVoucherGenerated || purchase.isUsed) {
      statusColor = Colors.green;
    } else if (isActuallyPending ||
        purchase.isVerifying ||
        purchase.isVerified) {
      statusColor = Colors.orange;
    } else if (purchase.showFailureMessage) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
    }

    // 2. Hide "Make New Payment" if they already have their code
    final canBuyAgain =
        (isActuallyPending ||
            purchase.showFailureMessage ||
            purchase.isInitialized) &&
        !purchase.isVoucherGenerated &&
        !purchase.isUsed;

    // 3. Hide the message box completely if the code is ready (makes the UI much cleaner)
    final showMessageBox =
        (isActuallyPending ||
            purchase.showFailureMessage ||
            purchase.isVerified) &&
        !purchase.isVoucherGenerated &&
        !purchase.isUsed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.dividerDark
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // status and date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                _formatDate(purchase.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // product row
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(image, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦$displayPrice',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // THE MESSAGE BOX (Now hides when code is ready)
          if (showMessageBox)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                message,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ),

          if (showMessageBox) const SizedBox(height: 10),

          if (purchase.canCopyVoucher && !purchase.isUsed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: baseColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      purchase.voucherCode!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    color: baseColor,
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: purchase.voucherCode!),
                      );
                      CustomToast.show(context, 'Code copied to clipboard!');
                    },
                    tooltip: 'Copy Code',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () =>
                    _showTransactionDetails(context, purchase, statusColor),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Details', style: TextStyle(fontSize: 12)),
              ),
              if (purchase.canUnlock && !purchase.isUsed)
                ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: purchase.voucherCode!),
                    );
                    Navigator.pushNamed(context, '/unlock');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: baseColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Unlock',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              if (canBuyAgain)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/store');
                    CustomToast.show(context, 
                          'Please select your package from the store to retry.',
                        );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Buy Again', style: TextStyle(fontSize: 12)),
                ),
              if (purchase.paymentMethod == 'bank_transfer' &&
                  isActuallyPending)
                ElevatedButton.icon(
                  onPressed: () async {
                    final settings = context.read<SettingsProvider>();
                    final waNumber = settings.whatsappNumber;
                    if (waNumber.isNotEmpty) {
                      await ContactHelper.openWhatsApp(
                        waNumber,
                        'Hello Admin, I just uploaded a receipt for my purchase (Ref: ${purchase.paystackReference}). Please confirm.',
                      );
                    } else {
                      if (!context.mounted) return;
                      CustomToast.show(context, 'WhatsApp contact not available.');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.chat, size: 14),
                  label: const Text(
                    'Notify WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    PurchaseModel purchase,
    Color statusColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final theme = Theme.of(context);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Transaction Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _detailTile('Status', purchase.statusLabel, statusColor),
                  _detailTile(
                    'Verification',
                    purchase.verificationStatus.toUpperCase(),
                    null,
                  ),
                  _detailTile(
                    'Amount',
                    '₦${purchase.amount.toStringAsFixed(0)}',
                    null,
                  ),
                  _detailTile(
                    'Exam Type',
                    _formatExamType(purchase.examType),
                    null,
                  ),
                  _detailTile(
                    'Payment Method',
                    purchase.paymentMethod.toUpperCase(),
                    null,
                  ),
                  _detailTile(
                    'Reference',
                    purchase.paystackReference,
                    null,
                    canCopy: true,
                  ),
                  if ((purchase.voucherCode ?? '').isNotEmpty)
                    _detailTile(
                      'Voucher Code',
                      purchase.voucherCode!,
                      null,
                      canCopy: true,
                    ),
                  if ((purchase.channel ?? '').isNotEmpty)
                    _detailTile('Channel', purchase.channel!, null),
                  if ((purchase.gatewayResponse ?? '').isNotEmpty)
                    _detailTile(
                      'Gateway Response',
                      purchase.gatewayResponse!,
                      null,
                    ),
                  _detailTile(
                    'Created At',
                    _formatDateTime(purchase.createdAt),
                    null,
                  ),
                  if (purchase.updatedAt != null)
                    _detailTile(
                      'Updated At',
                      _formatDateTime(purchase.updatedAt!),
                      null,
                    ),
                  if (purchase.paidAt != null)
                    _detailTile(
                      'Paid At',
                      _formatDateTime(purchase.paidAt!),
                      null,
                    ),
                  if ((purchase.failureReason ?? '').isNotEmpty)
                    _detailTile(
                      'Failure Reason',
                      purchase.failureReason!,
                      Colors.red,
                    ),
                  if ((purchase.errorMessage ?? '').isNotEmpty)
                    _detailTile('Message', purchase.errorMessage!, Colors.red),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailTile(
    String label,
    String value,
    Color? valueColor, {
    bool canCopy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.withValues(alpha: 0.06),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
            if (canCopy)
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  CustomToast.show(context, 'Copied successfully');
                },
                icon: const Icon(Icons.copy, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year}  $hour:$minute';
  }

  String _formatExamType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'post_utme':
        return 'POST UTME';
      case 'jamb':
        return 'JAMB UTME';
      case 'waec':
        return 'WAEC';
      case 'neco':
        return 'NECO';
      default:
        return type.toUpperCase();
    }
  }
}
