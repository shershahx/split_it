// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
<<<<<<< HEAD

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
=======
import 'core/services/secure_auth_storage.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
);
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

<<<<<<< HEAD
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Run with '
      '--dart-define=SUPABASE_URL=... and '
      '--dart-define=SUPABASE_ANON_KEY=...',
=======
  if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Run with '
      '--dart-define=SUPABASE_URL=... and '
      '--dart-define=SUPABASE_PUBLISHABLE_KEY=...',
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
<<<<<<< HEAD
    publishableKey: _supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
=======
    publishableKey: _supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: SecureAuthStorage(),
      pkceAsyncStorage: SecurePkceStorage(),
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
    ),
  );

  // Initialize Hive for local storage
  await Hive.initFlutter();

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

<<<<<<< HEAD
  runApp(
    const ProviderScope(
      child: SplitItApp(),
    ),
  );
=======
  runApp(const ProviderScope(child: SplitItApp()));
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
}
