import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_it/core/providers/theme_provider.dart';
import 'package:split_it/features/account/presentation/screens/profile_screen.dart';
import 'package:split_it/features/account/presentation/screens/settings_screen.dart';
import 'package:split_it/features/auth/data/auth_service.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Names implements AuthService {
  final names = <String>[];
  Completer<AppUser>? pending;

  @override
  AppUser getCurrentUser() => const AppUser(uid: 'me', displayName: 'Alice');

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<AppUser> updateDisplayName(String name) async {
    names.add(name);
    return await pending?.future ?? AppUser(uid: 'me', displayName: name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final value in [-1, 3, 999, 'dark']) {
    test('invalid stored theme $value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': value});
      final notifier = ThemeModeNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, ThemeMode.system);
      notifier.dispose();
    });
  }

  test('saved theme loads and changes persist', () async {
    SharedPreferences.setMockInitialValues(
        {'theme_mode': ThemeMode.dark.index});
    final notifier = ThemeModeNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, ThemeMode.dark);
    await notifier.setThemeMode(ThemeMode.light);
    expect((await SharedPreferences.getInstance()).getInt('theme_mode'),
        ThemeMode.light.index);
    notifier.dispose();
  });

  test('initial load cannot overwrite a user selection', () async {
    SharedPreferences.setMockInitialValues(
        {'theme_mode': ThemeMode.dark.index});
    final notifier = ThemeModeNotifier();
    await notifier.setThemeMode(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, ThemeMode.light);
    notifier.dispose();
  });

  test('pending theme load is safe after disposal', () async {
    final notifier = ThemeModeNotifier();
    notifier.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets(
      'push is disabled and both bundled legal documents are selectable',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
    final push = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Push Notifications'),
    );
    expect(push.value, isFalse);
    expect(push.onChanged, isNull);
    expect(find.textContaining('not implemented'), findsOneWidget);

    for (final document in [
      ('Privacy Policy', 'PRIVACY_POLICY.md'),
      ('Terms of Service', 'TERMS_OF_SERVICE.md'),
    ]) {
      final source = await rootBundle.loadString(document.$2);
      await tester.ensureVisible(find.text(document.$1));
      await tester.tap(find.text(document.$1));
      await tester.pumpAndSettle();
      expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
          source);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  Future<void> openEditor(WidgetTester tester, _Names names) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(names)],
      child: const MaterialApp(home: ProfileScreen()),
    ));
    await tester.scrollUntilVisible(find.text('Edit Profile'), 200);
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'name validation rejects blank and over 80, and trims valid names',
      (tester) async {
    final names = _Names();
    await openEditor(tester, names);
    for (final invalid in ['   ', List.filled(81, 'a').join()]) {
      await tester.enterText(find.byType(TextFormField), invalid);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name between 1 and 80 characters.'),
          findsOneWidget);
      expect(names.names, isEmpty);
    }
    await tester.enterText(find.byType(TextFormField), '  Bob  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(names.names, ['Bob']);
    expect(find.text('Name updated successfully'), findsOneWidget);
  });

  testWidgets('saving disables duplicate submission and errors allow retry',
      (tester) async {
    final names = _Names()..pending = Completer<AppUser>();
    await openEditor(tester, names);
    await tester.enterText(find.byType(TextFormField), 'Bob');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(names.names, ['Bob']);
    names.pending!.completeError(StateError('Profile synchronization failed'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Profile synchronization failed'), findsOneWidget);
    names.pending = null;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(names.names, ['Bob', 'Bob']);
    expect(find.text('Name updated successfully'), findsOneWidget);
  });

  testWidgets('disposing the editor during a save is safe', (tester) async {
    final names = _Names()..pending = Completer<AppUser>();
    await openEditor(tester, names);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    names.pending!.completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
