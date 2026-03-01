import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

/// Service for household CRUD operations via Supabase.
class HouseholdService {
  /// Creates a new household and adds the current user as admin.
  ///
  /// Returns the created household data.
  static Future<Map<String, dynamic>> createHousehold(String name) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // Call the SECURITY DEFINER function that handles both inserts atomically
    final response = await supabase.rpc('create_household', params: {
      'household_name': name,
    });

    // The function returns a JSON object with the household data
    return Map<String, dynamic>.from(response as Map);
  }

  /// Fetches the current user's household (if any).
  ///
  /// Returns null if the user hasn't joined a household yet.
  static Future<Map<String, dynamic>?> getCurrentHousehold() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      // Find the user's household membership
      final membership = await supabase
          .from('household_members')
          .select('household_id, role, households(id, name, created_by, created_at)')
          .eq('user_id', userId)
          .maybeSingle();

      if (membership == null) return null;

      return {
        'membership': membership,
        'household': membership['households'],
        'role': membership['role'],
      };
    } catch (e) {
      // If query fails (e.g., RLS blocks or no membership), return null
      // so the home screen shows the "Create Household" prompt.
      return null;
    }
  }

  /// Fetches all members of a household.
  static Future<List<Map<String, dynamic>>> getHouseholdMembers(
      String householdId) async {
    final members = await supabase
        .from('household_members')
        .select('user_id, role, joined_at, profiles(id, full_name, avatar_url)')
        .eq('household_id', householdId);

    return List<Map<String, dynamic>>.from(members);
  }

  /// Invites a user to the household by email.
  ///
  /// Creates a pending membership entry. The invited user will see the
  /// household when they sign up / log in.
  static Future<void> inviteByEmail({
    required String householdId,
    required String email,
  }) async {
    // Check if a user with this email already exists
    // We'll use the Supabase edge function or just create a pending invite
    await supabase.from('household_invites').insert({
      'household_id': householdId,
      'invited_email': email,
      'invited_by': currentUserId,
      'status': 'pending',
    });
  }

  /// Checks if the current user has a pending invite and accepts it.
  static Future<Map<String, dynamic>?> checkAndAcceptInvite() async {
    final user = currentUser;
    if (user == null || user.email == null) return null;

    final invite = await supabase
        .from('household_invites')
        .select('id, household_id, households(id, name)')
        .eq('invited_email', user.email!)
        .eq('status', 'pending')
        .maybeSingle();

    if (invite == null) return null;

    // Accept the invite — add user as member
    await supabase.from('household_members').insert({
      'household_id': invite['household_id'],
      'user_id': user.id,
      'role': 'member',
    });

    // Mark invite as accepted
    await supabase
        .from('household_invites')
        .update({'status': 'accepted'})
        .eq('id', invite['id']);

    return invite['households'] as Map<String, dynamic>?;
  }

  /// Removes a member from the household.
  static Future<void> removeMember({
    required String householdId,
    required String userId,
  }) async {
    await supabase
        .from('household_members')
        .delete()
        .eq('household_id', householdId)
        .eq('user_id', userId);
  }

  /// Updates the household name.
  static Future<void> updateHouseholdName({
    required String householdId,
    required String name,
  }) async {
    await supabase
        .from('households')
        .update({'name': name})
        .eq('id', householdId);
  }
}
