import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'oneshot_settings.dart';
import 'payload_manager.dart';
import 'root_shell.dart';

/// Holds UI state + persisted [OneShotSettings] and drives OneShot via root.
class OneShotController extends ChangeNotifier {
  static const _prefsKey = 'oneshot.settings.v1';

  OneShotSettings settings = OneShotSettings();
  bool loaded = false;
  bool? rootGranted; // null = not checked yet
  bool installed = false;
  bool installing = false;
  double? progress; // download progress 0–1 (null = unknown/indeterminate)
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

  /// One-shot startup: check root, then download+install the payload if it
  /// isn't already present. Everything here runs automatically on launch.
  Future<void> autoSetup() async {
    await checkRoot();
    await ensurePayload();
  }

  /// Ensures the payload is installed. Downloads it when missing (or when
  /// [force] is set, e.g. a manual re-download).
  Future<void> ensurePayload({bool force = false}) async {
    if (installing) return;
    installing = true;
    progress = null;
    notifyListeners();
    try {
      if (!force && await PayloadManager.isInstalled()) {
        _payload = await PayloadManager.dir();
        installed = true;
        _log('[+] Payload already installed');
        return;
      }
      _payload = await PayloadManager.downloadAndInstall(
        settings.payloadUrl,
        onLog: _log,
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );
      installed = File('${_payload!.path}/oneshot.py').existsSync();
      _log(installed
          ? '[+] Payload ready'
          : '[!] oneshot.py missing from the downloaded archive');
    } catch (e) {
      _log('[!] Payload setup failed: $e');
    } finally {
      installing = false;
      progress = null;
      notifyListeners();
    }
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
