import 'dart:io';

import 'package:flutter/foundation.dart';

import 'payload_installer.dart';
import 'root_shell.dart';

enum AttackMode { pixieDust, bruteforce, pushButton }

extension AttackModeX on AttackMode {
  String get flag => switch (this) {
        AttackMode.pixieDust => '-K',
        AttackMode.bruteforce => '-B',
        AttackMode.pushButton => '--pbc',
      };
}

/// Holds UI state and drives OneShot through a root shell.
class OneShotController extends ChangeNotifier {
  bool? rootGranted; // null = not checked yet
  bool installed = false;
  bool running = false;

  String iface = 'wlan0';
  String bssid = '';
  AttackMode mode = AttackMode.pixieDust;

  final List<String> log = [];

  Directory? _payload;
  Process? _proc;

  void _log(String line) {
    log.add(line);
    notifyListeners();
  }

  void setMode(AttackMode m) {
    mode = m;
    notifyListeners();
  }

  Future<void> checkRoot() async {
    rootGranted = await RootShell.isRootAvailable();
    _log(rootGranted!
        ? '[+] Root access granted'
        : '[!] No root access (su failed)');
  }

  Future<void> install() async {
    try {
      _payload = await PayloadInstaller.install(_log);
      installed = File('${_payload!.path}/oneshot.py').existsSync();
      _log(installed
          ? '[+] Payload ready'
          : '[!] oneshot.py missing — did you run prepare_assets.sh?');
    } catch (e) {
      _log('[!] Install failed: $e');
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (running) return;
    if (_payload == null || !installed) {
      _log('[!] Install the payload first.');
      return;
    }
    final base = _payload!.path;
    final flags = StringBuffer(mode.flag);
    if (bssid.trim().isNotEmpty) flags.write(' -b ${bssid.trim()}');

    final cmd = 'cd $base && export PATH=$base/bin:\$PATH && '
        'export PYTHONDONTWRITEBYTECODE=1 && '
        '$base/bin/python3 $base/oneshot.py -i $iface $flags';

    _log('[*] $cmd');
    running = true;
    notifyListeners();

    _proc = await RootShell.stream(cmd, _log);
    _proc!.exitCode.then((code) {
      _log('[*] oneshot exited ($code)');
      running = false;
      notifyListeners();
    });
  }

  Future<void> stop() async {
    _log('[*] Stopping oneshot...');
    // OneShot spawns its own wpa_supplicant; reap both. SIGINT first so it
    // can restore the interface, then force-kill.
    await RootShell.run(
      "pkill -INT -f oneshot.py 2>/dev/null; sleep 1; "
      "pkill -f oneshot.py 2>/dev/null; "
      "pkill -f 'wpa_supplicant.*p2p-dev' 2>/dev/null; true",
      _log,
    );
    _proc?.kill();
    running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _proc?.kill();
    super.dispose();
  }
}
