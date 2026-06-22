import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../../../core/utils/custom_loader.dart';

class PaystackCheckoutPage extends StatefulWidget {
  final String checkoutUrl;
  final String reference;

  const PaystackCheckoutPage({
    super.key,
    required this.checkoutUrl,
    required this.reference,
  });

  @override
  State<PaystackCheckoutPage> createState() => _PaystackCheckoutPageState();
}

class _PaystackCheckoutPageState extends State<PaystackCheckoutPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasReturnedResult = false;
  bool _hasError = false;

  static const String _successUrl =
      'https://utme-pass-at-once-36340.web.app/paystack/callback';
  static const String _cancelUrl = 'https://utme-pass-at-once-36340.web.app/paystack/cancel';

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (!_hasReturnedResult && mounted) {
              // Ignore errors that aren't critical or are just cancelled by system
              if (error.errorCode == -999) return;

              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;

            if (url.startsWith(_successUrl)) {
              _returnResult({
                'status': 'success',
                'reference': widget.reference,
                'url': url,
              });
              return NavigationDecision.prevent;
            }

            if (url.startsWith(_cancelUrl)) {
              _returnResult({
                'status': 'cancelled',
                'reference': widget.reference,
                'url': url,
              });
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _returnResult(Map<String, dynamic> result) {
    if (_hasReturnedResult) return;
    _hasReturnedResult = true;

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _confirmClose() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Payment?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'If you close this page now, your payment may not be completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Payment'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close Anyway'),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      _returnResult({'status': 'cancelled', 'reference': widget.reference});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Complete Payment',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmClose,
          ),
        ),
        body: Stack(
          children: [
            if (!_hasError) WebViewWidget(controller: _controller),

            if (_isLoading) const Center(child: CustomLoader()),

            if (_hasError) _buildErrorView(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connection Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'We couldn\'t load the payment page. Please check your internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _confirmClose,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isLoading = true;
                      });
                      _controller.reload();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
