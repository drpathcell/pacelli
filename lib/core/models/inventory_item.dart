import 'package:equatable/equatable.dart';

import 'task.dart';

/// An item in the household inventory.
class InventoryItem extends Equatable {
  final String id;
  final String householdId;
  final String name;
  final String? description;
  final String? categoryId;
  final String? locationId;
  final int quantity;
  final String unit;
  final int? lowStockThreshold;
  final String? barcode;
  final String barcodeType; // 'real', 'virtual', 'none'
  final DateTime? expiryDate;
  final DateTime? purchaseDate;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined / denormalized fields
  final InventoryCategory? category;
  final InventoryLocation? location;
  final ProfileRef? creatorProfile;
  final List<InventoryAttachment> attachments;

  const InventoryItem({
    required this.id,
    required this.householdId,
    required this.name,
    this.description,
    this.categoryId,
    this.locationId,
    this.quantity = 0,
    this.unit = 'pieces',
    this.lowStockThreshold,
    this.barcode,
    this.barcodeType = 'none',
    this.expiryDate,
    this.purchaseDate,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.location,
    this.creatorProfile,
    this.attachments = const [],
  });

  bool get isLowStock =>
      lowStockThreshold != null && quantity <= lowStockThreshold!;

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final diff = expiryDate!.difference(now).inDays;
    return diff >= 0 && diff <= 7;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    final categoryMap =
        map['inventory_categories'] as Map<String, dynamic>?;
    final locationMap =
        map['inventory_locations'] as Map<String, dynamic>?;
    final creatorMap = map['creator'] as Map<String, dynamic>?;
    final attachmentList = map['attachments'] as List<dynamic>? ?? [];

    return InventoryItem(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as String?,
      locationId: map['location_id'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? 'pieces',
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt(),
      barcode: map['barcode'] as String?,
      barcodeType: map['barcode_type'] as String? ?? 'none',
      expiryDate: _parseDate(map['expiry_date']),
      purchaseDate: _parseDate(map['purchase_date']),
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String? ?? '',
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updated_at']) ?? DateTime.now(),
      category: categoryMap != null
          ? InventoryCategory.fromMap(categoryMap)
          : null,
      location: locationMap != null
          ? InventoryLocation.fromMap(locationMap)
          : null,
      creatorProfile:
          creatorMap != null ? ProfileRef.fromMap(creatorMap) : null,
      attachments: attachmentList
          .map((a) =>
              InventoryAttachment.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'name': name,
        'description': description,
        'category_id': categoryId,
        'location_id': locationId,
        'quantity': quantity,
        'unit': unit,
        'low_stock_threshold': lowStockThreshold,
        'barcode': barcode,
        'barcode_type': barcodeType,
        'expiry_date': expiryDate?.toIso8601String(),
        'purchase_date': purchaseDate?.toIso8601String(),
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toDisplayMap() => {
        ...toMap(),
        'inventory_categories': category?.toMap(),
        'inventory_locations': location?.toMap(),
        'creator': creatorProfile?.toMap(),
        'attachments': attachments.map((a) => a.toMap()).toList(),
      };

  InventoryItem copyWith({
    String? name,
    String? description,
    String? categoryId,
    String? locationId,
    int? quantity,
    String? unit,
    int? lowStockThreshold,
    String? barcode,
    String? barcodeType,
    DateTime? expiryDate,
    DateTime? purchaseDate,
    String? notes,
    DateTime? updatedAt,
    InventoryCategory? category,
    InventoryLocation? location,
    ProfileRef? creatorProfile,
    List<InventoryAttachment>? attachments,
  }) {
    return InventoryItem(
      id: id,
      householdId: householdId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      barcode: barcode ?? this.barcode,
      barcodeType: barcodeType ?? this.barcodeType,
      expiryDate: expiryDate ?? this.expiryDate,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      location: location ?? this.location,
      creatorProfile: creatorProfile ?? this.creatorProfile,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  List<Object?> get props => [id, quantity, updatedAt];

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value as String);
  }
}

/// A category for grouping inventory items.
class InventoryCategory extends Equatable {
  final String id;
  final String householdId;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;
  final int sortOrder;
  final DateTime createdAt;

  const InventoryCategory({
    required this.id,
    required this.householdId,
    required this.name,
    this.icon = 'inventory_2',
    this.color = '#A5B4A5',
    this.isDefault = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory InventoryCategory.fromMap(Map<String, dynamic> map) =>
      InventoryCategory(
        id: map['id'] as String,
        householdId: map['household_id'] as String? ?? '',
        name: map['name'] as String,
        icon: map['icon'] as String? ?? 'inventory_2',
        color: map['color'] as String? ?? '#A5B4A5',
        isDefault: map['is_default'] as bool? ?? false,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'name': name,
        'icon': icon,
        'color': color,
        'is_default': isDefault,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id];

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value as String);
  }
}

/// A physical location where inventory items are stored.
class InventoryLocation extends Equatable {
  final String id;
  final String householdId;
  final String name;
  final String icon;
  final bool isDefault;
  final int sortOrder;
  final DateTime createdAt;

  const InventoryLocation({
    required this.id,
    required this.householdId,
    required this.name,
    this.icon = 'place',
    this.isDefault = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory InventoryLocation.fromMap(Map<String, dynamic> map) =>
      InventoryLocation(
        id: map['id'] as String,
        householdId: map['household_id'] as String? ?? '',
        name: map['name'] as String,
        icon: map['icon'] as String? ?? 'place',
        isDefault: map['is_default'] as bool? ?? false,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'name': name,
        'icon': icon,
        'is_default': isDefault,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id];

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value as String);
  }
}

/// A log entry recording a quantity change for an inventory item.
class InventoryLog extends Equatable {
  final String id;
  final String itemId;
  final String householdId;
  final String action; // 'added', 'removed', 'adjusted', 'expired'
  final int quantityChange;
  final int quantityAfter;
  final String? note;
  final String performedBy;
  final DateTime performedAt;

  // Joined
  final ProfileRef? performerProfile;

  const InventoryLog({
    required this.id,
    required this.itemId,
    required this.householdId,
    required this.action,
    required this.quantityChange,
    required this.quantityAfter,
    this.note,
    required this.performedBy,
    required this.performedAt,
    this.performerProfile,
  });

  factory InventoryLog.fromMap(Map<String, dynamic> map) {
    final performerMap = map['performer'] as Map<String, dynamic>?;

    return InventoryLog(
      id: map['id'] as String,
      itemId: map['item_id'] as String,
      householdId: map['household_id'] as String? ?? '',
      action: map['action'] as String,
      quantityChange: (map['quantity_change'] as num?)?.toInt() ?? 0,
      quantityAfter: (map['quantity_after'] as num?)?.toInt() ?? 0,
      note: map['note'] as String?,
      performedBy: map['performed_by'] as String? ?? '',
      performedAt: _parseDate(map['performed_at']) ?? DateTime.now(),
      performerProfile:
          performerMap != null ? ProfileRef.fromMap(performerMap) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'household_id': householdId,
        'action': action,
        'quantity_change': quantityChange,
        'quantity_after': quantityAfter,
        'note': note,
        'performed_by': performedBy,
        'performed_at': performedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id];

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value as String);
  }
}

/// A file attachment associated with an inventory item.
class InventoryAttachment extends Equatable {
  final String id;
  final String itemId;
  final String householdId;
  final String driveFileId;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String? thumbnailUrl;
  final String webViewLink;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String? description;

  const InventoryAttachment({
    required this.id,
    required this.itemId,
    required this.householdId,
    required this.driveFileId,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    this.thumbnailUrl,
    required this.webViewLink,
    required this.uploadedBy,
    required this.uploadedAt,
    this.description,
  });

  factory InventoryAttachment.fromMap(Map<String, dynamic> map) {
    return InventoryAttachment(
      id: map['id'] as String,
      itemId: map['item_id'] as String,
      householdId: map['household_id'] as String,
      driveFileId: map['drive_file_id'] as String,
      fileName: map['file_name'] as String,
      mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnail_url'] as String?,
      webViewLink: map['web_view_link'] as String,
      uploadedBy: map['uploaded_by'] as String,
      uploadedAt: map['uploaded_at'] is DateTime
          ? map['uploaded_at'] as DateTime
          : DateTime.parse(map['uploaded_at'] as String),
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'household_id': householdId,
        'drive_file_id': driveFileId,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size_bytes': fileSizeBytes,
        'thumbnail_url': thumbnailUrl,
        'web_view_link': webViewLink,
        'uploaded_by': uploadedBy,
        'uploaded_at': uploadedAt.toIso8601String(),
        'description': description,
      };

  InventoryAttachment copyWith({
    String? id,
    String? itemId,
    String? householdId,
    String? driveFileId,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? thumbnailUrl,
    String? webViewLink,
    String? uploadedBy,
    DateTime? uploadedAt,
    String? description,
  }) {
    return InventoryAttachment(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      householdId: householdId ?? this.householdId,
      driveFileId: driveFileId ?? this.driveFileId,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      webViewLink: webViewLink ?? this.webViewLink,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [id];
}
