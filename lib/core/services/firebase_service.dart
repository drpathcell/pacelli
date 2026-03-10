import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Convenience accessors for Firebase services.
///
/// Instead of importing and calling [FirebaseAuth.instance] and
/// [FirebaseFirestore.instance] everywhere, use these getters for
/// cleaner, more readable code.
///
/// Usage:
///   final user = firebaseAuth.currentUser;
///   final data = await db.collection('tasks').get();

/// The Firebase Auth instance — use for sign-in, sign-up, sign-out, etc.
final firebaseAuth = FirebaseAuth.instance;

/// The Firestore database instance — use for all CRUD operations.
final db = FirebaseFirestore.instance;

/// Shortcut to the current authenticated user (or null if not logged in).
User? get currentUser => firebaseAuth.currentUser;

/// Shortcut to the current user's UID (or null).
String? get currentUserId => firebaseAuth.currentUser?.uid;
