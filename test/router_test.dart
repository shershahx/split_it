import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_it/core/router/app_router.dart';
import 'package:split_it/features/account/presentation/screens/account_screen.dart';
import 'package:split_it/features/account/presentation/screens/profile_screen.dart';
import 'package:split_it/features/auth/data/auth_service.dart';
import 'package:split_it/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:split_it/features/auth/presentation/screens/login_screen.dart';
import 'package:split_it/features/auth/presentation/screens/register_screen.dart';
import 'package:split_it/features/auth/presentation/screens/splash_screen.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/groups/presentation/screens/groups_screen.dart';
import 'package:split_it/features/groups/providers/groups_provider.dart';
import 'package:split_it/features/home/presentation/screens/home_screen.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = AppUser(
  uid: 'me',
  email: 'alice@example.com',
  displayName: 'Alice',
);

class _OfflineAuthService implements AuthService {
  @override
  AppUser? getCurrentUser() => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(AsyncValue<AppUser?> initialState)
      : super(_OfflineAuthService(), onPasswordRecovery: () {}) {
    state = initialState;
  }

  void emit(AsyncValue<AppUser?> value) => state = value;

  @override
  Future<void> updateDisplayName(String name) async {
    final user = state.requireValue!;
    state = AsyncData(AppUser(
      uid: user.uid,
      email: user.email,
      displayName: name,
    ));
  }

  @override
  Future<void> signOut() async => state = const AsyncData(null);
}

class _RouterApp extends ConsumerWidget {
  const _RouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(routerConfig: ref.watch(appRouterProvider));
  }
}

class _Harness {
  _Harness(AsyncValue<AppUser?> initialState) {
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => _TestAuthNotifier(initialState)),
      groupsProvider.overrideWith((ref) async => []),
      // Any accidental access to production auth/backend dependencies must fail.
      supabaseClientProvider.overrideWith((ref) {
        throw StateError('Router tests must not access Supabase');
      }),
    ]);
    router = container.read(appRouterProvider);
    auth = container.read(authStateProvider.notifier) as _TestAuthNotifier;
  }

  late final ProviderContainer container;
  late final GoRouter router;
  late final _TestAuthNotifier auth;

  Future<void> mount(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const _RouterApp(),
    ));
  }

  void expectRoute(WidgetTester tester, String path, Type screen,
      {String? browserPath}) {
    expect(container.read(appRouterProvider), same(router));
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router));
    // Imperative pushes do not update the browser URL in this GoRouter version.
    expect(router.routeInformationProvider.value.uri.path, browserPath ?? path);
    expect(router.routerDelegate.currentConfiguration.uri.path,
        browserPath ?? path);
    expect(find.byType(screen), findsOneWidget);
    expect(
        GoRouterState.of(tester.element(find.byType(screen))).uri.path, path);
    expect(tester.takeException(), isNull);
  }
}

void main() {
  testWidgets('signed-out users are guarded on all protected route shapes',
      (tester) async {
    final harness = _Harness(const AsyncData(null));
    await harness.mount(tester);
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/login', LoginScreen);

    for (final path in [
      '/home',
      '/groups',
      '/groups/create',
      '/groups/group-id',
      '/groups/group-id/add-expense',
      '/groups/group-id/settle',
      '/friends',
      '/friends/add',
      '/friends/friend-id',
      '/activity',
      '/account',
      '/account/profile',
      '/account/settings',
      '/expense/expense-id',
      '/scan-receipt?groupId=group-id',
    ]) {
      harness.router.go(path);
      await tester.pumpAndSettle();
      harness.expectRoute(tester, '/login', LoginScreen);
      expect(find.byType(HomeScreen), findsNothing, reason: path);
    }
  });

  testWidgets('signed-out users can open every public auth screen',
      (tester) async {
    final harness = _Harness(const AsyncData(null));
    await harness.mount(tester);
    await tester.pumpAndSettle();

    for (final route in [
      ('/register', RegisterScreen),
      ('/forgot-password', ForgotPasswordScreen),
      ('/login', LoginScreen),
    ]) {
      harness.router.go(route.$1);
      await tester.pumpAndSettle();
      harness.expectRoute(tester, route.$1, route.$2);
    }
  });

  testWidgets('loading auth stays on splash and resolving signs in to groups',
      (tester) async {
    final harness = _Harness(const AsyncLoading());
    await harness.mount(tester);
    // Splash has a continuous progress animation, so do not pumpAndSettle here.
    await tester.pump();
    harness.expectRoute(tester, '/', SplashScreen);

    harness.router.go('/account/profile');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    harness.expectRoute(tester, '/', SplashScreen);

    harness.auth.emit(const AsyncData(_user));
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/groups', GroupsScreen);
  });

  testWidgets('sign-in refreshes login to groups without replacing the router',
      (tester) async {
    final harness = _Harness(const AsyncData(null));
    await harness.mount(tester);
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/login', LoginScreen);

    harness.auth.emit(const AsyncData(_user));
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/groups', GroupsScreen);
    expect(find.byType(HomeScreen), findsOneWidget);

    for (final path in ['/', '/login', '/register', '/forgot-password']) {
      harness.router.go(path);
      await tester.pumpAndSettle();
      harness.expectRoute(tester, '/groups', GroupsScreen);
    }
  });

  testWidgets(
      'display-name update preserves router, page, shell and back stack',
      (tester) async {
    final harness = _Harness(const AsyncData(_user));
    await harness.mount(tester);
    await tester.pumpAndSettle();
    harness.router.go('/account');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Profile'));
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/account/profile', ProfileScreen,
        browserPath: '/account');
    final profile = tester.element(find.byType(ProfileScreen));
    final shell = tester.state(find.byType(HomeScreen));
    expect(harness.router.canPop(), isTrue);
    expect(find.text('Alice'), findsWidgets);

    await harness.auth.updateDisplayName('Bob');
    await tester.pumpAndSettle();

    harness.expectRoute(tester, '/account/profile', ProfileScreen,
        browserPath: '/account');
    expect(tester.element(find.byType(ProfileScreen)), same(profile));
    expect(tester.state(find.byType(HomeScreen)), same(shell));
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('Alice'), findsNothing);
    expect(harness.router.canPop(), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/account', AccountScreen);
  });

  testWidgets('password recovery forces forgot-password until cleared',
      (tester) async {
    final harness = _Harness(const AsyncData(_user));
    await harness.mount(tester);
    await tester.pumpAndSettle();
    harness.router.go('/account/profile');
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/account/profile', ProfileScreen);

    harness.container.read(passwordRecoveryProvider.notifier).state = true;
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/forgot-password', ForgotPasswordScreen);
    expect(find.byType(HomeScreen), findsNothing);

    for (final path in ['/groups', '/account/profile', '/login', '/register']) {
      harness.router.go(path);
      await tester.pumpAndSettle();
      harness.expectRoute(tester, '/forgot-password', ForgotPasswordScreen);
    }

    harness.container.read(passwordRecoveryProvider.notifier).state = false;
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/groups', GroupsScreen);
  });

  testWidgets('sign-out guards the current page and subsequent navigation',
      (tester) async {
    final harness = _Harness(const AsyncData(_user));
    await harness.mount(tester);
    await tester.pumpAndSettle();
    harness.router.go('/account/profile');
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/account/profile', ProfileScreen);

    await harness.auth.signOut();
    await tester.pumpAndSettle();
    harness.expectRoute(tester, '/login', LoginScreen);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);

    for (final path in ['/groups', '/account/profile', '/expense/expense-id']) {
      harness.router.go(path);
      await tester.pumpAndSettle();
      harness.expectRoute(tester, '/login', LoginScreen);
    }
  });
}
