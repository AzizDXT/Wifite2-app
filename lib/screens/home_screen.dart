import 'package:flutter/material.dart';

import '../oneshot_controller.dart';
import '../theme.dart';
import '../widgets/console_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _c = OneShotController();
  late final TextEditingController _iface =
      TextEditingController(text: _c.iface);
  final _bssid = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    _iface.dispose();
    _bssid.dispose();
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
        builder: (context, _) => ListView(
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
            _sectionTitle('Configuration'),
            const SizedBox(height: 12),
            _configCard(),
            const SizedBox(height: 26),
            _sectionTitle('Setup'),
            const SizedBox(height: 12),
            _setupCard(theme),
            const SizedBox(height: 26),
            _sectionTitle('Console'),
            const SizedBox(height: 12),
            ConsoleView(lines: _c.log),
            const SizedBox(height: 20),
            _controls(),
          ],
        ),
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
          OutlinedButton(
            onPressed: _c.checkRoot,
            child: const Text('Check'),
          ),
        ],
      ),
    );
  }

  Widget _configCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Interface'),
          const SizedBox(height: 8),
          TextField(
            controller: _iface,
            onChanged: (v) => _c.iface = v.trim().isEmpty ? 'wlan0' : v.trim(),
            decoration: const InputDecoration(hintText: 'wlan0'),
          ),
          const SizedBox(height: 20),
          _fieldLabel('Target BSSID  ·  optional'),
          const SizedBox(height: 8),
          TextField(
            controller: _bssid,
            onChanged: (v) => _c.bssid = v,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'AA:BB:CC:DD:EE:FF'),
          ),
          const SizedBox(height: 20),
          _fieldLabel('Attack mode'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AttackMode>(
              segments: const [
                ButtonSegment(
                    value: AttackMode.pixieDust, label: Text('Pixie-Dust')),
                ButtonSegment(
                    value: AttackMode.bruteforce, label: Text('Bruteforce')),
                ButtonSegment(
                    value: AttackMode.pushButton, label: Text('PBC')),
              ],
              selected: {_c.mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _c.setMode(s.first),
            ),
          ),
        ],
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
              _c.installed
                  ? 'Payload installed'
                  : 'Extract OneShot + binaries',
              style: t.textTheme.titleSmall,
            ),
          ),
          FilledButton.tonal(
            onPressed: _c.install,
            child: const Text('Install'),
          ),
        ],
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

  // --- helpers --------------------------------------------------------------

  Widget _card(Widget child) =>
      Card(child: Padding(padding: const EdgeInsets.all(20), child: child));

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

  Widget _fieldLabel(String s) => Text(
        s,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.inkSoft,
        ),
      );
}
