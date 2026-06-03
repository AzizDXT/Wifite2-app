import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'root_shell.dart';

/// Extracts the bundled `assets/payload.zip` (OneShot source + arm64 binaries)
/// into the app's private support dir and makes the binaries executable.
class PayloadInstaller {
  PayloadInstaller._();

  static Future<Directory> install(void Function(String) log) async {
    final support = await getApplicationSupportDirectory();
    final dest = Directory('${support.path}/payload');
    log('[*] Installing payload -> ${dest.path}');

    if (dest.existsSync()) dest.deleteSync(recursive: true);
    dest.createSync(recursive: true);

    final data = await rootBundle.load('assets/payload.zip');
    final archive = ZipDecoder().decodeBytes(data.buffer.asUint8List());
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
    log('[+] Extracted ${archive.length} entries');

    // Android can't exec from the read-only APK; chmod the extracted tools.
    await RootShell.run('chmod -R 755 ${dest.path}/bin', log);
    return dest;
  }
}
