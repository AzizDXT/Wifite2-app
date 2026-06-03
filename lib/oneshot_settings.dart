import 'dart:convert';

/// The main attack action. `auto` passes no action flag, letting OneShot scan
/// and prompt interactively.
enum AttackMode { auto, pixieDust, bruteforce, pushButton }

extension AttackModeX on AttackMode {
  String get label => switch (this) {
        AttackMode.auto => 'Auto',
        AttackMode.pixieDust => 'Pixie-Dust',
        AttackMode.bruteforce => 'Bruteforce',
        AttackMode.pushButton => 'Push-button',
      };

  /// The OneShot flag, or null for [AttackMode.auto].
  String? get flag => switch (this) {
        AttackMode.auto => null,
        AttackMode.pixieDust => '-K',
        AttackMode.bruteforce => '-B',
        AttackMode.pushButton => '--pbc',
      };
}

/// All OneShot options, with (de)serialization and shell-argument building.
/// Field-by-field this mirrors `oneshot.py`'s argparse.
class OneShotSettings {
  // Primary
  String iface; // -i / --interface (required)
  String bssid; // -b / --bssid
  String pin; // -p / --pin
  AttackMode mode; // -K / -B / --pbc (or none)

  // Secondary — values
  String delay; // -d / --delay (seconds)
  String vulnList; // --vuln-list (path)

  // Secondary — switches
  bool pixieForce; // -F / --pixie-force
  bool showPixieCmd; // -X / --show-pixie-cmd
  bool write; // -w / --write
  bool ifaceDown; // --iface-down
  bool loop; // -l / --loop
  bool reverseScan; // -r / --reverse-scan
  bool mtkWifi; // --mtk-wifi
  bool verbose; // -v / --verbose

  OneShotSettings({
    this.iface = 'wlan0',
    this.bssid = '',
    this.pin = '',
    this.mode = AttackMode.pixieDust,
    this.delay = '',
    this.vulnList = '',
    this.pixieForce = false,
    this.showPixieCmd = false,
    this.write = true,
    this.ifaceDown = false,
    this.loop = false,
    this.reverseScan = false,
    this.mtkWifi = false,
    this.verbose = false,
  });

  /// Builds the OneShot argument string (interface + selected options).
  /// User-supplied values are single-quoted for the shell.
  String buildFlags() {
    final a = <String>['-i', _q(iface.trim().isEmpty ? 'wlan0' : iface.trim())];
    if (bssid.trim().isNotEmpty) a.addAll(['-b', _q(bssid.trim())]);
    if (pin.trim().isNotEmpty) a.addAll(['-p', _q(pin.trim())]);

    final f = mode.flag;
    if (f != null) a.add(f);

    if (pixieForce) a.add('-F');
    if (showPixieCmd) a.add('-X');
    if (write) a.add('-w');
    if (ifaceDown) a.add('--iface-down');
    if (loop) a.add('-l');
    if (reverseScan) a.add('-r');
    if (mtkWifi) a.add('--mtk-wifi');
    if (verbose) a.add('-v');

    if (delay.trim().isNotEmpty) a.addAll(['-d', _q(delay.trim())]);
    if (vulnList.trim().isNotEmpty) {
      a.addAll(['--vuln-list', _q(vulnList.trim())]);
    }
    return a.join(' ');
  }

  /// Single-quote a value for POSIX shells, escaping embedded quotes.
  static String _q(String s) => "'${s.replaceAll("'", r"'\''")}'";

  Map<String, dynamic> toMap() => {
        'iface': iface,
        'bssid': bssid,
        'pin': pin,
        'mode': mode.name,
        'delay': delay,
        'vulnList': vulnList,
        'pixieForce': pixieForce,
        'showPixieCmd': showPixieCmd,
        'write': write,
        'ifaceDown': ifaceDown,
        'loop': loop,
        'reverseScan': reverseScan,
        'mtkWifi': mtkWifi,
        'verbose': verbose,
      };

  String toJson() => jsonEncode(toMap());

  factory OneShotSettings.fromJson(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return OneShotSettings(
      iface: m['iface'] as String? ?? 'wlan0',
      bssid: m['bssid'] as String? ?? '',
      pin: m['pin'] as String? ?? '',
      mode: AttackMode.values.firstWhere(
        (e) => e.name == m['mode'],
        orElse: () => AttackMode.pixieDust,
      ),
      delay: m['delay'] as String? ?? '',
      vulnList: m['vulnList'] as String? ?? '',
      pixieForce: m['pixieForce'] as bool? ?? false,
      showPixieCmd: m['showPixieCmd'] as bool? ?? false,
      write: m['write'] as bool? ?? true,
      ifaceDown: m['ifaceDown'] as bool? ?? false,
      loop: m['loop'] as bool? ?? false,
      reverseScan: m['reverseScan'] as bool? ?? false,
      mtkWifi: m['mtkWifi'] as bool? ?? false,
      verbose: m['verbose'] as bool? ?? false,
    );
  }
}
