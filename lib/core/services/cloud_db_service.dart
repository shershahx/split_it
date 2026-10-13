import 'package:flutter_riverpod/flutter_riverpod.dart';

final cloudDbServiceProvider = Provider<CloudDbService>((ref) {
  return CloudDbService();
});

/// Temporary query abstraction retained until repositories move to Supabase.
class CloudDBQuery {
  final String objectTypeName;
  CloudDBQuery(this.objectTypeName);
  void equalTo(String field, dynamic value) {}
  void orderBy(String field, {bool ascending = true}) {}
}

class CloudDbService {
  Future<void> init() async {
    // Data integration is intentionally deferred.
  }

  Future<List<Map<String, dynamic>>> executeQuery(CloudDBQuery query) async {
    return [];
  }

  Future<void> upsertObject(
    String objectTypeName,
    List<Map<String, dynamic>> objects,
  ) async {
    // Data integration is intentionally deferred.
  }

  Future<void> deleteObject(
    String objectTypeName,
    List<Map<String, dynamic>> objects,
  ) async {
    // Data integration is intentionally deferred.
  }
}
