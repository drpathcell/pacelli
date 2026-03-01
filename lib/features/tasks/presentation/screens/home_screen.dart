import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/extensions.dart';

/// Home screen — the main hub of the Pacelli app.
///
/// Shows the user's tasks for today, quick actions, and
/// navigation to other sections (calendar, lists, settings).
///
/// This is a placeholder that will be fleshed out in the next phase.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = currentUser?.userMetadata?['full_name'] ?? 'Friend';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $userName',
              style: context.textTheme.titleLarge,
            ),
            Text(
              DateTime.now().formatted,
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Placeholder illustration
              Icon(
                Icons.home_rounded,
                size: 80,
                color: context.colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Pacelli!',
                style: context.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your household tasks will appear here.\nLet\'s start by creating your household.',
                style: context.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Navigate to household creation
                  context.showSnackBar(
                    'Household creation coming soon!',
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Household'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
