import 'package:flutter/material.dart';

/// Helper utilities for file attachments — icons, formatting, type detection.
class AttachmentHelpers {
  AttachmentHelpers._();

  /// Returns a descriptive file type label from a MIME type.
  static String fileTypeLabel(String mimeType) {
    if (mimeType.startsWith('image/')) return 'Image';
    if (mimeType == 'application/pdf') return 'PDF';
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
      return 'Spreadsheet';
    }
    if (mimeType.contains('document') || mimeType.contains('word')) {
      return 'Document';
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return 'Presentation';
    }
    if (mimeType.startsWith('video/')) return 'Video';
    if (mimeType.startsWith('audio/')) return 'Audio';
    if (mimeType.startsWith('text/')) return 'Text';
    return 'File';
  }

  /// Returns an appropriate icon for a MIME type.
  static IconData iconForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_rounded;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    if (mimeType.contains('document') || mimeType.contains('word')) {
      return Icons.description_rounded;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow_rounded;
    }
    if (mimeType.startsWith('video/')) return Icons.videocam_rounded;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack_rounded;
    if (mimeType.startsWith('text/')) return Icons.article_rounded;
    return Icons.attach_file_rounded;
  }

  /// Returns a colour for a MIME type (for icon tinting).
  static Color colorForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return const Color(0xFF6BAF6B);
    if (mimeType == 'application/pdf') return const Color(0xFFCF6B6B);
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
      return const Color(0xFF4CAF50);
    }
    if (mimeType.contains('document') || mimeType.contains('word')) {
      return const Color(0xFF2196F3);
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return const Color(0xFFFF9800);
    }
    if (mimeType.startsWith('video/')) return const Color(0xFF9C27B0);
    if (mimeType.startsWith('audio/')) return const Color(0xFFE91E63);
    return const Color(0xFF6B9ECF);
  }

  /// Formats a file size in bytes into a human-readable string.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Returns the file extension from a filename.
  static String fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toUpperCase();
  }
}
