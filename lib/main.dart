import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(200, 80),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(Colors.transparent); // Принудительно сбрасываем фон окна в ОС
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setIgnoreMouseEvents(true);
    
    // Изначально прячем окно за экраном с нулевой прозрачностью
    await windowManager.setPosition(const Offset(-5000, -5000));
    await windowManager.setOpacity(0.0);
    await windowManager.show(); 

    // Настраиваем системный трей
    String exePath = Platform.resolvedExecutable;
    String dirPath = File(exePath).parent.path;
    String iconPath = '$dirPath/data/flutter_assets/assets/app_icon.ico';
    
    try {
      await trayManager.setIcon(iconPath);
    } catch (e) {
      debugPrint('Не удалось загрузить иконку трея: $e');
    }

    Menu menu = Menu(items: [
      MenuItem(key: 'exit_app', label: 'Выход'),
    ]);
    await trayManager.setContextMenu(menu);
  });

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: BackgroundOverlayManager(),
    );
  }
}

class BackgroundOverlayManager extends StatefulWidget {
  const BackgroundOverlayManager({super.key});

  @override
  State<BackgroundOverlayManager> createState() => _BackgroundOverlayManagerState();
}

class _BackgroundOverlayManagerState extends State<BackgroundOverlayManager> with TrayListener {
  Timer? _openTimer;
  Timer? _closeTimer;
  final Random random = Random();
  
  String _timeString = '';
  bool _isOverlayVisible = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _voiceLines = [
    'audio/voice1.mp3',
    'audio/voice2.mp3',
    'audio/voice3.mp3',
  ];

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _updateTime();
    _scheduleNextOverlay();
  }

  void _updateTime() {
    final dt = DateTime.now();
    if (mounted) {
      setState(() {
        _timeString = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _scheduleNextOverlay() {
    _openTimer = Timer(const Duration(seconds: 10), () async {
      _updateTime();

      if (mounted) {
        setState(() => _isOverlayVisible = true);
      }

      // Перемещаем окно в правый верхний угол и делаем видимым
      await windowManager.setPosition(const Offset(1060, 20));
      await windowManager.setOpacity(1.0);
      await windowManager.setAlwaysOnTop(true);
      
      if (_voiceLines.isNotEmpty) {
        final randomIndex = random.nextInt(_voiceLines.length);
        await _audioPlayer.play(AssetSource(_voiceLines[randomIndex]));
      }

      // Таймер закрытия на 5 секунд
      _closeTimer = Timer(const Duration(seconds: 5), () async {
        await windowManager.setOpacity(0.0);
        await windowManager.setPosition(const Offset(-5000, -5000));
        
        if (mounted) {
          setState(() => _isOverlayVisible = false);
        }
        _scheduleNextOverlay(); 
      });
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void onTrayIconRightMouseDown() async {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'exit_app') {
      _openTimer?.cancel();
      _closeTimer?.cancel();
      await _audioPlayer.dispose();
      await trayManager.destroy();
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Безопасная верстка: Scaffold всегда прозрачный.
    // Если оверлей должен спать — возвращаем пустоту, иначе — текст строго по центру окна.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isOverlayVisible
          ? Center(
              child: Material( // Добавляем Material для корректного отображения текста в прозрачном окне
                color: Colors.transparent,
                child: Text(
                  _timeString,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 34, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}