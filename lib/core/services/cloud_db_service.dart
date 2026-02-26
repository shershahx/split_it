// lib/core/services/cloud_db_service.dart
// Development stub - Production will use HMS Cloud DB for AppGallery
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cloudDbServiceProvider = Provider<CloudDbService>((ref) {
  return CloudDbService();
});

/// Stub query class matching AGConnectCloudDBQuery interface
class CloudDBQuery {
  final String objectTypeName;
  CloudDBQuery(this.objectTypeName);
  void equalTo(String field, dynamic value) {}
  void orderBy(String field, {bool ascending = true}) {}
}

class CloudDbService {
  Future<void> init() async {
    // Stub: production will initialize HMS Cloud DB zone
    print('CloudDbService: Development stub - ready for HMS integration');
  }

  Future<List<Map<String, dynamic>>> executeQuery(CloudDBQuery query) async {
    // Stub: production will query HMS Cloud DB
    return [];
  }

  Future<void> upsertObject(String objectTypeName, List<Map<String, dynamic>> objects) async {
    // Stub: production will upsert into HMS Cloud DB
  }

  Future<void> deleteObject(String objectTypeName, List<Map<String, dynamic>> objects) async {
    // Stub: production will delete from HMS Cloud DB
  }
}