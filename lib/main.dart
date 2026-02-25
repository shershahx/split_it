// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/services/cloud_db_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AGConnect is auto-initialized via agconnect-services.json
  // No explicit init call needed (handled by the plugin)

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize Cloud DB so the zone is ready before any repository call
  final cloudDb = CloudDbService();
  await cloudDb.init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: SplitItApp(),
    ),
  );
}