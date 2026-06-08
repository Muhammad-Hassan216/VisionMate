/// Email Configuration for Brevo (formerly Sendinblue)
///
/// To get your API key:
/// 1. Go to: https://app.brevo.com/settings/keys/api
/// 2. Login to your Brevo account
/// 3. Generate a new API key
/// 4. Replace the key below with your new key
/// 5. Verify sender email in Brevo account

class EmailConfig {
  // ⚠️ IMPORTANT: Replace this with your valid Brevo API key
  // You MUST:
  // 1. Create new API key at https://app.brevo.com/settings/keys/api
  // 2. Verify the sender email (codewithmhassan786@gmail.com) in Brevo
  // 3. Get V3 REST API key (not SMTP)
  static const String brevoApiKey = 'YOUR_BREVO_API_KEY_HERE';

  // Sender details - MUST be verified in Brevo account
  static const String senderName = 'Vision Mate';
  static const String senderEmail = 'codewithmhassan786@gmail.com';

  // API endpoint
  static const String brevoApiUrl = 'https://api.brevo.com/v3/smtp/email';

  // Fallback endpoint
  static const String brevoFallbackUrl =
      'https://api.sendinblue.com/v3/smtp/email';

  /// Check if API key is configured
  static bool isConfigured() {
    return brevoApiKey != 'YOUR_BREVO_API_KEY_HERE' &&
        brevoApiKey.isNotEmpty &&
        senderEmail.isNotEmpty;
  }

  /// Check if sender email is valid
  static bool isSenderEmailValid() {
    return senderEmail.contains('@') && senderEmail.length > 5;
  }
}
