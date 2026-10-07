import 'package:flutter/material.dart';

void main() {
  runApp(const KerminalApp());
}

class KerminalApp extends StatelessWidget {
  const KerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kerminal',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        fontFamily: 'monospace',
      ),
      home: const TerminalScreen(),
    );
  }
}

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _output = [
    'Kerminal v0.1.0',
    'Flutter terminal interface',
    '',
    'Type "help" to see available commands.',
    '',
  ];

  void _executeCommand() {
    final command = _controller.text.trim();

    if (command.isEmpty) {
      return;
    }

    setState(() {
      _output.add('\$ $command');

      switch (command) {
        case 'help':
          _output.addAll([
            'Available commands:',
            '  help       Show this help message',
            '  clear      Clear terminal',
            '  echo       Print text',
            '  pwd        Show current directory',
            '  whoami     Show current user',
            '  uname      Show system information',
          ]);
          break;

        case 'clear':
          _output.clear();
          break;

        case 'pwd':
          _output.add('/data/data/com.kerminal/files');
          break;

        case 'whoami':
          _output.add('kerminal');
          break;

        case 'uname':
          _output.add('Kerminal Android');
          break;

        default:
          if (command.startsWith('echo ')) {
            _output.add(command.substring(5));
          } else {
            _output.add('Command not found: $command');
          }
      }

      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kerminal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF080808),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _output.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _output[index],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '\$',
                    style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      cursorColor: const Color(0xFF00FF88),
                      decoration: const InputDecoration(
                        hintText: 'Enter command...',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _executeCommand(),
                    ),
                  ),
                  IconButton(
                    onPressed: _executeCommand,
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: 'Run command',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}