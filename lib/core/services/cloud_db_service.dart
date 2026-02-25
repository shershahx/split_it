// lib/core/services/cloud_db_service.dart
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for the database service
final cloudDbServiceProvider = Provider<CloudDbService>((ref) {
  return CloudDbService();
});

class CloudDbService {
  AGConnectCloudDB? _cloudDB;
  AGConnectCloudDBZone? _cloudDBZone;
  final String _zoneName = "SplitItZone";
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Get the Cloud DB instance
      _cloudDB = AGConnectCloudDB.getInstance();
      await _cloudDB!.initialize();
      
      // Initialize the zone
      await _openZone();
      
      _isInitialized = true;
      debugPrint("Cloud DB Initialized successfully");
    } catch (e) {
      debugPrint("Error initializing Cloud DB: $e");
      // Don't rethrow here to allow app to function in offline/error state if possible,
      // or handle closer to UI. For now, we log.
    }
  }

  Future<void> _openZone() async {
    if (_cloudDB == null) return;

    try {
      AGConnectCloudDBZoneConfig mConfig = AGConnectCloudDBZoneConfig(
        zoneName: _zoneName,
        syncProperty: AGConnectCloudDBZoneSyncProperty.CLOUDDBZONE_CLOUD_CACHE,
        accessProperty: AGConnectCloudDBZoneAccessProperty.CLOUDDBZONE_PUBLIC,
        isPersistenceEnabled: true,
      );

      _cloudDBZone = await _cloudDB!.openCloudDBZone(
          zoneConfig: mConfig, isAllowToCreate: true);
      debugPrint("Cloud DB Zone opened: $_zoneName");
    } catch (e) {
      debugPrint("Error opening Cloud DB Zone: $e");
      rethrow;
    }
  }

  // Helper method to execute queries
  Future<List<Map<String, dynamic>>> executeQuery(
    AGConnectCloudDBQuery query, {
    AGConnectCloudDBZoneQueryPolicy policy =
        AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
  }) async {
    if (_cloudDBZone == null) {
      await _openZone();
    }

    try {
      AGConnectCloudDBZoneSnapshot snapshot =
          await _cloudDBZone!.executeQuery(query: query, policy: policy);
      return snapshot.snapshotObjects;
    } catch (e) {
      debugPrint("Error executing query: $e");
      rethrow;
    }
  }

  // Helper method to upsert objects (insert or update)
  Future<int> upsertObject(
      String objectTypeName, List<Map<String, dynamic>> entries) async {
    if (_cloudDBZone == null) {
      await _openZone();
    }

    try {
      return await _cloudDBZone!.executeUpsert(
        objectTypeName: objectTypeName,
        entries: entries,
      );
    } catch (e) {
      debugPrint("Error upserting objects: $e");
      rethrow;
    }
  }

  // Helper method to delete objects
  Future<int> deleteObject(
      String objectTypeName, List<Map<String, dynamic>> entries) async {
    if (_cloudDBZone == null) {
      await _openZone();
    }

    try {
      return await _cloudDBZone!.executeDelete(
        objectTypeName: objectTypeName,
        entries: entries,
      );
    } catch (e) {
      debugPrint("Error deleting objects: $e");
      rethrow;
    }
  }
}
