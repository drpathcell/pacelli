import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../../config/constants/app_constants.dart';

/// Result returned after uploading a file to Google Drive.
class DriveFileResult {
  final String fileId;
  final String webViewLink;
  final String? thumbnailLink;
  final int fileSizeBytes;
  final String mimeType;

  const DriveFileResult({
    required this.fileId,
    required this.webViewLink,
    this.thumbnailLink,
    required this.fileSizeBytes,
    required this.mimeType,
  });
}

/// Authenticated HTTP client that injects Google Sign-In auth headers.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Service for interacting with Google Drive API.
///
/// Uses the household owner's Google account to store files in a
/// dedicated "Pacelli" folder. Only accesses files created by the app
/// (drive.file scope).
class GoogleDriveService {
  /// The Drive API scope — only access files created by this app.
  static const String _driveFileScope =
      'https://www.googleapis.com/auth/drive.file';

  /// Root folder name in the owner's Google Drive.
  static const String _rootFolderName = 'Pacelli';

  // ── Authentication ────────────────────────────────────────────

  /// Returns a GoogleSignIn instance configured with Drive scope.
  GoogleSignIn _getGoogleSignIn() {
    return GoogleSignIn(
      clientId: AppConstants.googleiOSClientId,
      serverClientId: AppConstants.googleWebClientId,
      scopes: [_driveFileScope],
    );
  }

  /// Requests Drive file scope from the currently signed-in user.
  ///
  /// Returns `true` if the scope was granted, `false` if denied.
  Future<bool> requestDriveScope() async {
    final googleSignIn = _getGoogleSignIn();

    // Check if already signed in
    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();

    if (account == null) {
      // Not signed in at all — need full sign-in
      account = await googleSignIn.signIn();
      if (account == null) return false;
    }

    // Request the Drive scope
    final granted = await googleSignIn.requestScopes([_driveFileScope]);
    return granted;
  }

  /// Returns an authenticated [drive.DriveApi] instance.
  ///
  /// Throws if the user is not signed in or hasn't granted Drive scope.
  Future<drive.DriveApi> _getDriveApi() async {
    final googleSignIn = _getGoogleSignIn();

    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();

    if (account == null) {
      throw Exception(
        'Google Sign-In required. Please sign in to access Google Drive.',
      );
    }

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  /// Whether the current user has granted Drive file scope.
  Future<bool> hasDriveScope() async {
    final googleSignIn = _getGoogleSignIn();
    final account = googleSignIn.currentUser ??
        await googleSignIn.signInSilently();
    if (account == null) return false;

    // Check if the scope is already granted by trying to get auth headers
    try {
      await account.authHeaders;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Folder Management ─────────────────────────────────────────

  /// Ensures the "Pacelli/{householdName}" folder exists in the owner's Drive.
  ///
  /// Creates the folder hierarchy if it doesn't exist. Returns the
  /// household folder's Drive ID.
  Future<String> ensurePacelliFolder(String householdName) async {
    final driveApi = await _getDriveApi();

    // Find or create root "Pacelli" folder
    final rootFolderId = await _findOrCreateFolder(
      driveApi,
      _rootFolderName,
      parentId: 'root',
    );

    // Find or create household subfolder
    final sanitisedName = _sanitiseFolderName(householdName);
    final householdFolderId = await _findOrCreateFolder(
      driveApi,
      sanitisedName,
      parentId: rootFolderId,
    );

    return householdFolderId;
  }

  /// Finds a folder by name under a parent, or creates it.
  Future<String> _findOrCreateFolder(
    drive.DriveApi driveApi,
    String name, {
    required String parentId,
  }) async {
    // Search for existing folder
    final query = "name = '$name' "
        "and mimeType = 'application/vnd.google-apps.folder' "
        "and '$parentId' in parents "
        "and trashed = false";

    final result = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }

    // Create new folder
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [parentId];

    final created = await driveApi.files.create(
      folder,
      $fields: 'id',
    );

    return created.id!;
  }

  // ── File Operations ───────────────────────────────────────────

  /// Uploads a file to the household's Drive folder.
  ///
  /// Files are only accessible to the Google account that owns the Drive.
  /// We do NOT create public "anyone with link" permissions — instead,
  /// household members open files via the Drive API using the owner's
  /// auth headers.
  ///
  /// Returns metadata about the uploaded file.
  Future<DriveFileResult> uploadFile({
    required String folderId,
    required File file,
    required String fileName,
    required String mimeType,
  }) async {
    final driveApi = await _getDriveApi();

    // Create the file metadata
    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId];

    // Upload with media
    final fileLength = await file.length();
    final media = drive.Media(
      file.openRead(),
      fileLength,
      contentType: mimeType,
    );

    final created = await driveApi.files.create(
      driveFile,
      uploadMedia: media,
      $fields: 'id, webViewLink, thumbnailLink, size, mimeType',
    );

    // No public sharing permission created — files stay private to the
    // Drive owner's account. Access is through the app's Drive API auth.

    return DriveFileResult(
      fileId: created.id!,
      webViewLink: created.webViewLink ?? 'https://drive.google.com/file/d/${created.id}/view',
      thumbnailLink: created.thumbnailLink,
      fileSizeBytes: int.tryParse(created.size ?? '0') ?? fileLength,
      mimeType: created.mimeType ?? mimeType,
    );
  }

  /// Deletes a file from Google Drive.
  Future<void> deleteFile(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      await driveApi.files.delete(fileId);
    } catch (e) {
      debugPrint('GoogleDriveService: Failed to delete file $fileId: $e');
      // Don't throw — file might already be deleted from Drive directly
    }
  }

  /// Fetches metadata for a file.
  Future<drive.File?> getFileMetadata(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      return await driveApi.files.get(
        fileId,
        $fields: 'id, name, mimeType, size, thumbnailLink, webViewLink, createdTime',
      ) as drive.File;
    } catch (e) {
      debugPrint('GoogleDriveService: Failed to get metadata for $fileId: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  /// Sanitises a string for use as a Google Drive folder name.
  String _sanitiseFolderName(String name) {
    // Remove characters that are problematic in Drive folder names
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }
}
