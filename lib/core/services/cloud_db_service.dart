import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../utils/money.dart';

final cloudDbServiceProvider = Provider<CloudDbService>((ref) {
  return CloudDbService(ref.watch(supabaseClientProvider));
});

/// Shared database boundary; repositories use the injected Supabase client.
class CloudDbService {
  CloudDbService([this.client]);

  final SupabaseClient? client;

  /// Per-record boundary shared with the form/model money utility.
  static const maxMinorUnits = Money.maxMinorUnits;

  /// Read every row using an immutable, unique UUID key. A short page is NOT an
  /// end marker: PostgREST may enforce a smaller cap than our requested limit.
  /// Each callback must construct a fresh query without order/limit/offset.
  static Future<PostgrestList> readAll(
    PostgrestFilterBuilder<PostgrestList> Function() query, {
    String keyColumn = 'id',
  }) async {
    final rows = <Map<String, dynamic>>[];
    String? cursor;
    while (true) {
      var pageQuery = query();
      if (cursor != null) pageQuery = pageQuery.gt(keyColumn, cursor);
      final page = await pageQuery.order(keyColumn, ascending: true).limit(200);
      if (page.isEmpty) return rows;
      for (final row in page) {
        final key = row[keyColumn] as String;
        if (cursor != null && key.compareTo(cursor) <= 0) {
          throw const FormatException('Database pagination did not advance');
        }
        cursor = key;
        rows.add(row);
      }
    }
  }

  /// The existing models express money in major units with two decimal places.
  /// Reject sub-minor-unit amounts instead of silently changing split totals.
  static int toMinorUnits(double amount) {
    if (!amount.isFinite || amount.abs() > maxMinorUnits / 100) {
      throw ArgumentError.value(
          amount, 'amount', 'Outside the safe money range');
    }
    final scaled = amount * 100;
    final rounded = scaled.round();
    if (amount != rounded / 100 && (scaled - rounded).abs() > 0.000001) {
      throw ArgumentError.value(amount, 'amount', 'Use at most two decimals');
    }
    return rounded;
  }

  static double fromMinorUnits(num amount) {
    if (!amount.isFinite ||
        amount.abs() > maxMinorUnits ||
        amount != amount.round()) {
      throw FormatException('Invalid or unsafe minor-unit amount: $amount');
    }
    return amount.toDouble() / 100;
  }

  Future<void> upsertObject(String table, List<Map<String, dynamic>> objects) async {
    throw UnsupportedError('Direct table writes are no longer supported.');
  }

  Future<void> deleteObject(String table, List<String> ids) async {
    throw UnsupportedError('Direct table deletes are no longer supported.');
  }
}
