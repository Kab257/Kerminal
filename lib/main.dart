import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const KerminalApp());
}

class KerminalApp extends StatefulWidget {
  const KerminalApp({super.key});

  @override
  State<KerminalApp> createState() => _KerminalAppState();
}

class _KerminalAppState extends State<KerminalApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kerminal',
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: KerminalHome(
        themeMode: _themeMode,
        onThemeChanged: (mode) {
          setState(() => _themeMode = mode);
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF050805) : const Color(0xFFF5F7FA),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00FF66),
        brightness: brightness,
      ),
      fontFamily: 'monospace',
    );
  }
}

class KerminalHome extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const KerminalHome({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<KerminalHome> createState() => _KerminalHomeState();
}

class _KerminalHomeState extends State<KerminalHome> {
  static const _shell = MethodChannel('kerminal/shell');
  static const _outputChannel = EventChannel('kerminal/shell/output');
  

  final TextEditingController _commandController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final FocusNode _commandFocusNode = FocusNode();

  final List<String> _output = [];

  StreamSubscription<dynamic>? _outputSubscription;

  String _currentDirectory = '/';
  String _fontFamily = 'monospace';

  double _fontSize = 14;

  Color _terminalColor =
      const Color(0xFF00FF66);

  bool _running = false;
  bool _showCommands = true;

  @override
  void initState() {
    super.initState();

    _startShell();

    _outputSubscription =
        _outputChannel.receiveBroadcastStream().listen((event) {
      final text = event.toString();

      if (text.isEmpty) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _output.addAll(
          text
              .split('\n')
              .where((line) => line.isNotEmpty),
        );
      });

      _updateDirectoryFromOutput(text);
      _scrollToBottom();
    });
  }

  Future<void> _startShell() async {
    try {
      await _shell.invokeMethod('start');

      if (!mounted) {
        return;
      }

      setState(() {
        _running = true;
      });

      await _sendInternal('pwd');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _output.add('Shell error: $e');
      });
    }
  }

  Future<void> _sendInternal(String command) async {
    try {
      await _shell.invokeMethod(
        'write',
        {
          'command': '$command\n',
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _output.add('Command error: $e');
      });
    }
  }

  Future<void> _sendCommand() async {
    final command =
        _commandController.text.trim();

    if (command.isEmpty || !_running) {
      return;
    }

    if (_showCommands) {
      setState(() {
        _output.add(
          '$_currentDirectory \$ $command',
        );
      });
    }

    _commandController.clear();

    await _sendInternal(command);

    if (command == 'cd' ||
        command.startsWith('cd ') ||
        command == 'pwd') {
      await Future.delayed(
        const Duration(milliseconds: 80),
      );

      await _sendInternal('pwd');
    }

    _scrollToBottom();
  }

  void _updateDirectoryFromOutput(String text) {
    final lines = text.split('\n');

    for (final line in lines) {
      final path = line.trim();

      if (path.startsWith('/') &&
          !path.contains(' ')) {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentDirectory = path;
        });

        break;
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration:
            const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _commandFocusNode.dispose();

    _outputSubscription?.cancel();

    _shell.invokeMethod('stop');

    super.dispose();
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Kerminal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  subtitle:
                      Text('Terminal & Tools'),
                ),

                const Divider(),

                ListTile(
                  leading:
                      const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  subtitle: Text(
                    widget.themeMode ==
                            ThemeMode.dark
                        ? 'Dark'
                        : 'Light',
                  ),
                  onTap: _showThemePicker,
                ),

                ListTile(
                  leading:
                      const Icon(Icons.text_fields),
                  title: const Text('Font'),
                  subtitle:
                      Text(_fontFamily),
                  onTap: _showFontPicker,
                ),

                ListTile(
                  leading:
                      const Icon(Icons.format_size),
                  title:
                      const Text('Font size'),
                  subtitle: Text(
                    '${_fontSize.toInt()} px',
                  ),
                  onTap:
                      _showFontSizePicker,
                ),

                ListTile(
                  leading: const Icon(
                    Icons.color_lens_outlined,
                  ),
                  title: const Text(
                    'Terminal color',
                  ),
                  subtitle: const Text(
                    'Text / prompt color',
                  ),
                  onTap:
                      _showColorPicker,
                ),

                SwitchListTile(
                  secondary:
                      const Icon(Icons.terminal),
                  title:
                      const Text('Show commands'),
                  subtitle: const Text(
                    'Display commands generated by Tools',
                  ),
                  value: _showCommands,
                  onChanged: (value) {
                    setState(() {
                      _showCommands = value;
                    });

                    Navigator.pop(context);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.build_outlined,
                  ),
                  title: const Text('Tools'),
                  subtitle: const Text(
                    'Files, duplicates, large files, media',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showTools();
                  },
                ),

                ListTile(
                  leading:
                      const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAbout();
                  },
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThemePicker() {
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return RadioGroup<ThemeMode>(
          groupValue: widget.themeMode,
          onChanged: (value) {
            if (value != null) {
              widget.onThemeChanged(value);
              Navigator.pop(context);
            }
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Theme',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              RadioListTile<ThemeMode>(
                title: Text('Dark'),
                value: ThemeMode.dark,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Light'),
                value: ThemeMode.light,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFontPicker() {
    Navigator.pop(context);

    final fonts = [
      'monospace',
      'Courier',
      'Courier New',
      'Roboto Mono',
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Font type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final font in fonts)
              ListTile(
                title: Text(
                  font,
                  style: TextStyle(
                    fontFamily: font,
                  ),
                ),
                trailing:
                    _fontFamily == font
                        ? const Icon(Icons.check)
                        : null,
                onTap: () {
                  setState(() {
                    _fontFamily = font;
                  });

                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }

  void _showFontSizePicker() {
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        double value = _fontSize;

        return StatefulBuilder(
          builder:
              (context, setSheetState) {
            return Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                30,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Font size: ${value.toInt()} px',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    min: 10,
                    max: 30,
                    divisions: 20,
                    value: value,
                    onChanged: (newValue) {
                      setSheetState(() {
                        value = newValue;
                      });

                      setState(() {
                        _fontSize = newValue;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showColorPicker() {
    Navigator.pop(context);

    final colors = <String, Color>{
      'Matrix Green':
          const Color(0xFF00FF66),
      'Cyber Blue':
          const Color(0xFF00BFFF),
      'Amber':
          const Color(0xFFFFB000),
      'Classic White':
          const Color(0xFFE8E8E8),
      'Red':
          const Color(0xFFFF4040),
      'Cyan':
          const Color(0xFF00FFFF),
      'Purple':
          const Color(0xFFB56CFF),
    };

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Terminal color',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final entry
                in colors.entries)
              ListTile(
                leading: CircleAvatar(
                  radius: 9,
                  backgroundColor:
                      entry.value,
                ),
                title:
                    Text(entry.key),
                trailing:
                    _terminalColor ==
                            entry.value
                        ? const Icon(
                            Icons.check,
                          )
                        : null,
                onTap: () {
                  setState(() {
                    _terminalColor =
                        entry.value;
                  });

                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }

  void _showTools() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ToolsPage(
          terminalColor: _terminalColor,
          showCommands: _showCommands,
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Kerminal',
      applicationVersion: '0.3.0+3',
      applicationLegalese:
          'Android Terminal & Tools',
      children: const [
        SizedBox(height: 16),
        Text(
          'A powerful Android terminal with graphical '
          'file and media tools.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: _terminalColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        _terminalColor.withValues(
                      alpha: 0.7,
                    ),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            const Text(
              'Kerminal',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            icon:
                const Icon(Icons.more_vert),
            onPressed: _showMenu,
          ),
        ],
      ),

      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: dark
                      ? const Color(0xFF030603)
                      : const Color(0xFFF8F9FA),
                  child:
                      ListView.builder(
                    controller:
                        _scrollController,
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      110,
                    ),
                    itemCount:
                        _output.length + 1,
                    itemBuilder:
                        (context, index) {
                      if (index ==
                          _output.length) {
                        return _buildPrompt();
                      }

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 3,
                        ),
                        child:
                            SelectableText(
                          _output[index],
                          style:
                              TextStyle(
                            fontFamily:
                                _fontFamily,
                            fontSize:
                                _fontSize,
                            height: 1.35,
                            color:
                                _terminalColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child:
                _buildFloatingCommandBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrompt() {
    return Padding(
      padding:
          const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '$_currentDirectory \$',
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: _fontSize,
                fontWeight:
                    FontWeight.bold,
                color: _terminalColor,
              ),
            ),
          ),

          const SizedBox(width: 5),

          Container(
            width: 8,
            height: _fontSize + 2,
            color: _terminalColor,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCommandBar() {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Material(
      elevation: 12,
      borderRadius:
          BorderRadius.circular(18),
      color: dark
          ? const Color(0xFF111711)
          : Colors.white,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: _terminalColor,
              ),
              onPressed: () {
                _commandController
                    .selection =
                    TextSelection.fromPosition(
                  TextPosition(
                    offset:
                        _commandController
                            .text
                            .length,
                  ),
                );

                _commandFocusNode
                    .requestFocus();
              },
            ),

            Expanded(
              child: TextField(
                controller:
                    _commandController,
                focusNode:
                    _commandFocusNode,
                style: TextStyle(
                  fontFamily:
                      _fontFamily,
                  fontSize: _fontSize,
                  color:
                      _terminalColor,
                ),
                cursorColor:
                    _terminalColor,
                decoration:
                    const InputDecoration(
                  hintText:
                      'Enter command...',
                  border:
                      InputBorder.none,
                  isDense: true,
                ),
                textInputAction:
                    TextInputAction.send,
                onSubmitted: (_) =>
                    _sendCommand(),
              ),
            ),

            IconButton(
              icon: Icon(
                Icons.arrow_upward_rounded,
                color: _terminalColor,
              ),
              onPressed:
                  _sendCommand,
            ),
          ],
        ),
      ),
    );
  }
}

class ToolsPage extends StatefulWidget {
  final Color terminalColor;
  final bool showCommands;

  const ToolsPage({
    super.key,
    required this.terminalColor,
    required this.showCommands,
  });

  @override
  State<ToolsPage> createState() =>
      _ToolsPageState();
}

class _ToolsPageState
    extends State<ToolsPage> {
  static const MethodChannel _tools =
      MethodChannel('kerminal/tools');

  bool _busy = false;

  String _status =
      'Ready';

  List<Map<String, dynamic>> _files =
      [];

  Future<void> _loadFiles() async {
    setState(() {
      _busy = true;
      _status = 'Scanning storage...';
    });

    try {
      final result =
          await _tools.invokeMethod(
        'listDirectory',
        {
          'path': '/storage/emulated/0',
        },
      );

      final data =
          List<Map<String, dynamic>>.from(
        (result as List).map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        ),
      );

      setState(() {
        _files = data;
        _status =
            '${data.length} items';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _getStorageInfo() async {
    setState(() {
      _busy = true;
      _status =
          'Reading storage information...';
    });

    try {
      final result =
          await _tools.invokeMethod(
        'storageInfo',
      );

      final info =
          Map<String, dynamic>.from(
        result,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title:
                const Text('Storage'),
            content: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Total: ${_formatBytes(info['total'])}',
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'Used: ${_formatBytes(info['used'])}',
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'Free: ${_formatBytes(info['free'])}',
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _status = 'Storage ready';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  String _formatBytes(dynamic value) {
    final bytes =
        (value as num?)?.toInt() ?? 0;

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes <
        1024 * 1024) {
      return
          '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes <
        1024 * 1024 * 1024) {
      return
          '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return
        '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _iconForItem(
    Map<String, dynamic> item,
  ) {
    final isDirectory =
        item['isDirectory'] == true;

    if (isDirectory) {
      return Icons.folder;
    }

    final type =
        item['type']?.toString() ?? '';

    if (type.startsWith('image/')) {
      return Icons.image;
    }

    if (type.startsWith('video/')) {
      return Icons.video_file;
    }

    if (type.startsWith('audio/')) {
      return Icons.audio_file;
    }

    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Tools'),
        actions: [
          IconButton(
            tooltip: 'Storage',
            icon: const Icon(
              Icons.storage_outlined,
            ),
            onPressed:
                _busy
                    ? null
                    : _getStorageInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.folder_outlined,
                        color:
                            widget.terminalColor,
                      ),
                      title: const Text(
                        'File Manager',
                      ),
                      subtitle:
                          Text(_status),
                      onTap:
                          _busy
                              ? null
                              : _loadFiles,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child:
                _files.isEmpty
                    ? _buildToolsGrid()
                    : _buildFileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid() {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        20,
      ),
      children: [
        _toolCard(
          Icons.folder_outlined,
          'File Manager',
          'Browse files and folders.',
          _loadFiles,
        ),
        _toolCard(
          Icons.content_copy_outlined,
          'Duplicates',
          'Find exact duplicate files.',
          () {
            _showComingSoon(
              'Duplicate scanner',
            );
          },
        ),
        _toolCard(
          Icons.storage_outlined,
          'Large Files',
          'Find files from 250 MB upward.',
          () {
            _showComingSoon(
              'Large file scanner',
            );
          },
        ),
        _toolCard(
          Icons.image_outlined,
          'Similar Images',
          'Visual image similarity analyzer.',
          () {
            _showComingSoon(
              'Image AI analyzer',
            );
          },
        ),
        _toolCard(
          Icons.video_library_outlined,
          'Similar Videos',
          'Compare sampled video frames.',
          () {
            _showComingSoon(
              'Video AI analyzer',
            );
          },
        ),
        _toolCard(
          Icons.audiotrack_outlined,
          'Audio',
          'Analyze audio files.',
          () {
            _showComingSoon(
              'Audio analyzer',
            );
          },
        ),
      ],
    );
  }

  Widget _toolCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.all(16),
        leading: Icon(
          icon,
          size: 30,
          color:
              widget.terminalColor,
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 5,
          ),
          child:
              Text(subtitle),
        ),
        trailing:
            const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      itemCount: _files.length,
      itemBuilder:
          (context, index) {
        final item =
            _files[index];

        final name =
            item['name']
                    ?.toString() ??
                '';

        final size =
            item['size'];

        final isDirectory =
            item['isDirectory'] ==
                true;

        return ListTile(
          leading: Icon(
            _iconForItem(item),
            color:
                widget.terminalColor,
          ),
          title:
              Text(name),
          subtitle:
              Text(
            isDirectory
                ? 'Folder'
                : _formatBytes(size),
          ),
          trailing:
              isDirectory
                  ? const Icon(
                      Icons.chevron_right,
                    )
                  : null,
        );
      },
    );
  }

  void _showComingSoon(String name) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '$name will be implemented in the next Tools stage.',
        ),
      ),
    );
  }
}