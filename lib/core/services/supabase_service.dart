import 'package:supabase_flutter/supabase_flutter.dart';

/// Convenience accessors for the Supabase client.
///
/// Instead of importing and calling [Supabase.instance.client] everywhere,
/// use these getters for cleaner, more readable code.
///
/// Usage:
///   final user = supabase.auth.currentUser;
///   final data = await supabase.from('tasks').select();
///

/// The main Supabase client — use this for database queries, auth, etc.
final supabase = Supabase.instance.client;

/// Shortcut to the current authenticated user (or null if not logged in).
User? get currentUser => supabase.auth.currentUser;

/// Shortcut to the current user's ID (or null).
String? get currentUserId => supabase.auth.currentUser?.id;
