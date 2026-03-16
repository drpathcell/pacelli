import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/storage_setup_screen.dart';
import '../../features/household/presentation/screens/create_household_screen.dart';
import '../../features/household/presentation/screens/drive_setup_screen.dart';
import '../../features/household/presentation/screens/household_screen.dart';
import '../../features/tasks/presentation/screens/create_task_screen.dart';
import '../../features/tasks/presentation/screens/edit_task_screen.dart';
import '../../features/tasks/presentation/screens/calendar_screen.dart';
import '../../features/tasks/presentation/screens/home_screen.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../features/plans/presentation/screens/create_plan_screen.dart';
import '../../features/plans/presentation/screens/plan_day_editor_screen.dart';
import '../../features/plans/presentation/screens/plan_finalise_screen.dart';
import '../../features/plans/presentation/screens/plan_view_screen.dart';
import '../../features/settings/presentation/screens/appearance_screen.dart';
import '../../features/settings/presentation/screens/burn_data_screen.dart';
import '../../features/import_export/presentation/screens/import_export_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/inventory/presentation/screens/inventory_item_detail_screen.dart';
import '../../features/inventory/presentation/screens/create_inventory_item_screen.dart';
import '../../features/inventory/presentation/screens/edit_inventory_item_screen.dart';
import '../../features/inventory/presentation/screens/manage_inventory_categories_screen.dart';
import '../../features/inventory/presentation/screens/manage_inventory_locations_screen.dart';
import '../../features/inventory/presentation/screens/barcode_scanner_screen.dart';
import '../../features/inventory/presentation/screens/batch_create_screen.dart';
import '../../features/inventory/presentation/screens/virtual_barcode_view_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/notification_settings_screen.dart';
import '../../features/settings/presentation/screens/ai_assistant_screen.dart';
import '../../features/settings/presentation/screens/privacy_encryption_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/ai_chat/presentation/screens/chat_screen.dart';
import '../../features/capabilities/presentation/screens/capabilities_screen.dart';
import '../../features/manual/presentation/screens/manual_screen.dart';
import '../../features/manual/presentation/screens/manual_entry_detail_screen.dart';
import '../../features/manual/presentation/screens/create_manual_entry_screen.dart';
import '../../features/manual/presentation/screens/edit_manual_entry_screen.dart';
import '../../features/manual/presentation/screens/manage_manual_categories_screen.dart';
import '../../features/feedback/presentation/screens/feedback_screen.dart';
import '../../shared/widgets/main_shell.dart';

/// Route path constants — use these instead of hardcoded strings.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String tasks = '/tasks';
  static const String calendar = '/calendar';
  static const String settings = '/settings';
  static const String createHousehold = '/create-household';
  static const String household = '/household';
  static const String storageSetup = '/storage-setup';
  static const String appearance = '/appearance';
  static const String burnData = '/burn-data';
  static const String privacyEncryption = '/privacy-encryption';
  static const String driveSetup = '/drive-setup';
  static const String notifications = '/notifications';
  static const String importExport = '/import-export';
  static const String search = '/search';
  static const String inventory = '/inventory';
  static const String inventoryItem = '/inventory/item';
  static const String createInventoryItem = '/inventory/create';
  static const String editInventoryItem = '/inventory/edit';
  static const String inventoryCategories = '/inventory/categories';
  static const String inventoryLocations = '/inventory/locations';
  static const String barcodeScanner = '/inventory/scan';
  static const String batchCreate = '/inventory/batch-create';
  static const String virtualBarcodeView = '/inventory/qr-view';
  static const String manual = '/manual';
  static const String manualCategories = '/manual/categories';
  static const String aiAssistant = '/ai-assistant';
  static const String aiChat = '/ai-chat';
  static const String capabilities = '/capabilities';
  static const String feedback = '/feedback';
}

/// Key for the shell navigator (bottom nav tabs).
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter provider — accessible throughout the app via Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      // Splash screen — checks auth status and redirects
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Authentication routes (no bottom nav)
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // Storage setup onboarding (no bottom nav)
      GoRoute(
        path: AppRoutes.storageSetup,
        builder: (context, state) => const StorageSetupScreen(),
      ),

      // Burn data — full-screen fire animation during data wipe
      GoRoute(
        path: AppRoutes.burnData,
        builder: (context, state) => const BurnDataScreen(),
      ),

      // Appearance settings — theme mode & colour scheme
      GoRoute(
        path: AppRoutes.appearance,
        builder: (context, state) => const AppearanceScreen(),
      ),

      // Privacy & Encryption info screen
      GoRoute(
        path: AppRoutes.privacyEncryption,
        builder: (context, state) => const PrivacyEncryptionScreen(),
      ),

      // AI Assistant settings
      GoRoute(
        path: AppRoutes.aiAssistant,
        builder: (context, state) => const AiAssistantScreen(),
      ),

      // AI Chat (full-screen modal from center FAB)
      GoRoute(
        path: AppRoutes.aiChat,
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ChatScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),

      // Capabilities — "What can Pacelli do?"
      GoRoute(
        path: AppRoutes.capabilities,
        builder: (context, state) => const CapabilitiesScreen(),
      ),

      // Feedback & Insights
      GoRoute(
        path: AppRoutes.feedback,
        builder: (context, state) => const FeedbackScreen(),
      ),

      // Notification settings
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      // Import/Export
      GoRoute(
        path: AppRoutes.importExport,
        builder: (context, state) {
          final householdId = state.extra as String;
          return ImportExportScreen(householdId: householdId);
        },
      ),

      // Global search
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) {
          final householdId = state.extra as String;
          return SearchScreen(householdId: householdId);
        },
      ),

      // Create household (no bottom nav — modal-style)
      GoRoute(
        path: AppRoutes.createHousehold,
        builder: (context, state) => const CreateHouseholdScreen(),
      ),

      // Drive setup (full-screen, no bottom nav)
      GoRoute(
        path: AppRoutes.driveSetup,
        builder: (context, state) {
          final householdId = state.extra as String;
          return DriveSetupScreen(householdId: householdId);
        },
      ),

      // Household management
      GoRoute(
        path: AppRoutes.household,
        builder: (context, state) => const HouseholdScreen(),
      ),

      // Create task (full-screen, no bottom nav)
      GoRoute(
        path: '${AppRoutes.tasks}/create',
        builder: (context, state) {
          final householdId = state.extra as String;
          return CreateTaskScreen(householdId: householdId);
        },
      ),

      // Task detail (full-screen, no bottom nav)
      GoRoute(
        path: '${AppRoutes.tasks}/:taskId',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId']!;
          return TaskDetailScreen(taskId: taskId);
        },
      ),

      // Edit task (full-screen, no bottom nav)
      GoRoute(
        path: '${AppRoutes.tasks}/:taskId/edit',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId']!;
          return EditTaskScreen(taskId: taskId);
        },
      ),

      // ── Inventory (full-screen, no bottom nav) ────────────
      GoRoute(
        path: AppRoutes.inventory,
        builder: (context, state) {
          final householdId = state.extra as String;
          return InventoryScreen(householdId: householdId);
        },
      ),
      GoRoute(
        path: AppRoutes.inventoryItem,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return InventoryItemDetailScreen(
            householdId: extra['householdId']!,
            itemId: extra['itemId']!,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.createInventoryItem,
        builder: (context, state) {
          final householdId = state.extra as String;
          return CreateInventoryItemScreen(householdId: householdId);
        },
      ),
      GoRoute(
        path: AppRoutes.editInventoryItem,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return EditInventoryItemScreen(
            householdId: extra['householdId']!,
            itemId: extra['itemId']!,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.inventoryCategories,
        builder: (context, state) {
          final householdId = state.extra as String;
          return ManageInventoryCategoriesScreen(householdId: householdId);
        },
      ),
      GoRoute(
        path: AppRoutes.inventoryLocations,
        builder: (context, state) {
          final householdId = state.extra as String;
          return ManageInventoryLocationsScreen(householdId: householdId);
        },
      ),
      GoRoute(
        path: AppRoutes.barcodeScanner,
        builder: (context, state) {
          final householdId = state.extra as String;
          return BarcodeScannerScreen(householdId: householdId);
        },
      ),
      GoRoute(
        path: AppRoutes.batchCreate,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return BatchCreateScreen(
            householdId: extra['householdId'] as String,
            baseName: extra['baseName'] as String,
            categoryId: extra['categoryId'] as String?,
            locationId: extra['locationId'] as String?,
            unit: extra['unit'] as String,
            expiryDate: extra['expiryDate'] as DateTime?,
            purchaseDate: extra['purchaseDate'] as DateTime?,
            notes: extra['notes'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.virtualBarcodeView,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return VirtualBarcodeViewScreen(
            itemName: extra['itemName']!,
            barcode: extra['barcode']!,
          );
        },
      ),

      // ── House Manual (full-screen, no bottom nav) ────────────
      GoRoute(
        path: AppRoutes.manual,
        builder: (context, state) {
          final householdId = state.extra as String;
          return ManualScreen(householdId: householdId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.manual}/create',
        builder: (context, state) {
          final householdId = state.extra as String;
          return CreateManualEntryScreen(householdId: householdId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.manual}/:entryId',
        builder: (context, state) {
          final entryId = state.pathParameters['entryId']!;
          return ManualEntryDetailScreen(entryId: entryId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.manual}/:entryId/edit',
        builder: (context, state) {
          final entryId = state.pathParameters['entryId']!;
          return EditManualEntryScreen(entryId: entryId);
        },
      ),
      GoRoute(
        path: AppRoutes.manualCategories,
        builder: (context, state) {
          final householdId = state.extra as String;
          return ManageManualCategoriesScreen(householdId: householdId);
        },
      ),

      // ── Scratch Plans (full-screen, no bottom nav) ────────────
      GoRoute(
        path: '/plans/create',
        builder: (context, state) {
          final householdId = state.extra as String;
          return CreatePlanScreen(householdId: householdId);
        },
      ),
      GoRoute(
        path: '/plans/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return PlanViewScreen(planId: planId);
        },
      ),
      GoRoute(
        path: '/plans/:planId/day/:date',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          final date = DateTime.parse(state.pathParameters['date']!);
          return PlanDayEditorScreen(planId: planId, date: date);
        },
      ),
      GoRoute(
        path: '/plans/:planId/finalise',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return PlanFinaliseScreen(planId: planId);
        },
      ),

      // ── Main app with bottom navigation ──────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          // Map route → nav index. Index 2 is the center FAB (no tab).
          // 0 = Home, 1 = Tasks, (2 = AI FAB gap), 3 = Calendar, 4 = Settings
          int currentIndex = 0;
          final location = state.uri.path;
          if (location == AppRoutes.tasks) {
            currentIndex = 1;
          } else if (location == AppRoutes.calendar) {
            currentIndex = 3;
          } else if (location == AppRoutes.settings) {
            currentIndex = 4;
          }

          return MainShell(
            currentIndex: currentIndex,
            onTabChanged: (index) {
              // Skip index 2 (AI FAB dummy spacer)
              switch (index) {
                case 0:
                  context.go(AppRoutes.home);
                  break;
                case 1:
                  context.go(AppRoutes.tasks);
                  break;
                case 3:
                  context.go(AppRoutes.calendar);
                  break;
                case 4:
                  context.go(AppRoutes.settings);
                  break;
              }
            },
            onAiChatPressed: () => context.push(AppRoutes.aiChat),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],

    // Error page for unknown routes
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ),
  );
});
