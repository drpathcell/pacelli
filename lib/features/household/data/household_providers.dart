import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'household_service.dart';

/// Provider that fetches the current user's household.
///
/// Returns null if the user hasn't joined a household yet.
/// Call ref.invalidate(currentHouseholdProvider) to refresh.
final currentHouseholdProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  return HouseholdService.getCurrentHousehold();
});

/// Provider that fetches household members.
///
/// Requires a household ID. Returns an empty list if no ID is given.
final householdMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, householdId) async {
  return HouseholdService.getHouseholdMembers(householdId);
});
