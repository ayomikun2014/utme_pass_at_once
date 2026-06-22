import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'GEMINI_API_KEY', obfuscate: true)
  static final String geminiApiKey = _Env.geminiApiKey;

  @EnviedField(varName: 'GROQ_API_KEY', obfuscate: true)
  static final String groqApiKey = _Env.groqApiKey;

  @EnviedField(varName: 'PAYSTACK_PUBLIC_KEY', obfuscate: true)
  static final String paystackPublicKey = _Env.paystackPublicKey;

  @EnviedField(varName: 'PAYSTACK_INITIALIZE_URL', obfuscate: true)
  static final String paystackInitializeUrl = _Env.paystackInitializeUrl;

  @EnviedField(varName: 'PAYSTACK_VERIFY_URL', obfuscate: true)
  static final String paystackVerifyUrl = _Env.paystackVerifyUrl;

  @EnviedField(varName: 'PAYSTACK_RECORD_VOUCHER_USAGE_URL', obfuscate: true)
  static final String paystackRecordVoucherUsageUrl =
      _Env.paystackRecordVoucherUsageUrl;
}
