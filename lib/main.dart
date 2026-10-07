import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const KerminalApp());
}

class KerminalApp extends StatelessWidget {
  const KerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kerminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
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
  static const MethodChannel _shellChannel =
      MethodChannel('kerminal/shell');

  static const EventChannel _outputChannel =
      EventChannel('kerminal/shell/output');

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _output = [
    'Kerminal v0.2.0',
    'Real Android shell',
    '',
  ];

  StreamSubscription? _outputSubscription;

  @override
  void initState() {
    super.initState();

    _outputSubscription = _outputChannel
        .receiveBroadcastStream()
        .listen(_handleOutput);

    _startShell();
  }

  Future<void> _startShell() async {
    try {
      await _shellChannel.invokeMethod('start');
    } catch (e) {
      _addOutput('Shell error: $e');
    }
  }

  void _handleOutput(dynamic data) {
    if (!mounted) return;

    final text = data.toString();

    setState(() {
      _output.add(text);
    });

    _scrollToBottom();
  }

  Future<void> _executeCommand() async {
    final command = _controller.text;

    if (command.trim().isEmpty) {
      return;
    }

    setState(() {
      _output.add('\$ $command');
    });

    _controller.clear();

    try {
      await _shellChannel.invokeMethod(
        'write',
        {
          'command': '$command\n',
        },
      );
    } catch (e) {
      _addOutput('Error: $e');
    }

    _scrollToBottom();
  }

  void _addOutput(String text) {
    if (!mounted) return;

    setState(() {
      _output.add(text);
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();

    _shellChannel.invokeMethod('stop');

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Kerminal'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _output.length,
              itemBuilder: (context, index) {
                return Text(
                  _output[index],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Text(
                    '\$ ',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.greenAccent,
                      fontSize: 15,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter command...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _executeCommand(),
                    ),
                  ),
                  IconButton(
                    onPressed: _executeCommand,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
