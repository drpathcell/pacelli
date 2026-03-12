import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Manages the local SQLite database for the offline-first backend.
///
/// Schema mirrors the Firestore collections so that models can be
/// hydrated via the same `fromMap()` factories.
class LocalDatabase {
  static Database? _instance;

  /// Opens (or creates) the local database.
  static Future<Database> open() async {
    if (_instance != null) return _instance!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pacelli_local.db');

    _instance = await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _instance!;
  }

  /// Closes the database (useful for testing / switching backends).
  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  /// Permanently deletes the local database file from disk.
  static Future<void> deleteDatabase() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pacelli_local.db');
    await databaseFactory.deleteDatabase(path);
  }

  // ─── Schema creation ────────────────────────────────────────────

  static Future<void> _onCreate(Database db, int version) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    // ── Task Categories ──
    await db.execute('''
      CREATE TABLE task_categories (
        id           TEXT PRIMARY KEY,
        household_id TEXT NOT NULL,
        name         TEXT NOT NULL,
        icon         TEXT NOT NULL DEFAULT 'category',
        color        TEXT NOT NULL DEFAULT '#7EA87E',
        is_default   INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Tasks ──
    await db.execute('''
      CREATE TABLE tasks (
        id            TEXT PRIMARY KEY,
        household_id  TEXT NOT NULL,
        title         TEXT NOT NULL,
        description   TEXT,
        category_id   TEXT REFERENCES task_categories(id) ON DELETE SET NULL,
        priority      TEXT NOT NULL DEFAULT 'medium',
        status        TEXT NOT NULL DEFAULT 'pending',
        due_date      TEXT,
        start_date    TEXT,
        assigned_to   TEXT,
        is_shared     INTEGER NOT NULL DEFAULT 0,
        recurrence    TEXT NOT NULL DEFAULT 'none',
        created_by    TEXT,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        completed_at  TEXT,
        completed_by  TEXT
      )
    ''');

    // ── Subtasks ──
    await db.execute('''
      CREATE TABLE subtasks (
        id           TEXT PRIMARY KEY,
        task_id      TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        household_id TEXT NOT NULL DEFAULT '',
        title        TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        sort_order   INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Checklists ──
    await db.execute('''
      CREATE TABLE checklists (
        id           TEXT PRIMARY KEY,
        household_id TEXT NOT NULL,
        title        TEXT NOT NULL,
        created_by   TEXT,
        created_at   TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT
      )
    ''');

    // ── Checklist Items ──
    await db.execute('''
      CREATE TABLE checklist_items (
        id           TEXT PRIMARY KEY,
        checklist_id TEXT NOT NULL REFERENCES checklists(id) ON DELETE CASCADE,
        household_id TEXT NOT NULL DEFAULT '',
        title        TEXT NOT NULL,
        quantity     TEXT,
        is_checked   INTEGER NOT NULL DEFAULT 0,
        checked_at   TEXT,
        checked_by   TEXT,
        created_by   TEXT,
        created_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Scratch Plans ──
    await db.execute('''
      CREATE TABLE scratch_plans (
        id            TEXT PRIMARY KEY,
        household_id  TEXT NOT NULL,
        title         TEXT NOT NULL,
        type          TEXT NOT NULL DEFAULT 'weekly',
        status        TEXT NOT NULL DEFAULT 'draft',
        start_date    TEXT NOT NULL,
        end_date      TEXT NOT NULL,
        is_template   INTEGER NOT NULL DEFAULT 0,
        template_name TEXT,
        created_by    TEXT,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT
      )
    ''');

    // ── Plan Entries ──
    await db.execute('''
      CREATE TABLE plan_entries (
        id           TEXT PRIMARY KEY,
        plan_id      TEXT NOT NULL REFERENCES scratch_plans(id) ON DELETE CASCADE,
        household_id TEXT NOT NULL DEFAULT '',
        entry_date   TEXT NOT NULL,
        title       TEXT NOT NULL DEFAULT '',
        label       TEXT,
        description TEXT,
        sort_order  INTEGER NOT NULL DEFAULT 0,
        created_by  TEXT,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT
      )
    ''');

    // ── Plan Checklist Items ──
    await db.execute('''
      CREATE TABLE plan_checklist_items (
        id           TEXT PRIMARY KEY,
        plan_id      TEXT NOT NULL REFERENCES scratch_plans(id) ON DELETE CASCADE,
        household_id TEXT NOT NULL DEFAULT '',
        entry_id     TEXT REFERENCES plan_entries(id) ON DELETE SET NULL,
        title      TEXT NOT NULL,
        quantity   TEXT,
        is_checked INTEGER NOT NULL DEFAULT 0,
        checked_at TEXT,
        checked_by TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Task Attachments ──
    await db.execute('''
      CREATE TABLE task_attachments (
        id              TEXT PRIMARY KEY,
        task_id         TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        household_id    TEXT NOT NULL,
        drive_file_id   TEXT NOT NULL,
        file_name       TEXT NOT NULL,
        mime_type       TEXT NOT NULL DEFAULT 'application/octet-stream',
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        thumbnail_url   TEXT,
        web_view_link   TEXT NOT NULL,
        uploaded_by     TEXT NOT NULL,
        uploaded_at     TEXT NOT NULL DEFAULT (datetime('now')),
        description     TEXT
      )
    ''');

    // ── Profile Cache (Phase 5 placeholder) ──
    await db.execute('''
      CREATE TABLE profile_cache (
        id         TEXT PRIMARY KEY,
        full_name  TEXT,
        avatar_url TEXT,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Inventory Categories ──
    await db.execute('''
      CREATE TABLE inventory_categories (
        id           TEXT PRIMARY KEY,
        household_id TEXT NOT NULL,
        name         TEXT NOT NULL,
        icon         TEXT NOT NULL DEFAULT 'inventory_2',
        color        TEXT NOT NULL DEFAULT '#A5B4A5',
        is_default   INTEGER NOT NULL DEFAULT 0,
        sort_order   INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Inventory Locations ──
    await db.execute('''
      CREATE TABLE inventory_locations (
        id           TEXT PRIMARY KEY,
        household_id TEXT NOT NULL,
        name         TEXT NOT NULL,
        icon         TEXT NOT NULL DEFAULT 'place',
        is_default   INTEGER NOT NULL DEFAULT 0,
        sort_order   INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Inventory Items ──
    await db.execute('''
      CREATE TABLE inventory_items (
        id                  TEXT PRIMARY KEY,
        household_id        TEXT NOT NULL,
        name                TEXT NOT NULL,
        description         TEXT,
        category_id         TEXT REFERENCES inventory_categories(id) ON DELETE SET NULL,
        location_id         TEXT REFERENCES inventory_locations(id) ON DELETE SET NULL,
        quantity            INTEGER NOT NULL DEFAULT 0,
        unit                TEXT NOT NULL DEFAULT 'pieces',
        low_stock_threshold INTEGER,
        barcode             TEXT,
        barcode_type        TEXT NOT NULL DEFAULT 'none',
        expiry_date         TEXT,
        purchase_date       TEXT,
        notes               TEXT,
        created_by          TEXT,
        created_at          TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at          TEXT
      )
    ''');

    // ── Inventory Logs ──
    await db.execute('''
      CREATE TABLE inventory_logs (
        id              TEXT PRIMARY KEY,
        item_id         TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
        household_id    TEXT NOT NULL,
        action          TEXT NOT NULL,
        quantity_change  INTEGER NOT NULL DEFAULT 0,
        quantity_after   INTEGER NOT NULL DEFAULT 0,
        note            TEXT,
        performed_by    TEXT,
        performed_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Inventory Attachments ──
    await db.execute('''
      CREATE TABLE inventory_attachments (
        id              TEXT PRIMARY KEY,
        item_id         TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
        household_id    TEXT NOT NULL,
        drive_file_id   TEXT NOT NULL,
        file_name       TEXT NOT NULL,
        mime_type       TEXT NOT NULL DEFAULT 'application/octet-stream',
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        thumbnail_url   TEXT,
        web_view_link   TEXT NOT NULL,
        uploaded_by     TEXT NOT NULL,
        uploaded_at     TEXT NOT NULL DEFAULT (datetime('now')),
        description     TEXT
      )
    ''');

    // ── Indices for common queries ──
    await db.execute(
        'CREATE INDEX idx_tasks_household ON tasks(household_id)');
    await db.execute(
        'CREATE INDEX idx_tasks_status ON tasks(household_id, status)');
    await db.execute(
        'CREATE INDEX idx_subtasks_task ON subtasks(task_id)');
    await db.execute(
        'CREATE INDEX idx_checklists_household ON checklists(household_id)');
    await db.execute(
        'CREATE INDEX idx_checklist_items_checklist ON checklist_items(checklist_id)');
    await db.execute(
        'CREATE INDEX idx_plans_household ON scratch_plans(household_id)');
    await db.execute(
        'CREATE INDEX idx_plan_entries_plan ON plan_entries(plan_id)');
    await db.execute(
        'CREATE INDEX idx_plan_checklist_plan ON plan_checklist_items(plan_id)');
    await db.execute(
        'CREATE INDEX idx_task_attachments_task ON task_attachments(task_id)');
    await db.execute(
        'CREATE INDEX idx_task_attachments_household ON task_attachments(household_id)');

    // Inventory indices
    await db.execute(
        'CREATE INDEX idx_inventory_items_household ON inventory_items(household_id)');
    await db.execute(
        'CREATE INDEX idx_inventory_items_category ON inventory_items(category_id)');
    await db.execute(
        'CREATE INDEX idx_inventory_items_location ON inventory_items(location_id)');
    await db.execute(
        'CREATE INDEX idx_inventory_categories_household ON inventory_categories(household_id)');
    await db.execute(
        'CREATE INDEX idx_inventory_locations_household ON inventory_locations(household_id)');
    await db.execute(
        'CREATE INDEX idx_inventory_logs_item ON inventory_logs(item_id)');
    await db.execute(
        'CREATE INDEX idx_inventory_attachments_item ON inventory_attachments(item_id)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE inventory_categories (
          id           TEXT PRIMARY KEY,
          household_id TEXT NOT NULL,
          name         TEXT NOT NULL,
          icon         TEXT NOT NULL DEFAULT 'inventory_2',
          color        TEXT NOT NULL DEFAULT '#A5B4A5',
          is_default   INTEGER NOT NULL DEFAULT 0,
          sort_order   INTEGER NOT NULL DEFAULT 0,
          created_at   TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      await db.execute('''
        CREATE TABLE inventory_locations (
          id           TEXT PRIMARY KEY,
          household_id TEXT NOT NULL,
          name         TEXT NOT NULL,
          icon         TEXT NOT NULL DEFAULT 'place',
          is_default   INTEGER NOT NULL DEFAULT 0,
          sort_order   INTEGER NOT NULL DEFAULT 0,
          created_at   TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      await db.execute('''
        CREATE TABLE inventory_items (
          id                  TEXT PRIMARY KEY,
          household_id        TEXT NOT NULL,
          name                TEXT NOT NULL,
          description         TEXT,
          category_id         TEXT REFERENCES inventory_categories(id) ON DELETE SET NULL,
          location_id         TEXT REFERENCES inventory_locations(id) ON DELETE SET NULL,
          quantity            INTEGER NOT NULL DEFAULT 0,
          unit                TEXT NOT NULL DEFAULT 'pieces',
          low_stock_threshold INTEGER,
          barcode             TEXT,
          barcode_type        TEXT NOT NULL DEFAULT 'none',
          expiry_date         TEXT,
          purchase_date       TEXT,
          notes               TEXT,
          created_by          TEXT,
          created_at          TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at          TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE inventory_logs (
          id              TEXT PRIMARY KEY,
          item_id         TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
          household_id    TEXT NOT NULL,
          action          TEXT NOT NULL,
          quantity_change  INTEGER NOT NULL DEFAULT 0,
          quantity_after   INTEGER NOT NULL DEFAULT 0,
          note            TEXT,
          performed_by    TEXT,
          performed_at    TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      await db.execute('''
        CREATE TABLE inventory_attachments (
          id              TEXT PRIMARY KEY,
          item_id         TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
          household_id    TEXT NOT NULL,
          drive_file_id   TEXT NOT NULL,
          file_name       TEXT NOT NULL,
          mime_type       TEXT NOT NULL DEFAULT 'application/octet-stream',
          file_size_bytes INTEGER NOT NULL DEFAULT 0,
          thumbnail_url   TEXT,
          web_view_link   TEXT NOT NULL,
          uploaded_by     TEXT NOT NULL,
          uploaded_at     TEXT NOT NULL DEFAULT (datetime('now')),
          description     TEXT
        )
      ''');
      await db.execute(
          'CREATE INDEX idx_inventory_items_household ON inventory_items(household_id)');
      await db.execute(
          'CREATE INDEX idx_inventory_items_category ON inventory_items(category_id)');
      await db.execute(
          'CREATE INDEX idx_inventory_items_location ON inventory_items(location_id)');
      await db.execute(
          'CREATE INDEX idx_inventory_categories_household ON inventory_categories(household_id)');
      await db.execute(
          'CREATE INDEX idx_inventory_locations_household ON inventory_locations(household_id)');
      await db.execute(
          'CREATE INDEX idx_inventory_logs_item ON inventory_logs(item_id)');
      await db.execute(
          'CREATE INDEX idx_inventory_attachments_item ON inventory_attachments(item_id)');
    }

    if (oldVersion < 3) {
      await db.execute("ALTER TABLE subtasks ADD COLUMN household_id TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE checklist_items ADD COLUMN household_id TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE plan_entries ADD COLUMN household_id TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE plan_checklist_items ADD COLUMN household_id TEXT NOT NULL DEFAULT ''");
    }
  }
}
