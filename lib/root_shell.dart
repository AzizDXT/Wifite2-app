import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Thin wrapper around an on-demand `su` shell.
class RootShell {
  RootShell._();

  /// True if `su` grants us uid 0.
  static Future<bool> isRootAvailable() async {
    try {
      final r = await Process.run('su', ['-c', 'id -u']);
      return r.stdout.toString().trim().startsWith('0');
    } catch (_) {
      return false;
    }
  }

  /// Starts [command] as root, streaming combined stdout/stderr lines to
  /// [onLine]. Returns the running [Process] so the caller can kill it.
  static Future<Process> stream(
      String command, void Function(String) onLine) async {
    final p = await Process.start('su', ['-c', command]);
    p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);
    p.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);
    return p;
  }

  /// Runs [command] as root and waits for it to finish. Returns the exit code.
  static Future<int> run(String command, void Function(String) onLine) async {
    final p = await stream(command, onLine);
    return p.exitCode;
  }
}
