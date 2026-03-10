import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/household_providers.dart';
import '../../data/household_service.dart';

/// Screen for creating a new household.
class CreateHouseholdScreen extends ConsumerStatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  ConsumerState<CreateHouseholdScreen> createState() =>
      _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends ConsumerState<CreateHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await HouseholdService.createHousehold(_nameController.text.trim());

      // Refresh the household provider so the home screen picks it up
      ref.invalidate(currentHouseholdProvider);

      if (mounted) {
        context.showSnackBar(context.l10n.householdCreated);
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          context.l10n.householdCreateFailed,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(context.l10n.householdCreateTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Illustration
              Icon(
                Icons.home_rounded,
                size: 80,
                color: context.colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 24),

              Text(
                context.l10n.householdNameYour,
                style: context.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.householdNameSubtitle,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Household name input
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.householdNameLabel,
                  hintText: context.l10n.householdNameHint,
                  prefixIcon: const Icon(Icons.home_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.householdEnterName;
                  }
                  if (value.trim().length < 2) {
                    return context.l10n.householdNameMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Create button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleCreate,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.l10n.householdCreateButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
