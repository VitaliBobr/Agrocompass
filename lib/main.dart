import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_screen.dart';
import 'utils/app_logger.dart';
import 'utils/debug_probe.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugProbeLog(
      runId: 'run1',
      hypothesisId: 'H5',
      location: 'main.dart:11',
      message: 'FlutterError caught',
      data: {
        'exception': details.exceptionAsString(),
      },
    );
    AppLogger.error(
      'flutter.framework',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugProbeLog(
      runId: 'run1',
      hypothesisId: 'H5',
      location: 'main.dart:24',
      message: 'PlatformDispatcher error',
      data: {
        'error': error.toString(),
      },
    );
    AppLogger.error(
      'flutter.platform',
      'Unhandled platform error',
      error: error,
      stackTrace: stack,
    );
    return true;
  };
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const AgrokilarCompassApp());
}

class AgrokilarCompassApp extends StatelessWidget {
  const AgrokilarCompassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Курсоуказатель',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF2196F3),
          surface: const Color(0xFF121212),
          error: const Color(0xFFF44336),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onError: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
