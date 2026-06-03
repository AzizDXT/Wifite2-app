import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'oneshot_settings.dart';
import 'payload_installer.dart';
import 'root_shell.dart';

/// Holds UI state + persisted [OneShotSettings] and drives OneShot via root.
class OneShotController extends ChangeNotifier {
  static const _prefsKey = 'oneshot.settings.v1';

  OneShotSettings settings = OneShotSettings();
  bool loaded = false;
  bool? rootGranted; // null = not checked yet
  bool installed = false;
  bool running = false;

  final List<String> log = [];

  Directory? _payload;
  Process? _proc;
  SharedPreferences? _prefs;

  /// The exact OneShot invocation that Start will run (for the live preview).
  String get commandPreview => 'oneshot.py ${settings.buildFlags()}';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs!.getString(_prefsKey);
    if (s != null) {
      try {
        settings = OneShotSettings.fromJson(s);
      } catch (_) {/* keep defaults on corrupt data */}
    }
    loaded = true;
    notifyListeners();
  }

  /// Mutate settings, persist, and rebuild. Used by every input.
  void update(void Function(OneShotSettings) change) {
    change(settings);
    _prefs?.setString(_prefsKey, settings.toJson());
    notifyListeners();
  }

  void _log(String line) {
    log.add(line);
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
    final cmd = 'cd $base && export PATH=$base/bin:\$PATH && '
        'export PYTHONDONTWRITEBYTECODE=1 && '
        '$base/bin/python3 $base/oneshot.py ${settings.buildFlags()}';

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
