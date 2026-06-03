import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../oneshot_controller.dart';
import '../oneshot_settings.dart';
import '../theme.dart';
import '../widgets/console_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _c = OneShotController();

  final _iface = TextEditingController();
  final _bssid = TextEditingController();
  final _pin = TextEditingController();
  final _delay = TextEditingController();
  final _vuln = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c.load().then((_) {
      final s = _c.settings;
      _iface.text = s.iface;
      _bssid.text = s.bssid;
      _pin.text = s.pin;
      _delay.text = s.delay;
      _vuln.text = s.vulnList;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _iface.dispose();
    _bssid.dispose();
    _pin.dispose();
    _delay.dispose();
    _vuln.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneShot'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          if (!_c.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
            children: [
              Text(
                'WPS auditing · authorized networks only',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.inkMuted),
              ),
              const SizedBox(height: 26),
              _statusCard(theme),
              const SizedBox(height: 26),
              _sectionTitle('Target & mode'),
              const SizedBox(height: 12),
              _configCard(),
              const SizedBox(height: 26),
              _sectionTitle('Advanced options'),
              const SizedBox(height: 12),
              _advancedCard(),
              const SizedBox(height: 26),
              _sectionTitle('Setup'),
              const SizedBox(height: 12),
              _setupCard(theme),
              const SizedBox(height: 26),
              _sectionTitle('Console'),
              const SizedBox(height: 12),
              _commandPreview(),
              const SizedBox(height: 12),
              ConsoleView(lines: _c.log),
              const SizedBox(height: 20),
              _controls(),
            ],
          );
        },
      ),
    );
  }

  // --- sections -------------------------------------------------------------

  Widget _statusCard(ThemeData t) {
    final (color, label) = switch (_c.rootGranted) {
      true => (AppTheme.ok, 'Root access granted'),
      false => (AppTheme.danger, 'Root not available'),
      null => (const Color(0xFFB0B8C1), 'Root status unknown'),
    };
    return _card(
      Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: t.textTheme.titleSmall)),
          OutlinedButton(onPressed: _c.checkRoot, child: const Text('Check')),
        ],
      ),
    );
  }

  Widget _configCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Interface', '-i'),
          const SizedBox(height: 8),
          _text(
            _iface,
            hint: 'wlan0',
            onChanged: (v) => _c.update((s) => s.iface = v),
          ),
          const SizedBox(height: 20),
          _fieldLabel('Target BSSID', '-b · optional'),
          const SizedBox(height: 8),
          _text(
            _bssid,
            hint: 'AA:BB:CC:DD:EE:FF',
            caps: true,
            onChanged: (v) => _c.update((s) => s.bssid = v),
          ),
          const SizedBox(height: 20),
          _fieldLabel('WPS PIN', '-p · optional'),
          const SizedBox(height: 8),
          _text(
            _pin,
            hint: '4 or 8 digits',
            onChanged: (v) => _c.update((s) => s.pin = v),
          ),
          const SizedBox(height: 22),
          _fieldLabel('Attack mode', null),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AttackMode.values.map((m) {
              return ChoiceChip(
                label: Text(m.label),
                selected: _c.settings.mode == m,
                onSelected: (_) => _c.update((s) => s.mode = m),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _advancedCard() {
    final s = _c.settings;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Remove the default ExpansionTile divider lines for a calmer look.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          title: const Text('Show all parameters',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink)),
          subtitle: const Text('Delay, list file, and toggles',
              style: TextStyle(color: AppTheme.inkMuted, fontSize: 13)),
          children: [
            _fieldLabel('Delay between attempts', '-d · seconds'),
            const SizedBox(height: 8),
            _text(
              _delay,
              hint: 'e.g. 1.5',
              number: true,
              onChanged: (v) => _c.update((st) => st.delay = v),
            ),
            const SizedBox(height: 18),
            _fieldLabel('Vulnerable-devices list', '--vuln-list · path'),
            const SizedBox(height: 8),
            _text(
              _vuln,
              hint: 'vulnwsc.txt',
              onChanged: (v) => _c.update((st) => st.vulnList = v),
            ),
            const SizedBox(height: 10),
            const Divider(color: AppTheme.hairline, height: 28),
            _switch('Pixie-Dust full bruteforce', '-F', s.pixieForce,
                (v) => _c.update((st) => st.pixieForce = v)),
            _switch('Always print pixiewps command', '-X', s.showPixieCmd,
                (v) => _c.update((st) => st.showPixieCmd = v)),
            _switch('Save credentials on success', '-w', s.write,
                (v) => _c.update((st) => st.write = v)),
            _switch('Bring interface down when done', '--iface-down',
                s.ifaceDown, (v) => _c.update((st) => st.ifaceDown = v)),
            _switch('Run in a loop', '-l', s.loop,
                (v) => _c.update((st) => st.loop = v)),
            _switch('Reverse scan order', '-r', s.reverseScan,
                (v) => _c.update((st) => st.reverseScan = v)),
            _switch('MediaTek Wi-Fi driver', '--mtk-wifi', s.mtkWifi,
                (v) => _c.update((st) => st.mtkWifi = v)),
            _switch('Verbose output', '-v', s.verbose,
                (v) => _c.update((st) => st.verbose = v)),
          ],
        ),
      ),
    );
  }

  Widget _setupCard(ThemeData t) {
    return _card(
      Row(
        children: [
          Icon(
            _c.installed
                ? Icons.check_circle_rounded
                : Icons.inventory_2_outlined,
            size: 22,
            color: _c.installed ? AppTheme.ok : const Color(0xFF9AA5B1),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _c.installed ? 'Payload installed' : 'Extract OneShot + binaries',
              style: t.textTheme.titleSmall,
            ),
          ),
          FilledButton.tonal(
              onPressed: _c.install, child: const Text('Install')),
        ],
      ),
    );
  }

  Widget _commandPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Text(
        _c.commandPreview,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.4,
          color: AppTheme.inkSoft,
        ),
      ),
    );
  }

  Widget _controls() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _c.running ? null : _c.start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_c.running ? 'Running…' : 'Start'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _c.running ? _c.stop : null,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          ),
        ),
      ],
    );
  }

  // --- small building blocks ------------------------------------------------

  Widget _card(Widget child) =>
      Card(child: Padding(padding: const EdgeInsets.all(20), child: child));

  Widget _text(
    TextEditingController c, {
    required String hint,
    required ValueChanged<String> onChanged,
    bool caps = false,
    bool number = false,
  }) {
    return TextField(
      controller: c,
      onChanged: onChanged,
      textCapitalization:
          caps ? TextCapitalization.characters : TextCapitalization.none,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _switch(
    String title,
    String flag,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title,
          style: const TextStyle(
              color: AppTheme.ink, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(flag,
          style: const TextStyle(
              color: AppTheme.inkMuted, fontSize: 12, fontFamily: 'monospace')),
    );
  }

  Widget _sectionTitle(String s) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          s.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.inkMuted,
          ),
        ),
      );

  Widget _fieldLabel(String s, String? hint) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(s,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.inkSoft)),
          if (hint != null) ...[
            const SizedBox(width: 8),
            Text(hint,
                style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppTheme.inkMuted)),
          ],
        ],
      );
}
