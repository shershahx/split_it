// lib/features/settle/data/settlements_repository.dart
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cloud_db_service.dart';
import '../../../shared/models/settlement.dart';

final settlementsRepositoryProvider = Provider<SettlementsRepository>((ref) {
  return SettlementsRepository(ref.read(cloudDbServiceProvider));
});

class SettlementsRepository {
  final CloudDbService _cloudDbService;
  final String _objectTypeName = 'Settlement';

  SettlementsRepository(this._cloudDbService);

  /// Fetch all settlements for a group
  Future<List<Settlement>> getSettlements(String groupId) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName);
      query.equalTo('groupId', groupId);

      final result = await _cloudDbService.executeQuery(query);
      return result.map((map) => Settlement.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch settlements: $e');
    }
  }

  /// Save (upsert) a settlement
  Future<void> saveSettlement(Settlement settlement) async {
    try {
      await _cloudDbService.upsertObject(
        _objectTypeName,
        [settlement.toMap()],
      );
    } catch (e) {
      throw Exception('Failed to save settlement: $e');
    }
  }

  /// Delete a settlement
  Future<void> deleteSettlement(Settlement settlement) async {
    try {
      await _cloudDbService.deleteObject(
        _objectTypeName,
        [settlement.toMap()],
      );
    } catch (e) {
      throw Exception('Failed to delete settlement: $e');
    }
  }

  /// Get settlement by ID
  Future<Settlement?> getSettlementById(String settlementId) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName);
      query.equalTo('id', settlementId);

      final result = await _cloudDbService.executeQuery(query);
      if (result.isNotEmpty) {
        return Settlement.fromMap(result.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch settlement: $e');
    }
  }
}
