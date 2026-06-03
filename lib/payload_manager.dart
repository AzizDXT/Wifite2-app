import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads `payload.zip` (OneShot source + arm64 binaries) from a URL,
/// extracts it into the app's private support dir, and chmods the binaries.
class PayloadManager {
  PayloadManager._();

  /// The payload install directory (not created here).
  static Future<Directory> dir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/payload');
  }

  /// True if a payload is already extracted locally.
  static Future<bool> isInstalled() async {
    final d = await dir();
    return File('${d.path}/oneshot.py').existsSync();
  }

  /// Downloads from [url], extracts, and makes binaries executable.
  /// [onProgress] receives 0–1 (or null when total size is unknown / done).
  static Future<Directory> downloadAndInstall(
    String url, {
    required void Function(String) onLog,
    required void Function(double?) onProgress,
  }) async {
    final dest = await dir();
    onLog('[*] Downloading payload from $url');

    final client = http.Client();
    try {
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      if (resp.statusCode == 404) {
        throw const HttpException(
            'payload.zip not found (404) — publish it with '
            'scripts/build_payload.sh, or set the URL in Advanced options');
      }
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode} fetching payload');
      }

      final total = resp.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in resp.stream) {
        builder.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : null);
      }
      onProgress(null);

      final bytes = builder.takeBytes();
      onLog('[+] Downloaded '
          '${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB');

      onLog('[*] Extracting -> ${dest.path}');
      if (dest.existsSync()) dest.deleteSync(recursive: true);
      dest.createSync(recursive: true);

      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        final outPath = '${dest.path}/${entry.name}';
        if (entry.isFile) {
          File(outPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(entry.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
      onLog('[+] Extracted ${archive.length} entries');

      // The binaries are app-owned, so chmod needs NO root. Avoid `su` here
      // (it may be absent / fail) — use the toolbox chmod directly.
      await _makeExecutable(dest, onLog);
      return dest;
    } finally {
      client.close();
    }
  }

  /// Marks everything under bin/ executable, without requiring root.
  static Future<void> _makeExecutable(
      Directory dest, void Function(String) onLog) async {
    final bin = '${dest.path}/bin';
    for (final chmod in const ['/system/bin/chmod', 'chmod', 'toybox']) {
      try {
        final args = chmod == 'toybox'
            ? ['chmod', '-R', '755', bin]
            : ['-R', '755', bin];
        final r = await Process.run(chmod, args);
        if (r.exitCode == 0) return;
      } catch (_) {/* try next */}
    }
    onLog('[!] Could not chmod bin/ (continuing; will retry under root on Start)');
  }
}
