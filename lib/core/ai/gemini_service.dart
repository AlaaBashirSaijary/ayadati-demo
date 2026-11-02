import 'dart:convert';

import 'package:http/http.dart' as http;

/// The one place this app talks to an external AI model — every AI-assist
/// feature (medical-certificate drafting, dosage suggestions, "اسأل عن
/// عيادتك") goes through here, never calls the API directly.
///
/// This is the one deliberate exception to "عيادتي works fully offline":
/// each call needs internet, so every feature built on this must be
/// optional and degrade to "الميزة غير متوفرة الآن" rather than block the
/// doctor's actual work. The API key itself is a compile-time constant
/// (`--dart-define=GEMINI_API_KEY=...`, injected only by CI from a repo
/// secret — see build-apk.yml) so it's never committed to this public
/// repo; a build without it (a fork, a local dev build) simply reports
/// [isAvailable] as false and every AI feature hides itself.
///
/// The AI only ever *drafts wording* or *suggests* something the doctor
/// reviews and can edit before saving — it never decides a diagnosis or a
/// dosage on its own, and every screen that uses it says so.
class GeminiService {
  GeminiService._();

  static final GeminiService instance = GeminiService._();

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// The "-latest" alias is deliberate: Google regularly deprecates and
  /// shuts down pinned model versions (e.g. gemini-2.0-flash was shut down
  /// within about a year), which would otherwise silently break every AI
  /// feature until someone notices and ships a new build. This alias always
  /// resolves to whichever stable flash release Google currently
  /// recommends, so the app keeps working without a code change.
  static const _model = 'gemini-flash-latest';

  bool get isAvailable => _apiKey.isNotEmpty;

  /// Set after every failed [generateText] call — the HTTP status/response
  /// snippet or exception message, so a failure can be diagnosed (e.g. a
  /// shut-down model, an invalid key, a quota limit) without needing device
  /// logs. Null after a successful call.
  String? lastError;

  /// Returns the model's reply, or null on any failure (no key, no
  /// internet, a rate limit, a malformed response) — callers show a plain
  /// "تعذّر الاتصال بالمساعد الذكي" rather than a raw error either way, but
  /// may also surface [lastError] for troubleshooting.
  Future<String?> generateText(String prompt) async {
    if (!isAvailable) {
      lastError = 'no API key compiled into this build';
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        final body = utf8.decode(response.bodyBytes).trim();
        final snippet = body.length > 200 ? body.substring(0, 200) : body;
        lastError = 'HTTP ${response.statusCode}: $snippet';
        return null;
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        lastError = 'empty candidates in response';
        return null;
      }

      final parts =
          (candidates.first['content']?['parts'] as List<dynamic>?) ?? [];
      final text = parts.map((p) => p['text'] as String? ?? '').join().trim();
      if (text.isEmpty) {
        lastError = 'empty text in response';
        return null;
      }
      lastError = null;
      return text;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }
}
