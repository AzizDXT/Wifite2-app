import 'package:flutter/material.dart';

/// A calm dark console panel that streams log lines and auto-scrolls.
class ConsoleView extends StatefulWidget {
  const ConsoleView({super.key, required this.lines});

  final List<String> lines;

  @override
  State<ConsoleView> createState() => _ConsoleViewState();
}

class _ConsoleViewState extends State<ConsoleView> {
  final _scroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    // Keep the newest output in view after each rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121821),
        borderRadius: BorderRadius.circular(20),
      ),
      child: widget.lines.isEmpty
          ? const Center(
              child: Text(
                'Output will appear here',
                style: TextStyle(color: Color(0xFF5C6B7A), fontSize: 13),
              ),
            )
          : ListView.builder(
              controller: _scroll,
              itemCount: widget.lines.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: SelectableText(
                  widget.lines[i],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                    color: _lineColor(widget.lines[i]),
                  ),
                ),
              ),
            ),
    );
  }

  Color _lineColor(String line) {
    if (line.startsWith('[!]')) return const Color(0xFFE57373); // error
    if (line.startsWith('[+]')) return const Color(0xFF81C995); // success
    if (line.startsWith('[*]')) return const Color(0xFF7FB0E0); // info
    return const Color(0xFFCBD2D9); // default
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}
