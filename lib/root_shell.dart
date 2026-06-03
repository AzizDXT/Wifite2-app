import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs commands as root. Locates the `su` binary by absolute path (PATH is not
/// reliable for app processes) and feeds commands over stdin to an interactive
/// root shell — which avoids any `-c` quoting issues.
class RootShell {
  RootShell._();

  static String? _cachedSu;

  /// Common `su` locations across Magisk / KernelSU / classic root.
  static const _candidates = [
    '/system/bin/su',
    '/system/xbin/su',
    '/su/bin/su',
    '/sbin/su',
    '/debug_ramdisk/su',
    '/sbin/bin/su',
    '/system/sbin/su',
    '/vendor/bin/su',
    '/magisk/.core/bin/su',
  ];

  static Future<String> _su() async {
    final cached = _cachedSu;
    if (cached != null) return cached;
    for (final c in _candidates) {
      if (File(c).existsSync()) return _cachedSu = c;
    }
    return _cachedSu = 'su'; // last resort: rely on PATH
  }

  /// True if `su` grants us uid 0.
  static Future<bool> isRootAvailable() async {
    try {
      final lines = <String>[];
      await run('id -u', lines.add);
      return lines.any((l) => l.trim() == '0');
    } catch (_) {
      return false;
    }
  }

  /// Starts a root shell, feeds it [command] over stdin, and streams combined
  /// stdout/stderr lines to [onLine]. Closing stdin (EOF) makes the shell exit
  /// once the command finishes. Returns the [Process] so callers can kill it.
  static Future<Process> stream(
      String command, void Function(String) onLine) async {
    final su = await _su();
    final p = await Process.start(su, const <String>[]);
    p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);
    p.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);
    p.stdin.writeln(command);
    await p.stdin.flush();
    await p.stdin.close();
    return p;
  }

  /// Runs [command] as root and waits for it to finish. Returns the exit code.
  static Future<int> run(String command, void Function(String) onLine) async {
    final p = await stream(command, onLine);
    return p.exitCode;
  }
}
