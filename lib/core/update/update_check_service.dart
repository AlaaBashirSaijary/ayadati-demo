import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A newer build than the one currently installed, found on GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseUrl,
  });

  /// Human-readable version, e.g. "1.5.0" (the build suffix is stripped).
  final String version;

  /// Direct link to the release's .apk asset — opened straight in the
  /// browser, which hands it to the OS download manager. Falls back to
  /// [releaseUrl] if the release has no attached .apk for some reason.
  final String downloadUrl;

  /// The release's own GitHub page — used as that fallback, and as "what's
  /// new" if a doctor wants to read the release notes.
  final String releaseUrl;
}

/// Polls this repo's public GitHub Releases for a build newer than the one
/// installed — the one network call this otherwise fully offline app ever
/// makes, and one it's built to fail silently: no internet, a rate limit, a
/// flaky connection, all just mean "couldn't check this time," never a
/// crash or a blocking dialog. There's still no in-app licensing/activation
/// service — this only ever answers "is a newer .apk available," the same
/// question the vendor's own downloads page would.
class UpdateCheckService {
  UpdateCheckService._();

  static final UpdateCheckService instance = UpdateCheckService._();

  static const _releasesUrl =
      'https://api.github.com/repos/AlaaBashirSaijary/ayadati-site/releases/latest';
  static const _lastCheckedKey = 'clinic_manager.update_check.last_checked';
  static const _checkInterval = Duration(hours: 24);

  /// Returns the newer release if one exists, or null if there isn't one,
  /// the check was skipped (checked recently and [force] is false), or the
  /// request failed for any reason. Never throws.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    // The demo build never offers an update: the real app's releases are a
    // different product and must not be pushed onto a demo install.
    return null;
    // ignore: dead_code
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force) {
        final lastMillis = prefs.getInt(_lastCheckedKey);
        if (lastMillis != null) {
          final since = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(lastMillis),
          );
          if (since < _checkInterval) return null;
        }
      }

      final response = await http
          .get(
            Uri.parse(_releasesUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      await prefs.setInt(
        _lastCheckedKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String? ?? '';
      final latestBuild = _buildNumberOf(tag);
      if (latestBuild == null) return null;

      final currentBuild =
          int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
      if (latestBuild <= currentBuild) return null;

      final releaseUrl = json['html_url'] as String? ?? '';
      final assets = (json['assets'] as List<dynamic>?) ?? const [];
      final apkAsset = assets.cast<Map<String, dynamic>>().where(
        (asset) => (asset['name'] as String? ?? '').endsWith('.apk'),
      );
      final downloadUrl = apkAsset.isEmpty
          ? releaseUrl
          : (apkAsset.first['browser_download_url'] as String? ?? releaseUrl);

      return UpdateInfo(
        version: _versionOf(tag),
        downloadUrl: downloadUrl,
        releaseUrl: releaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// "v1.5.0+7" → 7. The release tag is always produced by the CI workflow
  /// from pubspec's own `version:` line, so this stays in lockstep with
  /// [PackageInfo.buildNumber] without either side hardcoding the other.
  int? _buildNumberOf(String tag) {
    final plusIndex = tag.indexOf('+');
    if (plusIndex == -1) return null;
    return int.tryParse(tag.substring(plusIndex + 1));
  }

  /// "v1.5.0+7" → "1.5.0".
  String _versionOf(String tag) {
    final withoutV = tag.startsWith('v') ? tag.substring(1) : tag;
    final plusIndex = withoutV.indexOf('+');
    return plusIndex == -1 ? withoutV : withoutV.substring(0, plusIndex);
  }
}
