import 'package:supabase_flutter/supabase_flutter.dart';

class FinancialFailure implements Exception {
  final String message;
  const FinancialFailure(this.message);

  @override
  String toString() => message;
}

/// Raw transport errors/SQL details must never be displayed to users.
String financialErrorMessage(Object error) {
  if (error is FinancialFailure) return error.message;
  if (error is ArgumentError) {
    return 'Check the amount and participants. Use at most two decimal places.';
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case '42501':
        return 'You do not have permission for this action. Refresh and try again.';
      case '23505':
        return 'This request already exists. Refresh before trying again.';
      case 'PGRST202':
        return 'The financial database update is required. Run migration 002.';
      case 'P0001':
      case '23514':
      case '22023':
        return 'The record could not be saved. Refresh the group and check the amount and participants.';
    }
  }
  return 'Could not complete the request. Check your connection and try again. '
      'Retry the unchanged form to safely confirm the same request.';
}
