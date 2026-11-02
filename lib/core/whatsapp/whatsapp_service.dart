import 'package:url_launcher/url_launcher.dart';

/// Opens a WhatsApp chat with a ready-made message. WhatsApp never lets an
/// app send on the user's behalf, so this only pre-fills the text — the
/// doctor still taps "send" — which is also why nothing here needs a
/// server, a Business API account, or an internet connection beyond
/// WhatsApp itself.
class WhatsAppService {
  const WhatsAppService._();

  /// wa.me needs the number in international form with no leading zero or
  /// symbols: strips everything but digits, treats a leading 00 as the
  /// international prefix, and assumes a local 0-prefixed Syrian number
  /// otherwise. Null when there's nothing usable.
  static String? normalize(String? phone) {
    if (phone == null) return null;
    final digits = _asciiDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('00')) return digits.substring(2);
    if (digits.startsWith('963')) return digits;
    if (digits.startsWith('0')) return '963${digits.substring(1)}';
    if (digits.length == 9 && digits.startsWith('9')) return '963$digits';
    return digits;
  }

  static Future<bool> open(String phone, String message) async {
    final number = normalize(phone);
    if (number == null) return false;
    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens any WhatsApp URL (e.g. wa.me/?text=… with no recipient, so the
  /// user picks the contact themselves).
  static Future<bool> openUri(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Arabic-Indic (٠-٩) and Persian (۰-۹) digits to ASCII, so numbers typed
  /// or pasted from an Arabic keyboard still normalize.
  static String _asciiDigits(String input) {
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      if (unit >= 0x0660 && unit <= 0x0669) {
        buffer.writeCharCode(unit - 0x0660 + 0x30);
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        buffer.writeCharCode(unit - 0x06F0 + 0x30);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }
}
