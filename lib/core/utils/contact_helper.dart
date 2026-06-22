import 'package:url_launcher/url_launcher.dart';

class ContactHelper {
  /// Cleans a phone number for WhatsApp:
  /// - Removes spaces, +, brackets, and dashes
  /// - Converts leading 0 to 234 (Nigerian format)
  static String cleanWhatsAppNumber(String number) {
    // 1. Remove all non-numeric characters
    String clean = number.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Handle Nigerian format (starts with 0)
    if (clean.startsWith('0')) {
      clean = '234${clean.substring(1)}';
    }

    return clean;
  }

  // =========================
  // 1. WHATSAPP
  // =========================
  static Future<void> openWhatsApp(String phoneNumber, String message) async {
    try {
      final cleanPhone = cleanWhatsAppNumber(phoneNumber);
      final encodedMessage = Uri.encodeComponent(message);

      final Uri url = Uri.parse(
        'https://wa.me/$cleanPhone?text=$encodedMessage',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for some devices/browsers
        final Uri fallbackUrl = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMessage');
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('WhatsApp not available');
        }
      }
    } catch (e) {
      throw Exception('Could not open WhatsApp: $e');
    }
  }

  // =========================
  // 2. EMAIL
  // =========================
  static Future<void> openEmail(String emailAddress, {String subject = 'Support Request', String body = 'Hi support team, '}) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: emailAddress,
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw Exception('Email app not available');
      }
    } catch (e) {
      throw Exception('Could not open Email: $e');
    }
  }

  // =========================
  // 3. DIALER
  // =========================
  static Future<void> openDialer(String phoneNumber) async {
    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      final Uri dialUri = Uri(scheme: 'tel', path: cleanPhone);

      if (await canLaunchUrl(dialUri)) {
        await launchUrl(dialUri);
      } else {
        throw Exception('Dialer not available');
      }
    } catch (e) {
      throw Exception('Could not open Dialer: $e');
    }
  }
}
