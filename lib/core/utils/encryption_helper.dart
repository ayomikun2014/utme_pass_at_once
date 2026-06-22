import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart'; // Make sure this is in pubspec.yaml
import 'package:encrypt/encrypt.dart' as enc; // Make sure this is in pubspec.yaml

class EncryptionHelper {
  // You can type literally anything here.
  // The SHA-256 hash below will automatically convert it to exactly 32 bytes!
  static const String _rawSecret = "utme_pass_at_once_premium_secure_key_2026";

  // --- 1. Generate guaranteed 32-byte key ---
  static enc.Key get _getKey {
    final bytes = utf8.encode(_rawSecret);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  // --- 2. Generate standard 16-byte Initialization Vector (IV) ---
  static final _iv = enc.IV.fromLength(16);

  // --- 3. Encrypt and Save ---
  static Future<void> encryptAndSave(Uint8List data, String filePath) async {
    try {
      final encrypter = enc.Encrypter(enc.AES(_getKey));
      final encrypted = encrypter.encryptBytes(data, iv: _iv);

      final file = File(filePath);
      await file.writeAsBytes(encrypted.bytes);
    } catch (e) {
      throw Exception("Encryption failed: $e");
    }
  }

  // --- 4. Read and Decrypt ---
  static Future<Uint8List> readAndDecrypt(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Uint8List(0); // Return empty if file is missing
      }

      final encryptedBytes = await file.readAsBytes();
      final encrypter = enc.Encrypter(enc.AES(_getKey));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: _iv);

      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw Exception("Decryption failed: $e");
    }
  }
}