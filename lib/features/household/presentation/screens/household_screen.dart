import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
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
      context.showSnackBar(context.l10n.householdInviteValidEmail, isError: true);
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
          context.l10n.householdInviteSent(email),
        );
        // Refresh members list
        ref.invalidate(householdMembersProvider(householdId));
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          context.l10n.householdInviteFailed,
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
        title: Text(context.l10n.householdTitle),
      ),
      body: householdAsync.when(
        loading: () => LoadingView(message: context.l10n.householdLoading),
        error: (e, _) => ErrorView(
          message: context.l10n.householdCouldNotLoad,
          onRetry: () => ref.invalidate(currentHouseholdProvider),
        ),
        data: (data) {
          if (data == null) {
            return Center(child: Text(context.l10n.householdNotFound));
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
                  (household['name'] as String?) ?? context.l10n.householdMyHousehold,
                  style: context.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  role == 'admin' ? context.l10n.householdRoleAdmin : context.l10n.householdRoleMember,
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
          context.l10n.householdMembers,
          style: context.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        membersAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(20),
            child: LoadingView(message: context.l10n.householdLoadingMembers),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.householdCouldNotLoadMembers),
          ),
          data: (members) {
            return Column(
              children: members.map((member) {
                final profile =
                    member['profiles'] as Map<String, dynamic>? ?? {};
                final memberRole = member['role'] ?? 'member';
                final currentUser = FirebaseAuth.instance.currentUser;
                final isCurrentUser = member['user_id'] == currentUser?.uid;
                // Prefer the encrypted profile name; for the current user
                // fall back to FirebaseAuth's displayName, then the email
                // local-part — both are populated even when the encrypted
                // profile field is still empty (Apple Sign-In, freshly-
                // created profiles before household-key encryption).
                String name =
                    (profile['full_name'] as String?)?.trim() ?? '';
                if (name.isEmpty && isCurrentUser) {
                  final dn = currentUser?.displayName?.trim() ?? '';
                  if (dn.isNotEmpty) {
                    name = dn;
                  } else if (currentUser?.email != null &&
                      currentUser!.email!.contains('@')) {
                    name = currentUser.email!.split('@').first;
                  }
                }
                if (name.isEmpty) name = context.l10n.commonUnknown;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          context.colorScheme.primary.withValues(alpha: 0.2),
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
                      '$name${isCurrentUser ? ' ${context.l10n.householdYouSuffix}' : ''}',
                      style: context.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      memberRole == 'admin' ? context.l10n.householdRoleAdminLabel : context.l10n.householdRoleMemberLabel,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Storage section ──
        Text(
          context.l10n.householdStorageSection,
          style: context.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        // Data Storage card — shows current backend (local vs cloud).
        _DataStorageCard(householdId: householdId),
        const SizedBox(height: 8),

        // File Storage card — Google Drive integration.
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  context.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.cloud_outlined,
                color: context.colorScheme.primary,
              ),
            ),
            title: Text(
              context.l10n.householdFileStorage,
              style: context.textTheme.titleMedium,
            ),
            subtitle: Text(
              context.l10n.householdFileStorageSubtitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => context.push(
              AppRoutes.driveSetup,
              extra: householdId,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Invite section (only for admins)
        if (role == 'admin') ...[
          Text(
            context.l10n.householdInvitePartner,
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.householdInviteMessage,
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
                  decoration: InputDecoration(
                    labelText: context.l10n.householdPartnerEmail,
                    hintText: context.l10n.householdPartnerEmailHint,
                    prefixIcon: const Icon(Icons.email_outlined),
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
                    : Text(context.l10n.householdInvite),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Card showing current data backend (local vs cloud) with option to change.
class _DataStorageCard extends ConsumerWidget {
  final String householdId;
  const _DataStorageCard({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(localDatabaseProvider);
    final isLocal = db != null;
    final backendLabel =
        isLocal ? context.l10n.settingsBackendLocal : context.l10n.settingsBackendCloud;
    final icon = isLocal ? Icons.phone_iphone_rounded : Icons.cloud_sync_outlined;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: context.colorScheme.primary),
        ),
        title: Text(
          context.l10n.settingsDataStorage,
          style: context.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              backendLabel,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            if (!isLocal) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.settingsEndToEndEncrypted,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => context.push(AppRoutes.storageSetup),
      ),
    );
  }
}
