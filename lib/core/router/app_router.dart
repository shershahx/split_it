import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/groups/presentation/screens/groups_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/create_group_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/friends/presentation/screens/friend_detail_screen.dart';
import '../../features/friends/presentation/screens/add_friend_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/expenses/presentation/screens/expense_detail_screen.dart';
import '../../features/expenses/presentation/screens/scan_receipt_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/account/presentation/screens/profile_screen.dart';
import '../../features/account/presentation/screens/settings_screen.dart';
import '../../features/settle/presentation/screens/settle_up_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
      final isLoading = authState.maybeWhen(
        loading: () => true,
        orElse: () => false,
      );
      
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final isSplash = state.matchedLocation == '/';

      // Stay on splash while loading auth state
      if (isLoading && isSplash) return null;
      if (isLoading) return '/';

      if (isSplash) {
        return isLoggedIn ? '/groups' : '/login';
      }

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/groups';
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main Shell with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          // Groups Tab
          GoRoute(
            path: '/home',
            name: 'home',
            redirect: (context, state) => '/groups',
          ),
          GoRoute(
            path: '/groups',
            name: 'groups',
            builder: (context, state) => const GroupsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'create-group',
                builder: (context, state) => const CreateGroupScreen(),
              ),
              GoRoute(
                path: ':groupId',
                name: 'group-detail',
                builder: (context, state) {
                  final groupId = state.pathParameters['groupId']!;
                  return GroupDetailScreen(groupId: groupId);
                },
                routes: [
                  GoRoute(
                    path: 'add-expense',
                    name: 'group-add-expense',
                    builder: (context, state) {
                      final groupId = state.pathParameters['groupId']!;
                      return AddExpenseScreen(groupId: groupId);
                    },
                  ),
                  GoRoute(
                    path: 'settle',
                    name: 'group-settle',
                    builder: (context, state) {
                      final groupId = state.pathParameters['groupId']!;
                      return SettleUpScreen(groupId: groupId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Friends Tab
          GoRoute(
            path: '/friends',
            name: 'friends',
            builder: (context, state) => const FriendsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-friend',
                builder: (context, state) => const AddFriendScreen(),
              ),
              GoRoute(
                path: ':friendId',
                name: 'friend-detail',
                builder: (context, state) {
                  final friendId = state.pathParameters['friendId']!;
                  return FriendDetailScreen(friendId: friendId);
                },
              ),
            ],
          ),

          // Activity Tab
          GoRoute(
            path: '/activity',
            name: 'activity',
            builder: (context, state) => const ActivityScreen(),
          ),

          // Account Tab
          GoRoute(
            path: '/account',
            name: 'account',
            builder: (context, state) => const AccountScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Expense Routes (can be accessed from multiple places)
      GoRoute(
        path: '/expense/:expenseId',
        name: 'expense-detail',
        builder: (context, state) {
          final expenseId = state.pathParameters['expenseId']!;
          return ExpenseDetailScreen(expenseId: expenseId);
        },
      ),
      GoRoute(
        path: '/scan-receipt',
        name: 'scan-receipt',
        builder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'];
          return ScanReceiptScreen(groupId: groupId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
