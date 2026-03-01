import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/household_providers.dart';
import '../../data/household_service.dart';

/// Screen for managing the household — view members, invite partner.
class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  final _emailController = TextEditingController();
  bool _isSendingInvite = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleInvite(String householdId) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.isValidEmail) {
      context.showSnackBar('Please enter a valid email address.', isError: true);
      return;
    }

    setState(() => _isSendingInvite = true);

    try {
      await HouseholdService.inviteByEmail(
        householdId: householdId,
        email: email,
      );

      _emailController.clear();

      if (mounted) {
        context.showSnackBar(
          'Invite sent to $email! They\'ll see the household when they sign up.',
        );
        // Refresh members list
        ref.invalidate(householdMembersProvider(householdId));
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          'Failed to send invite. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingInvite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(currentHouseholdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Household'),
      ),
      body: householdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading household: $e'),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No household found.'));
          }

          final household = data['household'] as Map<String, dynamic>;
          final role = data['role'] as String;
          final householdId = household['id'] as String;

          return _HouseholdContent(
            household: household,
            role: role,
            householdId: householdId,
            emailController: _emailController,
            isSendingInvite: _isSendingInvite,
            onInvite: () => _handleInvite(householdId),
          );
        },
      ),
    );
  }
}

class _HouseholdContent extends ConsumerWidget {
  final Map<String, dynamic> household;
  final String role;
  final String householdId;
  final TextEditingController emailController;
  final bool isSendingInvite;
  final VoidCallback onInvite;

  const _HouseholdContent({
    required this.household,
    required this.role,
    required this.householdId,
    required this.emailController,
    required this.isSendingInvite,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(householdMembersProvider(householdId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Household info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.home_rounded,
                  size: 48,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  household['name'] ?? 'My Household',
                  style: context.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'You are ${role == 'admin' ? 'the admin' : 'a member'}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Members section
        Text(
          'Members',
          style: context.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        membersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Error loading members: $e'),
          data: (members) {
            return Column(
              children: members.map((member) {
                final profile =
                    member['profiles'] as Map<String, dynamic>? ?? {};
                final name = profile['full_name'] ?? 'Unknown';
                final memberRole = member['role'] ?? 'member';
                final isCurrentUser = member['user_id'] == currentUserId;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          context.colorScheme.primary.withOpacity(0.2),
                      child: Text(
                        name.toString().isNotEmpty
                            ? name.toString()[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      '$name${isCurrentUser ? ' (You)' : ''}',
                      style: context.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      memberRole == 'admin' ? 'Admin' : 'Member',
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        // Invite section (only for admins)
        if (role == 'admin') ...[
          Text(
            'Invite Partner',
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Send an invite to your partner\'s email. They\'ll be added to your household when they sign up or log in.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Partner\'s email',
                    hintText: 'partner@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isSendingInvite ? null : onInvite,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                child: isSendingInvite
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Invite'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
