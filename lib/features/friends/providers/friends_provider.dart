import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/balance_calculator.dart';

import '../../../shared/models/expense.dart';
import '../../../shared/models/friend.dart';
import '../../../shared/models/group.dart';
import '../../../shared/models/settlement.dart';
import '../../auth/providers/auth_provider.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../settle/providers/settlements_provider.dart';
import '../data/friends_repository.dart';

final friendsProvider = FutureProvider<List<Friend>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(friendsRepositoryProvider).getFriends(user.uid);
});

final friendRequestsProvider = FutureProvider<List<FriendRequest>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final requests =
      await ref.watch(friendsRepositoryProvider).getFriendRequests();
  return requests.where((request) => request.addresseeId == user.uid).toList();
});

final singleFriendProvider =
    FutureProvider.family<Friend?, String>((ref, id) async {
  if (ref.watch(currentUserProvider) == null) return null;
  final friends = await ref.watch(friendsProvider.future);
  for (final friend in friends) {
    if (friend.id == id) return friend;
  }
  return null;
});

class FriendsNotifier extends StateNotifier<AsyncValue<void>> {
  FriendsNotifier(this._repository, {this.userId, void Function()? onChanged})
      : _onChanged = onChanged,
        super(const AsyncValue.data(null));

  final FriendsRepository _repository;
  final String? userId;
  final void Function()? _onChanged;

  Future<void> _mutate(Future<void> Function() action) async {
    if (userId == null) throw StateError('Sign in to manage friends');
    if (state.isLoading) {
      throw StateError('A friend request is already in progress');
    }
    state = const AsyncValue.loading();
    try {
      await action();
      // An auth change disposes this notifier; do not publish into the new session.
      if (!mounted) return;
      _onChanged?.call();
      state = const AsyncValue.data(null);
    } catch (error, stack) {
      if (mounted) state = AsyncValue.error(error, stack);
      rethrow;
    }
  }

  Future<void> addFriend(Friend friend) => _mutate(() {
        if (friend.userId1 != userId) throw StateError('Account changed');
        return _repository.addFriend(friend);
      });

  Future<void> respondToFriendRequest(String requesterId,
          {required bool accept}) =>
      _mutate(() =>
          _repository.respondToFriendRequest(requesterId, accept: accept));

  Future<void> removeFriend(String friendId) =>
      _mutate(() => _repository.removeFriend(friendId));

  Future<void> deleteFriend(Friend friend) => removeFriend(friend.id);
}

final friendsNotifierProvider =
    StateNotifierProvider<FriendsNotifier, AsyncValue<void>>((ref) {
  final user = ref.watch(currentUserProvider);
  return FriendsNotifier(
    ref.watch(friendsRepositoryProvider),
    userId: user?.uid,
    onChanged: () {
      ref.invalidate(friendsProvider);
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(singleFriendProvider);
      ref.invalidate(friendFinancialsProvider);
    },
  );
});

class _GroupLedger {
  const _GroupLedger(this.group, this.expenses, this.settlements);
  final Group group;
  final List<Expense> expenses;
  final List<Settlement> settlements;
}

final _friendsLedgerProvider = FutureProvider<List<_GroupLedger>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  var active = true;
  ref.onDispose(() => active = false);
  final groups = await ref.watch(groupsProvider.future);
  // An obsolete async build must not register dependencies in the new session.
  if (!active || ref.read(currentUserProvider)?.uid != user.uid) return [];
  return Future.wait(
      groups.groups.where((g) => g.memberIds.contains(user.uid)).map((group) {
    final expenses = ref.watch(expensesProvider(group.id).future);
    final settlements = ref.watch(settlementsProvider(group.id).future);
    return Future.wait<Object>([expenses, settlements]).then((values) =>
        _GroupLedger(
            group, values[0] as List<Expense>, values[1] as List<Settlement>));
  }));
});

class SharedFriendExpense {
  const SharedFriendExpense(
      {required this.expense, required this.groupName, required this.currency});
  final Expense expense;
  final String groupName;
  final String currency;
}

class FriendFinancials {
  const FriendFinancials({required this.balances, required this.expenses});

  /// Positive = friend owes you. Currency codes are never converted or combined.
  final Map<String, double> balances;
  final List<SharedFriendExpense> expenses;
}

final friendFinancialsProvider =
    FutureProvider.family<FriendFinancials, String>((ref, friendId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const FriendFinancials(balances: {}, expenses: []);
  final ledgers = await ref.watch(_friendsLedgerProvider.future);
  final expensesByCurrency = <String, List<Expense>>{};
  final settlementsByCurrency = <String, List<Settlement>>{};
  final shared = <SharedFriendExpense>[];
  for (final ledger in ledgers) {
    // Include historical records even when the friend has since left the group.
    final currency = ledger.group.currency.trim().toUpperCase();
    if (currency.isEmpty) throw StateError('Group currency is missing');
    expensesByCurrency.putIfAbsent(currency, () => []).addAll(ledger.expenses);
    settlementsByCurrency
        .putIfAbsent(currency, () => [])
        .addAll(ledger.settlements);
    for (final expense in ledger.expenses) {
      bool involves(String id) =>
          expense.paidBy == id || expense.split.containsKey(id);
      if (involves(user.uid) && involves(friendId)) {
        shared.add(SharedFriendExpense(
          expense: expense,
          groupName: ledger.group.name,
          currency: currency,
        ));
      }
    }
  }
  final balances = <String, double>{};
  for (final currency in expensesByCurrency.keys) {
    final balance = BalanceCalculator.calculateNetBalances(
          currentUserId: user.uid,
          expenses: expensesByCurrency[currency]!,
          settlements: settlementsByCurrency[currency]!,
        )[friendId] ??
        0;
    if (balance != 0) balances[currency] = balance;
  }
  shared.sort((a, b) => b.expense.date.compareTo(a.expense.date));
  return FriendFinancials(balances: balances, expenses: shared);
});

/// Explicit refresh/retry only; expense mutations are refreshed by the parent.
void refreshFriendFinancials(WidgetRef ref) {
  ref.invalidate(groupsProvider);
  ref.invalidate(expensesProvider);
  ref.invalidate(settlementsProvider);
  ref.invalidate(_friendsLedgerProvider);
  ref.invalidate(friendFinancialsProvider);
}
