// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonClose => 'Close';

  @override
  String get commonChange => 'Change';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonToday => 'Today';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get commonUnassigned => 'Unassigned';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUntitled => 'Untitled';

  @override
  String get commonShared => 'Shared';

  @override
  String commonError(String error) {
    return 'Error: $error';
  }

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSignInToHousehold => 'Sign in to your household';

  @override
  String get authOrSignInWithEmail => 'or sign in with email';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authEnterEmail => 'Please enter your email';

  @override
  String get authEnterValidEmail => 'Please enter a valid email';

  @override
  String get authEnterPassword => 'Please enter your password';

  @override
  String get authPasswordMinLength => 'Password must be at least 6 characters';

  @override
  String get authEnterEmailFirst => 'Enter your email first';

  @override
  String get authPasswordResetSent =>
      'Password reset email sent! Check your inbox.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authGoogleSignInFailed =>
      'Google sign-in failed. Please try again.';

  @override
  String get authLoginFailed =>
      'Login failed. Please check your email and password.';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authStartOrganising => 'Start organising your home with love';

  @override
  String get authOrSignUpWithEmail => 'or sign up with email';

  @override
  String get authFullName => 'Full name';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authEnterName => 'Please enter your name';

  @override
  String get authEnterAPassword => 'Please enter a password';

  @override
  String get authPasswordMin8 => 'Password must be at least 8 characters';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authCreateAccountButton => 'Create Account';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? ';

  @override
  String get authAccountCreated => 'Account created! Welcome to Pacelli.';

  @override
  String get authSignupFailed => 'Signup failed. Please try again.';

  @override
  String get authAppName => 'Pacelli';

  @override
  String get authTagline => 'A peaceful home, organised with love.';

  @override
  String homeHelloGreeting(String userName) {
    return 'Hello, $userName';
  }

  @override
  String get homeLoadingHousehold => 'Loading household…';

  @override
  String get homeSomethingWentWrong => 'Something went wrong';

  @override
  String get homeTryAgain => 'Try again';

  @override
  String get homeWelcomeToPacelli => 'Welcome to Pacelli!';

  @override
  String get homeWelcomeSubtitle =>
      'Your household tasks will appear here.\nLet\'s start by creating your household.';

  @override
  String get homeCreateHousehold => 'Create Household';

  @override
  String get homeHouseholdSetUp => 'Your household is set up!';

  @override
  String get homeTodaysOverview => 'Today\'s Overview';

  @override
  String get homeCompleted => 'Completed';

  @override
  String get homePending => 'Pending';

  @override
  String get homeOverdue => 'Overdue';

  @override
  String get homeRecentTasks => 'Recent Tasks';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeFailedToLoadTasks => 'Failed to load tasks';

  @override
  String get homeNoTasksYet =>
      'No tasks yet — they\'ll show up here once you create some!';

  @override
  String get homeCreateTask => 'Create Task';

  @override
  String get homeCouldNotCompleteTask => 'Could not complete task';

  @override
  String get homeDueToday => 'Due today';

  @override
  String get homeDueTomorrow => 'Due tomorrow';

  @override
  String homeDueDate(String date) {
    return 'Due $date';
  }

  @override
  String get homeMyHousehold => 'My Household';

  @override
  String get taskNewTask => 'New Task';

  @override
  String get taskTitle => 'Task title';

  @override
  String get taskTitleHint => 'e.g. Clean the kitchen';

  @override
  String get taskEnterTitle => 'Please enter a title';

  @override
  String get taskDescriptionOptional => 'Description (optional)';

  @override
  String get taskDescriptionHint => 'Add any details...';

  @override
  String get taskCategory => 'Category';

  @override
  String get taskFailedToLoadCategories => 'Failed to load categories';

  @override
  String get taskNewCategory => 'New Category';

  @override
  String get taskCategoryName => 'Category name';

  @override
  String get taskPriority => 'Priority';

  @override
  String get taskPriorityLow => 'Low';

  @override
  String get taskPriorityMedium => 'Medium';

  @override
  String get taskPriorityHigh => 'High';

  @override
  String get taskPriorityUrgent => 'Urgent';

  @override
  String get taskStartsToday => 'Starts: Today';

  @override
  String taskStartsDate(String date) {
    return 'Starts: $date';
  }

  @override
  String get taskNoDueDate => 'No due date';

  @override
  String taskDueDate(String date) {
    return 'Due: $date';
  }

  @override
  String get taskAssignTo => 'Assign to';

  @override
  String get taskSharedTask => 'Shared task (both of you)';

  @override
  String get taskSharedTaskSubtitle => 'Anyone can complete it';

  @override
  String get taskFailedToLoadMembers => 'Failed to load members';

  @override
  String get taskMeSuffix => '(me)';

  @override
  String get taskRepeat => 'Repeat';

  @override
  String get taskRepeatNever => 'Never';

  @override
  String get taskRepeatDaily => 'Daily';

  @override
  String get taskRepeatWeekly => 'Weekly';

  @override
  String get taskRepeatBiweekly => 'Every 2 weeks';

  @override
  String get taskRepeatMonthly => 'Monthly';

  @override
  String get taskSubtasks => 'Subtasks';

  @override
  String get taskAddSubtaskHint => 'Add a subtask...';

  @override
  String get taskDiscardTitle => 'Discard task?';

  @override
  String get taskDiscardMessage =>
      'You have unsaved changes. Are you sure you want to go back?';

  @override
  String get taskKeepEditing => 'Keep editing';

  @override
  String get taskDiscard => 'Discard';

  @override
  String get taskCreated => 'Task created!';

  @override
  String get taskEditTask => 'Edit Task';

  @override
  String get taskLoadingTask => 'Loading task…';

  @override
  String get taskFailedToLoadTask => 'Failed to load task';

  @override
  String get taskNoHousehold => 'Task has no household';

  @override
  String get taskUpdated => 'Task updated!';

  @override
  String get taskDetails => 'Task Details';

  @override
  String get taskLoadingDetails => 'Loading task details…';

  @override
  String get taskCouldNotLoadDetails => 'Could not load task details.';

  @override
  String get taskDeleteTitle => 'Delete task?';

  @override
  String get taskDeleteMessage =>
      'This will permanently delete this task and all its subtasks.';

  @override
  String get taskStatusCompleted => 'Completed';

  @override
  String get taskReopenTask => 'Reopen Task';

  @override
  String get taskMarkComplete => 'Mark Complete';

  @override
  String get taskLabelCategory => 'Category';

  @override
  String get taskLabelStarts => 'Starts';

  @override
  String get taskLabelDue => 'Due';

  @override
  String get taskLabelAssignedTo => 'Assigned to';

  @override
  String get taskSharedBoth => 'Shared (both)';

  @override
  String get taskLabelRepeats => 'Repeats';

  @override
  String get taskLabelCreatedBy => 'Created by';

  @override
  String get taskRemoveAttachmentTitle => 'Remove attachment?';

  @override
  String taskRemoveAttachmentMessage(String fileName) {
    return 'Remove \"$fileName\" from this task? The file will remain in Google Drive.';
  }

  @override
  String get taskRemove => 'Remove';

  @override
  String get taskAttachFile => 'Attach a file';

  @override
  String get taskAttachAfterSave =>
      'You can attach files after saving the task.';

  @override
  String taskPendingAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return '$count $_temp0 ready to upload';
  }

  @override
  String get taskUploadingAttachments => 'Uploading attachments…';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get tasksCreateHouseholdFirst => 'Create a household first';

  @override
  String get tasksFilterAll => 'All';

  @override
  String get tasksFilterPending => 'Pending';

  @override
  String get tasksFilterDone => 'Done';

  @override
  String get tasksAllCategories => 'All Categories';

  @override
  String get tasksMore => 'More';

  @override
  String get tasksCouldNotLoad => 'Could not load tasks.';

  @override
  String get tasksNoTasksYet => 'No tasks yet.\nTap + to create one!';

  @override
  String get tasksAllCaughtUp => 'All caught up!';

  @override
  String get tasksNoCompletedYet => 'No completed tasks yet.';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarActivePlans => 'Active plans';

  @override
  String get calendarNewPlan => 'New Plan';

  @override
  String get calendarLoading => 'Loading calendar…';

  @override
  String get calendarCouldNotLoad => 'Could not load calendar.';

  @override
  String get calendarNoHousehold => 'No household yet';

  @override
  String get calendarLoadingTasks => 'Loading tasks…';

  @override
  String get calendarCouldNotLoadTasks => 'Could not load tasks.';

  @override
  String get attachTitle => 'Attach a File';

  @override
  String get attachPickFile => 'Pick a file';

  @override
  String get attachPickFileSubtitle =>
      'PDF, document, spreadsheet, or any file';

  @override
  String get attachTakePhoto => 'Take a photo';

  @override
  String get attachTakePhotoSubtitle => 'Open the camera';

  @override
  String get attachPickGallery => 'Pick from gallery';

  @override
  String get attachPickGallerySubtitle => 'Choose an existing photo';

  @override
  String get attachUploading => 'Uploading file…';

  @override
  String get attachDriveNotSetUp =>
      'Google Drive is not set up for this household. Ask the household admin to connect it.';

  @override
  String get attachDriveDisabled =>
      'Google Drive storage is currently disabled.';

  @override
  String get attachSuccess => 'File attached successfully!';

  @override
  String attachUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get checklistNewChecklist => 'New Checklist';

  @override
  String get checklistHint => 'e.g. Groceries, Travel Essentials';

  @override
  String get checklistAddItem => 'Add Item';

  @override
  String get checklistItemName => 'Item name';

  @override
  String get checklistDeleteTitle => 'Delete Checklist?';

  @override
  String get checklistDeleteMessage =>
      'This will delete the checklist and all its items.';

  @override
  String get checklistCouldNotCreate => 'Could not create checklist';

  @override
  String get checklistCouldNotAdd => 'Could not add item';

  @override
  String get checklistCouldNotUpdate => 'Could not update item';

  @override
  String get checklistCouldNotPush => 'Could not push item as task';

  @override
  String get checklistCouldNotDeleteItem => 'Could not delete item';

  @override
  String get checklistCouldNotDeleteList => 'Could not delete checklist';

  @override
  String checklistAddedAsTask(String title) {
    return '\"$title\" added as task';
  }

  @override
  String checklistSectionTitle(int count) {
    return 'Checklists · $count';
  }

  @override
  String get checklistNoChecklists => 'No checklists yet';

  @override
  String get checklistBadgePlan => 'Plan';

  @override
  String get checklistBadgeList => 'List';

  @override
  String get checklistPushAsTask => 'Push as Task';

  @override
  String checklistCountProgress(int checked, int total) {
    return '$checked/$total';
  }

  @override
  String get planNewPlan => 'New Plan';

  @override
  String get planStartFromTemplate => 'Start from a template';

  @override
  String get planWeeklyDinnerPlanner => 'Weekly Dinner Planner';

  @override
  String get planWeeklyDinnerDescription =>
      '7 dinners for the week — one per day';

  @override
  String get planOrStartFromScratch => 'Or start from scratch';

  @override
  String get planTitle => 'Plan title';

  @override
  String get planTitleHint => 'e.g. Meal Prep Week, Holiday Trip';

  @override
  String get planGiveItAName => 'Give it a name';

  @override
  String get planTypeWeek => 'Week';

  @override
  String get planTypeMonth => 'Month';

  @override
  String get planTypeCustom => 'Custom';

  @override
  String get planCreatePlan => 'Create Plan';

  @override
  String planFailedToCreate(String error) {
    return 'Failed to create plan: $error';
  }

  @override
  String get planSelectDates => 'Select start and end dates';

  @override
  String get planConfirm => 'Confirm';

  @override
  String planDaysCount(int count) {
    return '$count days';
  }

  @override
  String planStartsDate(String date) {
    return 'Starts: $date';
  }

  @override
  String planTemplateEntries(String type, int count) {
    return '$type plan • $count entries';
  }

  @override
  String get planLoadingPlan => 'Loading plan…';

  @override
  String get planCouldNotLoad => 'Could not load plan.';

  @override
  String get planInvalidMissingDates => 'Invalid plan: missing dates';

  @override
  String get planInvalidUnreadableDates => 'Invalid plan: unreadable dates';

  @override
  String get planSaveAsTemplate => 'Save as Template';

  @override
  String get planTemplateName => 'Template name';

  @override
  String get planFinalise => 'Finalise';

  @override
  String get planFinalisedChip => 'Finalised';

  @override
  String get planTapToAdd =>
      'Tap + to add meals, activities, or anything you\'re planning.';

  @override
  String get planChecklist => 'Checklist';

  @override
  String get planAddItemHint => 'Add item...';

  @override
  String get planNoItemsYet =>
      'No items yet. Add things you need to buy or do.';

  @override
  String planTemplateSaved(String name) {
    return 'Template \"$name\" saved!';
  }

  @override
  String planFailedToSaveTemplate(String error) {
    return 'Failed to save template: $error';
  }

  @override
  String planFailedToAddItem(String error) {
    return 'Failed to add item: $error';
  }

  @override
  String get planFinalisePlan => 'Finalise Plan';

  @override
  String get planLoadingEntries => 'Loading plan entries…';

  @override
  String get planPushToCalendar => 'Push to Calendar?';

  @override
  String planPushSummary(int tasks, int notes) {
    return '$tasks task(s) and $notes note(s) will be created.\n\nSkipped entries won\'t be added to the calendar.';
  }

  @override
  String get planPushToCalendarButton => 'Push to Calendar';

  @override
  String get planFinalisedSuccess => 'Plan Finalised!';

  @override
  String get planEntriesPushed =>
      'Your entries have been pushed to the calendar.';

  @override
  String get planViewCalendar => 'View Calendar';

  @override
  String planFailedToFinalise(String error) {
    return 'Failed to finalise: $error';
  }

  @override
  String get planNoEntriesToFinalise => 'No entries to finalise.';

  @override
  String get planGoBack => 'Go Back';

  @override
  String get planInfoBanner =>
      'Choose what each entry becomes on your calendar. Tasks can be assigned and completed. Notes are lightweight reminders.';

  @override
  String get planActionTask => 'Task';

  @override
  String get planActionNote => 'Note';

  @override
  String get planActionSkip => 'Skip';

  @override
  String get planLoadingDay => 'Loading day entries…';

  @override
  String get planCouldNotLoadDay => 'Could not load day entries.';

  @override
  String planFailedToAdd(String error) {
    return 'Failed to add: $error';
  }

  @override
  String planFailedToDelete(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get planNewLabel => 'New Label';

  @override
  String get planLabelHint => 'e.g. Dessert, Outing';

  @override
  String get planEditEntry => 'Edit Entry';

  @override
  String get planWhatsPlanned => 'What\'s planned?';

  @override
  String get planCustomLabel => 'Custom';

  @override
  String planWhatsForLabel(String label) {
    return 'What\'s for $label?';
  }

  @override
  String planAddNeedsFor(String entry) {
    return 'Add needs for \"$entry\"';
  }

  @override
  String get planNeedsHint => 'e.g. pasta, mince, tomatoes';

  @override
  String get planNeedsHelper => 'Separate with commas';

  @override
  String get planAddToList => 'Add to List';

  @override
  String planItemsAddedToChecklist(int count) {
    return '$count item(s) added to checklist';
  }

  @override
  String planFailedToUpdate(String error) {
    return 'Failed to update: $error';
  }

  @override
  String get planAddToChecklist => 'Add to checklist';

  @override
  String get planEdit => 'Edit';

  @override
  String get planLabelDinner => 'Dinner';

  @override
  String get planLabelBreakfast => 'Breakfast';

  @override
  String get planLabelLunch => 'Lunch';

  @override
  String get planLabelSnack => 'Snack';

  @override
  String get planLabelActivity => 'Activity';

  @override
  String get planLabelTransport => 'Transport';

  @override
  String get planLabelAccommodation => 'Accommodation';

  @override
  String get householdCreateTitle => 'Create Household';

  @override
  String get householdNameYour => 'Name your household';

  @override
  String get householdNameSubtitle =>
      'This is what you and your partner will see.\nYou can change it anytime.';

  @override
  String get householdNameLabel => 'Household name';

  @override
  String get householdNameHint => 'e.g. The Celis Home';

  @override
  String get householdEnterName => 'Please enter a name for your household';

  @override
  String get householdNameMinLength => 'Name must be at least 2 characters';

  @override
  String get householdCreateButton => 'Create Household';

  @override
  String get householdCreated => 'Household created! Welcome home.';

  @override
  String get householdCreateFailed =>
      'Failed to create household. Please try again.';

  @override
  String get householdTitle => 'Household';

  @override
  String get householdLoading => 'Loading household…';

  @override
  String get householdCouldNotLoad => 'Could not load household.';

  @override
  String get householdNotFound => 'No household found.';

  @override
  String get householdMyHousehold => 'My Household';

  @override
  String get householdRoleAdmin => 'You are the admin';

  @override
  String get householdRoleMember => 'You are a member';

  @override
  String get householdMembers => 'Members';

  @override
  String get householdLoadingMembers => 'Loading members…';

  @override
  String get householdCouldNotLoadMembers =>
      'Could not load members. Pull down to retry.';

  @override
  String get householdYouSuffix => '(You)';

  @override
  String get householdRoleAdminLabel => 'Admin';

  @override
  String get householdRoleMemberLabel => 'Member';

  @override
  String get householdStorageSection => 'Storage';

  @override
  String get householdFileStorage => 'File Storage';

  @override
  String get householdFileStorageSubtitle =>
      'Attach files to tasks via Google Drive';

  @override
  String get householdInvitePartner => 'Invite Partner';

  @override
  String get householdInviteMessage =>
      'Send an invite to your partner\'s email. They\'ll be added to your household when they sign up or log in.';

  @override
  String get householdPartnerEmail => 'Partner\'s email';

  @override
  String get householdPartnerEmailHint => 'partner@example.com';

  @override
  String get householdInvite => 'Invite';

  @override
  String get householdInviteValidEmail => 'Please enter a valid email address.';

  @override
  String householdInviteSent(String email) {
    return 'Invite sent to $email! They\'ll see the household when they sign up.';
  }

  @override
  String get householdInviteFailed =>
      'Failed to send invite. Please try again.';

  @override
  String get driveTitle => 'File Storage';

  @override
  String get driveConnected => 'Google Drive Connected';

  @override
  String get driveConnect => 'Connect Google Drive';

  @override
  String get driveConnectedSubtitle =>
      'Household files are stored in your Google Drive.';

  @override
  String get driveConnectSubtitle =>
      'Store photos, documents, and other files alongside your household tasks.';

  @override
  String get driveHowItWorks => 'HOW IT WORKS';

  @override
  String get driveInfoFolder =>
      'A \"Pacelli\" folder is created in your Google Drive.';

  @override
  String get driveInfoAttach =>
      'Attach photos, PDFs, or spreadsheets to any task.';

  @override
  String get driveInfoMembers =>
      'Household members can view attached files via links.';

  @override
  String get driveInfoQuota =>
      'Files use YOUR Google Drive quota — no extra costs.';

  @override
  String get drivePrivacyNote =>
      'Pacelli only accesses files it creates. It cannot see or modify your other Drive files.';

  @override
  String get driveStorageActive => 'Drive storage is active';

  @override
  String get driveCanAttachNow => 'You can now attach files to tasks.';

  @override
  String get drivePacelliFolder => 'Pacelli folder in Google Drive';

  @override
  String get driveDisconnectTitle => 'Disconnect Drive?';

  @override
  String get driveDisconnectMessage =>
      'Existing file attachments will still be accessible via their links, but you won\'t be able to upload new files until you reconnect.';

  @override
  String get driveDisconnect => 'Disconnect';

  @override
  String get driveConnectButton => 'Connect Google Drive';

  @override
  String get driveDisconnectButton => 'Disconnect Google Drive';

  @override
  String get driveAdminOnly =>
      'Only the household admin can connect or disconnect Google Drive storage.';

  @override
  String get driveAccessNotGranted =>
      'Drive access was not granted. Please try again.';

  @override
  String get driveConnectedSuccess => 'Google Drive connected successfully!';

  @override
  String driveConnectFailed(String error) {
    return 'Failed to connect Google Drive: $error';
  }

  @override
  String get driveDisconnected => 'Google Drive disconnected.';

  @override
  String driveDisconnectFailed(String error) {
    return 'Failed to disconnect: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsHousehold => 'Household';

  @override
  String get settingsHouseholdSubtitle => 'Manage household & members';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsSubtitle => 'Reminders & alerts';

  @override
  String get settingsPrivacy => 'Privacy & Encryption';

  @override
  String get settingsPrivacySubtitle => 'How your data is protected';

  @override
  String get settingsDataStorage => 'Data Storage';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSubtitle => 'Theme & display';

  @override
  String get settingsAbout => 'About Pacelli';

  @override
  String get settingsAboutVersion => 'Version 1.0.0';

  @override
  String get settingsSignOut => 'Sign Out';

  @override
  String get settingsSignOutFailed => 'Failed to log out. Please try again.';

  @override
  String settingsComingSoon(String feature) {
    return '$feature settings are coming in a future update. Stay tuned!';
  }

  @override
  String get settingsAboutDescription =>
      'Pacelli helps your household stay organised — tasks, plans, checklists, and more, all in one place.';

  @override
  String get settingsDataStorageTitle => 'Data Storage';

  @override
  String get settingsCurrentBackend => 'Current backend:';

  @override
  String get settingsBackendLocal => 'On This Device (SQLite)';

  @override
  String get settingsBackendCloud => 'Cloud Sync (Firebase)';

  @override
  String get settingsEndToEndEncrypted => 'End-to-end encrypted';

  @override
  String get settingsSwitchBackend =>
      'To switch backends, tap \"Change\" below. Note: existing data will not be migrated automatically.';

  @override
  String get settingsDangerZone => 'DANGER ZONE';

  @override
  String get settingsBurnAllData => 'Burn All My Data';

  @override
  String get settingsBurnExplanation =>
      'Permanently delete all your data, saved settings, and sign out. This cannot be undone.';

  @override
  String get settingsBurnTitle => 'Destroy All Data?';

  @override
  String get settingsBurnWillDelete => 'This will permanently delete:';

  @override
  String get settingsBurnTasks => 'All tasks, plans, and checklists';

  @override
  String get settingsBurnCategories => 'All categories and settings';

  @override
  String get settingsBurnLocalDb => 'Local database (if used)';

  @override
  String get settingsBurnCloudData => 'Cloud data (if using Cloud Sync)';

  @override
  String get settingsBurnKeys => 'Encryption keys and saved preferences';

  @override
  String get settingsBurnCredentials =>
      'Your username & password (full sign-out)';

  @override
  String get settingsBurnSession =>
      'Your session — you\'ll need to log in again';

  @override
  String get settingsBurnIrreversible =>
      'This action is irreversible. There is no way to recover your data after this.';

  @override
  String get settingsBurnEverything => 'Burn Everything';

  @override
  String get privacyTitle => 'Privacy & Encryption';

  @override
  String get privacyE2ETitle => 'End-to-End Encrypted';

  @override
  String get privacyE2ESubtitle =>
      'AES-256 encryption — the same standard used by banks and governments.';

  @override
  String get privacyHowProtected => 'How your data is protected';

  @override
  String get privacyAllContent =>
      'All your personal content — task names, descriptions, plan titles, checklist items, your household name — is end-to-end encrypted before it leaves your device.';

  @override
  String get privacyOnlyYou =>
      'Only you and your household members can read your data. Not even the app developers can see it.';

  @override
  String get privacyWhatEncrypted => 'What is encrypted';

  @override
  String get privacyTaskTitles => 'Task titles and descriptions';

  @override
  String get privacySubtaskTitles => 'Subtask titles';

  @override
  String get privacyChecklistTitles => 'Checklist and checklist item titles';

  @override
  String get privacyPlanTitles =>
      'Plan titles, entry titles, labels, and descriptions';

  @override
  String get privacyCategoryNames => 'Category names';

  @override
  String get privacyHouseholdName => 'Household name';

  @override
  String get privacyDisplayName => 'Your display name';

  @override
  String get privacyAttachmentNames => 'File attachment names and descriptions';

  @override
  String get privacyAttachmentMetadata =>
      'Attachment metadata (file type, links, thumbnails)';

  @override
  String get privacyWhatNotEncrypted => 'What is not encrypted';

  @override
  String get privacyTaskStatus => 'Task status (pending, completed, etc.)';

  @override
  String get privacyPriorityLevels =>
      'Priority levels (low, medium, high, urgent)';

  @override
  String get privacyDueDates => 'Due dates and timestamps';

  @override
  String get privacyCheckedStatus => 'Whether items are checked or completed';

  @override
  String get privacySortOrder => 'Sort order and display settings';

  @override
  String get privacyCategoryIcons => 'Category icons and colours';

  @override
  String get privacyFileAttachments => 'File attachments (Google Drive)';

  @override
  String get privacyDriveExplanation =>
      'Files you attach to tasks are stored in the household owner\'s Google Drive, in a dedicated \"Pacelli\" folder. File names and descriptions are encrypted in Pacelli\'s database, but the actual files in Google Drive are protected by Google\'s own security — not Pacelli\'s E2E encryption.';

  @override
  String get privacyDriveAccess =>
      'Household members access files via shareable view-only links. The files are stored using the owner\'s Google Drive storage quota — no extra costs for the app.';

  @override
  String get privacyWhyNotEncrypted => 'Why some fields aren\'t encrypted';

  @override
  String get privacyWhyExplanation =>
      'These structural fields are needed for the app to filter, sort, and organise your data on the server. They don\'t contain personal information — they\'re labels like \"completed\" or \"high priority\", not your actual content.';

  @override
  String get privacyYourControl => 'Your data, your control';

  @override
  String get privacyDeleteAll =>
      'You can delete ALL your data at any time using \"Burn All My Data\" in Settings. When you delete your data, the encrypted content is permanently removed from our servers.';

  @override
  String get privacyKeyGeneration =>
      'Your encryption key is generated on your device and never stored in readable form on the server. Each household member receives their own encrypted copy of the shared key.';

  @override
  String get storageWhereDataLive => 'Where should your data live?';

  @override
  String get storageSubtitle =>
      'Your tasks, plans, and checklists are yours. Choose where to keep them.';

  @override
  String get storageOnDevice => 'On This Device';

  @override
  String get storageOnDeviceDescription =>
      'Data stays on your phone. No cloud, no sync, full privacy.';

  @override
  String get storageCloudSync => 'Cloud Sync';

  @override
  String get storageCloudSyncDescription =>
      'Multi-device sync in real time. All your content is end-to-end encrypted.';

  @override
  String get storageRecommended => 'Recommended';

  @override
  String get storagePrivacyNote =>
      'Cloud Sync uses AES-256 end-to-end encryption. Your personal content (task names, descriptions, checklist items) is encrypted on your device before it ever leaves. Not even we can read it.';

  @override
  String storageFailedLocal(String error) {
    return 'Failed to set up local storage: $error';
  }

  @override
  String storageFailedCloud(String error) {
    return 'Failed to set up cloud sync: $error';
  }

  @override
  String get errorDefault => 'Something went wrong.\nPlease try again.';

  @override
  String get taskRecurrenceDaily => 'Daily';

  @override
  String get taskRecurrenceWeekly => 'Weekly';

  @override
  String get taskRecurrenceBiweekly => 'Every 2 weeks';

  @override
  String get taskRecurrenceMonthly => 'Monthly';

  @override
  String taskSubtaskProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String get taskNew => 'New';

  @override
  String get commonNew => 'New';

  @override
  String get commonOK => 'OK';

  @override
  String get taskAddSubtask => 'Add a subtask...';

  @override
  String get taskDescription => 'Description (optional)';

  @override
  String get taskLabelAssignTo => 'Assign to';

  @override
  String get taskLabelPriority => 'Priority';

  @override
  String get taskLabelRepeat => 'Repeat';

  @override
  String get taskRecurrenceNone => 'Never';

  @override
  String get taskUnassigned => 'Unassigned';

  @override
  String get tasksFailedToLoadHousehold => 'Failed to load household';

  @override
  String get tasksLoadingHousehold => 'Loading household…';

  @override
  String get navHome => 'Home';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navSettings => 'Settings';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNone => 'None';

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceEveryTwoWeeks => 'Every 2 weeks';

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get recurrenceNever => 'Never';

  @override
  String calendarTasksSectionTitle(String dayLabel, int count) {
    return 'Tasks · $dayLabel · $count';
  }

  @override
  String get calendarNoTasksOnDay => 'No tasks on this day';

  @override
  String calendarPlansSectionTitle(int count) {
    return 'Plans · $count';
  }

  @override
  String get calendarNoDraftPlans => 'No draft plans';

  @override
  String calendarPlanEntries(int count) {
    return '$count entries';
  }

  @override
  String calendarChecklistItems(int count) {
    return '$count checklist items';
  }

  @override
  String get settingsBurnDriveWarning =>
      'Heads up — this won\'t delete your Pacelli folder in Google Drive or any files on your device. You\'ll need to remove those manually if you\'d like.';

  @override
  String get settingsBurnDriveWarningShort =>
      'Files in Google Drive or local storage must be deleted manually.';

  @override
  String get burnStatusBurning => 'Burning your data...';

  @override
  String get burnStatusDestroying => 'Destroying your data...';

  @override
  String get burnStatusClearingLocal => 'Clearing local storage...';

  @override
  String get burnStatusClearingKeys => 'Clearing encryption keys...';

  @override
  String get burnStatusSigningOut => 'Signing out...';

  @override
  String get burnStatusRemovingSettings => 'Removing saved settings...';

  @override
  String get burnStatusComplete => 'All data destroyed.';

  @override
  String get burnStatusError => 'Something went wrong. Please try again.';

  @override
  String get burnPasswordTitle => 'Confirm Account Deletion';

  @override
  String get burnPasswordMessage =>
      'To permanently delete your account and all data, please enter your password.';

  @override
  String get burnPasswordHint => 'Password';

  @override
  String get burnPasswordConfirm => 'Delete Everything';

  @override
  String get burnPasswordError => 'Incorrect password. Please try again.';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceThemeMode => 'Theme mode';

  @override
  String get appearanceThemeModeSubtitle =>
      'Choose light, dark, or follow your device settings';

  @override
  String get appearanceModeSystem => 'Auto';

  @override
  String get appearanceModeLight => 'Light';

  @override
  String get appearanceModeDark => 'Dark';

  @override
  String get appearanceColorScheme => 'Colour scheme';

  @override
  String get appearanceColorSchemeSubtitle => 'Pick a palette that suits you';

  @override
  String get appearanceSchemePacelli => 'Pacelli';

  @override
  String get appearanceSchemePacelliDesc => 'Sage green & terracotta';

  @override
  String get appearanceSchemeClaude => 'Claude';

  @override
  String get appearanceSchemeClaudeDesc => 'Warm purple & coral';

  @override
  String get appearanceSchemeGemini => 'Gemini';

  @override
  String get appearanceSchemeGeminiDesc => 'Ocean blue & coral';

  @override
  String attachCount(int count) {
    return 'Attachments ($count)';
  }

  @override
  String get attachInvalidLink => 'Invalid link.';

  @override
  String get attachCouldNotOpen => 'Could not open file.';

  @override
  String get attachRemoveTooltip => 'Remove attachment';

  @override
  String get planAttachFile => 'Attach a file';

  @override
  String get planRemoveAttachmentTitle => 'Remove attachment?';

  @override
  String planRemoveAttachmentMessage(String fileName) {
    return 'Remove \"$fileName\" from this entry? The file will remain in Google Drive.';
  }

  @override
  String planAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return '$count $_temp0';
  }

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifEnable => 'Enable notifications';

  @override
  String get notifEnableSubtitle => 'Get reminders when tasks are due';

  @override
  String get notifTimingTitle => 'Reminder timing';

  @override
  String get notifTimingSubtitle =>
      'When should we remind you about due tasks?';

  @override
  String get notifTimingAtDue => 'At due time';

  @override
  String get notifTimingAtDueDesc => 'Notify exactly when the task is due';

  @override
  String get notifTimingOneHour => '1 hour before';

  @override
  String get notifTimingOneHourDesc => 'Get a heads-up an hour early';

  @override
  String get notifTimingOneDay => '1 day before';

  @override
  String get notifTimingOneDayDesc => 'Remind at 9 AM the day before';

  @override
  String get notifInfoNote =>
      'Notifications are delivered locally on this device. They work even when the app is closed.';

  @override
  String get settingsImportExport => 'Import / Export';

  @override
  String get settingsImportExportSubtitle => 'Backup & restore your data';

  @override
  String get ieTitle => 'Import / Export';

  @override
  String get ieExportSection => 'EXPORT';

  @override
  String get ieExportJson => 'Export as JSON';

  @override
  String get ieExportJsonDesc =>
      'Full backup of tasks, checklists, plans, and inventory';

  @override
  String get ieExportCsv => 'Export tasks as CSV';

  @override
  String get ieExportCsvDesc => 'Spreadsheet-friendly list of tasks only';

  @override
  String get ieExportSuccess => 'Export saved successfully!';

  @override
  String ieExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String ieLastExport(String date) {
    return 'Last export: $date';
  }

  @override
  String get ieImportSection => 'IMPORT';

  @override
  String get ieImportButton => 'Import from backup';

  @override
  String get ieImportDesc => 'Restore data from a Pacelli JSON backup file';

  @override
  String get ieImportReading => 'Reading file...';

  @override
  String ieImportInvalid(String error) {
    return 'Invalid backup file: $error';
  }

  @override
  String get ieImportConfirmTitle => 'Import data?';

  @override
  String get ieImportConfirmMessage =>
      'This will add the backed-up data to your current household. Existing data will not be deleted.';

  @override
  String ieImportSuccess(int created, int skipped) {
    return 'Import complete! $created items created, $skipped skipped.';
  }

  @override
  String ieImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get ieImportErrorsTitle => 'Import Warnings';

  @override
  String ieImportErrorsCount(int count) {
    return '$count items could not be imported';
  }

  @override
  String get ieInfoNote =>
      'Exported files are saved in plaintext. If your data is encrypted in the cloud, it will be decrypted for the export.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search tasks, checklists, plans...';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchFilterTasks => 'Tasks';

  @override
  String get searchFilterChecklists => 'Checklists';

  @override
  String get searchFilterPlans => 'Plans';

  @override
  String get searchFilterAttachments => 'Attachments';

  @override
  String get searchLoading => 'Searching...';

  @override
  String get searchEmptyState => 'Start typing to search your household';

  @override
  String get searchResultTask => 'Task';

  @override
  String get searchResultChecklist => 'Checklist';

  @override
  String get searchResultPlan => 'Plan';

  @override
  String get searchResultAttachment => 'Attachment';

  @override
  String get searchResultInventory => 'Inventory';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventoryEmpty =>
      'Your inventory is empty — tap + to add your first item';

  @override
  String inventoryItemCount(int count) {
    return '$count items';
  }

  @override
  String get inventoryLowStock => 'Low stock';

  @override
  String get inventoryExpiringSoon => 'Expiring soon';

  @override
  String get inventoryAddItem => 'Add Item';

  @override
  String get inventoryEditItem => 'Edit Item';

  @override
  String get inventoryItemName => 'Item name';

  @override
  String get inventoryItemNameHint => 'e.g. Olive oil, Paper towels';

  @override
  String get inventoryDescription => 'Description';

  @override
  String get inventoryCategory => 'Category';

  @override
  String get inventoryLocation => 'Location';

  @override
  String get inventoryQuantity => 'Quantity';

  @override
  String get inventoryUnit => 'Unit';

  @override
  String get inventoryUnitPieces => 'pieces';

  @override
  String get inventoryUnitKg => 'kg';

  @override
  String get inventoryUnitLitres => 'litres';

  @override
  String get inventoryUnitBags => 'bags';

  @override
  String get inventoryUnitBoxes => 'boxes';

  @override
  String get inventoryLowStockThreshold => 'Low stock threshold';

  @override
  String get inventoryExpiryDate => 'Expiry date';

  @override
  String get inventoryPurchaseDate => 'Purchase date';

  @override
  String get inventoryNotes => 'Notes';

  @override
  String get inventoryBarcode => 'Barcode';

  @override
  String get inventoryBarcodeNone => 'No barcode';

  @override
  String get inventoryBarcodeReal => 'Product barcode';

  @override
  String get inventoryBarcodeVirtual => 'Virtual barcode';

  @override
  String get inventorySave => 'Save item';

  @override
  String get inventoryDelete => 'Delete item';

  @override
  String get inventoryDeleteConfirm =>
      'Are you sure you want to delete this item? This cannot be undone.';

  @override
  String get inventoryCategories => 'Categories';

  @override
  String get inventoryLocations => 'Locations';

  @override
  String get inventoryManageCategories => 'Manage Categories';

  @override
  String get inventoryManageLocations => 'Manage Locations';

  @override
  String get inventoryAddCategory => 'Add Category';

  @override
  String get inventoryAddLocation => 'Add Location';

  @override
  String get inventoryCategoryName => 'Category name';

  @override
  String get inventoryLocationName => 'Location name';

  @override
  String get inventoryCannotDeleteCategory =>
      'Cannot delete — items are using this category';

  @override
  String get inventoryCannotDeleteLocation =>
      'Cannot delete — items are using this location';

  @override
  String inventoryLogAdded(int count) {
    return 'Added $count';
  }

  @override
  String inventoryLogRemoved(int count) {
    return 'Used $count';
  }

  @override
  String inventoryLogAdjusted(int count) {
    return 'Adjusted to $count';
  }

  @override
  String get inventoryActivityLog => 'Activity Log';

  @override
  String get inventoryViewByCategory => 'By Category';

  @override
  String get inventoryViewByLocation => 'By Location';

  @override
  String get inventoryViewAll => 'All Items';

  @override
  String get inventoryDetails => 'Details';

  @override
  String get inventoryAttachments => 'Attachments';

  @override
  String inventoryCreatedBy(String name) {
    return 'Added by $name';
  }

  @override
  String inventoryItemsExpiring(int count) {
    return '$count expiring soon';
  }

  @override
  String inventoryItemsLowStock(int count) {
    return '$count low stock';
  }

  @override
  String get inventoryNoExpiry => 'No expiry date';

  @override
  String inventoryExpiresIn(int days) {
    return 'Expires in $days days';
  }

  @override
  String get inventoryExpired => 'Expired';

  @override
  String get inventoryExpiresToday => 'Expires today';

  @override
  String get inventoryDiscardTitle => 'Discard changes?';

  @override
  String get inventoryDiscardMessage =>
      'You have unsaved changes. Are you sure you want to go back?';

  @override
  String get inventoryKeepEditing => 'Keep editing';

  @override
  String get inventoryDiscard => 'Discard';

  @override
  String get inventoryCreated => 'Item added!';

  @override
  String get inventoryUpdated => 'Item updated!';

  @override
  String get inventoryDeleted => 'Item deleted';

  @override
  String get inventoryCouldNotLoad => 'Could not load inventory';

  @override
  String get inventoryUncategorised => 'Uncategorised';

  @override
  String get inventoryNoLocation => 'No location';

  @override
  String get inventoryIconLabel => 'Icon';

  @override
  String get inventoryColorLabel => 'Colour';

  @override
  String get inventoryCategoryCreated => 'Category created';

  @override
  String get inventoryLocationCreated => 'Location created';

  @override
  String get inventoryCategoryDeleted => 'Category deleted';

  @override
  String get inventoryLocationDeleted => 'Location deleted';

  @override
  String get inventoryCouldNotDelete => 'Could not delete';

  @override
  String get inventoryScanBarcode => 'Scan Barcode';

  @override
  String get inventoryScanPrompt => 'Point the camera at a barcode or QR code';

  @override
  String get inventoryScanNotFound => 'No item found with this barcode';

  @override
  String inventoryScanFoundItem(String name) {
    return 'Found: $name';
  }

  @override
  String get inventoryBarcodeTypeLabel => 'Barcode type';

  @override
  String get inventoryBarcodeTypeNone => 'No barcode';

  @override
  String get inventoryBarcodeTypeReal => 'Scan product barcode';

  @override
  String get inventoryBarcodeTypeVirtual => 'Generate virtual QR';

  @override
  String get inventoryTapToScan => 'Tap to scan';

  @override
  String get inventoryVirtualBarcodeGenerated => 'Virtual QR generated';

  @override
  String get inventoryViewQrCode => 'View QR Code';

  @override
  String get inventoryQrCodeTitle => 'Virtual Barcode';

  @override
  String get inventoryQrCodeSubtitle => 'Scan this QR code to find this item';

  @override
  String get inventoryBatchCreate => 'Batch Create';

  @override
  String get inventoryBatchTitle => 'Batch Create Items';

  @override
  String get inventoryBatchPortions => 'Number of portions';

  @override
  String get inventoryBatchPortionsHint =>
      'How many items to create from this one';

  @override
  String inventoryBatchNamePattern(String name, int index, int total) {
    return '$name ($index/$total)';
  }

  @override
  String inventoryBatchCreated(int count) {
    return '$count items created!';
  }

  @override
  String get inventoryCameraPermissionDenied =>
      'Camera permission is required to scan barcodes';

  @override
  String inventoryExpiringNotification(String name) {
    return '$name is expiring soon';
  }

  @override
  String inventoryLowStockNotification(String name, int count) {
    return '$name is running low ($count remaining)';
  }

  @override
  String get inventoryCreateRestockTask => 'Create restock task?';

  @override
  String inventoryRestockTaskTitle(String name) {
    return 'Restock: $name';
  }

  @override
  String inventoryExpiryTaskTitle(String name) {
    return 'Use before expiry: $name';
  }

  @override
  String get inventoryRestockTaskCreated => 'Restock task created';

  @override
  String get inventoryExpiryTaskCreated => 'Expiry task created';

  @override
  String get inventoryAutoCreateTask => 'Create task';

  @override
  String get inventoryNotificationSent => 'Notification sent';

  @override
  String get inventoryItemExpired => 'Item expired';

  @override
  String get inventoryCalendarExpiring => 'Expiring Items';

  @override
  String get inventoryLowStockAlert => 'Low stock! Create a shopping task?';

  @override
  String inventoryThresholdCrossed(String name, int threshold) {
    return '$name dropped below $threshold';
  }

  @override
  String get inventoryExpiryCalendarDot => 'Item expiring';

  @override
  String get inventoryActivityLogEmpty => 'No activity yet';

  @override
  String get inventoryDefaultLabel => 'Default';

  @override
  String get commonErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get homeInventorySnapshot => 'Inventory';

  @override
  String get homeInvTotal => 'Total';

  @override
  String homeInventorySummary(int count, int alert) {
    return '$count items · $alert alert';
  }

  @override
  String homeInventorySummaryPlural(int count, int alert) {
    return '$count items · $alert alerts';
  }
}
