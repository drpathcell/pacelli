import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('it')
  ];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get commonChange;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get commonTomorrow;

  /// No description provided for @commonUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get commonUnassigned;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get commonUntitled;

  /// No description provided for @commonShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get commonShared;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonError(String error);

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authSignInToHousehold.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your household'**
  String get authSignInToHousehold;

  /// No description provided for @authOrSignInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'or sign in with email'**
  String get authOrSignInWithEmail;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authEnterEmail;

  /// No description provided for @authEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get authEnterValidEmail;

  /// No description provided for @authEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authEnterPassword;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authEnterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your email first'**
  String get authEnterEmailFirst;

  /// No description provided for @authPasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent! Check your inbox.'**
  String get authPasswordResetSent;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get authGoogleSignInFailed;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your email and password.'**
  String get authLoginFailed;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authStartOrganising.
  ///
  /// In en, this message translates to:
  /// **'Start organising your home with love'**
  String get authStartOrganising;

  /// No description provided for @authOrSignUpWithEmail.
  ///
  /// In en, this message translates to:
  /// **'or sign up with email'**
  String get authOrSignUpWithEmail;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authEnterName;

  /// No description provided for @authEnterAPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get authEnterAPassword;

  /// No description provided for @authPasswordMin8.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordMin8;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccountButton;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authAlreadyHaveAccount;

  /// No description provided for @authAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created! Welcome to Pacelli.'**
  String get authAccountCreated;

  /// No description provided for @authSignupFailed.
  ///
  /// In en, this message translates to:
  /// **'Signup failed. Please try again.'**
  String get authSignupFailed;

  /// No description provided for @authAppName.
  ///
  /// In en, this message translates to:
  /// **'Pacelli'**
  String get authAppName;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'A peaceful home, organised with love.'**
  String get authTagline;

  /// No description provided for @homeHelloGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {userName}'**
  String homeHelloGreeting(String userName);

  /// No description provided for @homeLoadingHousehold.
  ///
  /// In en, this message translates to:
  /// **'Loading household…'**
  String get homeLoadingHousehold;

  /// No description provided for @homeSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get homeSomethingWentWrong;

  /// No description provided for @homeTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get homeTryAgain;

  /// No description provided for @homeWelcomeToPacelli.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pacelli!'**
  String get homeWelcomeToPacelli;

  /// No description provided for @homeWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your household tasks will appear here.\nLet\'s start by creating your household.'**
  String get homeWelcomeSubtitle;

  /// No description provided for @homeCreateHousehold.
  ///
  /// In en, this message translates to:
  /// **'Create Household'**
  String get homeCreateHousehold;

  /// No description provided for @homeHouseholdSetUp.
  ///
  /// In en, this message translates to:
  /// **'Your household is set up!'**
  String get homeHouseholdSetUp;

  /// No description provided for @homeTodaysOverview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Overview'**
  String get homeTodaysOverview;

  /// No description provided for @homeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get homeCompleted;

  /// No description provided for @homePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get homePending;

  /// No description provided for @homeOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get homeOverdue;

  /// No description provided for @homeRecentTasks.
  ///
  /// In en, this message translates to:
  /// **'Recent Tasks'**
  String get homeRecentTasks;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @homeFailedToLoadTasks.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tasks'**
  String get homeFailedToLoadTasks;

  /// No description provided for @homeNoTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet — they\'ll show up here once you create some!'**
  String get homeNoTasksYet;

  /// No description provided for @homeCreateTask.
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get homeCreateTask;

  /// No description provided for @homeCouldNotCompleteTask.
  ///
  /// In en, this message translates to:
  /// **'Could not complete task'**
  String get homeCouldNotCompleteTask;

  /// No description provided for @homeDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get homeDueToday;

  /// No description provided for @homeDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get homeDueTomorrow;

  /// No description provided for @homeDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String homeDueDate(String date);

  /// No description provided for @homeMyHousehold.
  ///
  /// In en, this message translates to:
  /// **'My Household'**
  String get homeMyHousehold;

  /// No description provided for @taskNewTask.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get taskNewTask;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskTitle;

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Clean the kitchen'**
  String get taskTitleHint;

  /// No description provided for @taskEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get taskEnterTitle;

  /// No description provided for @taskDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get taskDescriptionOptional;

  /// No description provided for @taskDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add any details...'**
  String get taskDescriptionHint;

  /// No description provided for @taskCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get taskCategory;

  /// No description provided for @taskFailedToLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Failed to load categories'**
  String get taskFailedToLoadCategories;

  /// No description provided for @taskNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get taskNewCategory;

  /// No description provided for @taskCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get taskCategoryName;

  /// No description provided for @taskPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskPriority;

  /// No description provided for @taskPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get taskPriorityLow;

  /// No description provided for @taskPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get taskPriorityMedium;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get taskPriorityHigh;

  /// No description provided for @taskPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get taskPriorityUrgent;

  /// No description provided for @taskStartsToday.
  ///
  /// In en, this message translates to:
  /// **'Starts: Today'**
  String get taskStartsToday;

  /// No description provided for @taskStartsDate.
  ///
  /// In en, this message translates to:
  /// **'Starts: {date}'**
  String taskStartsDate(String date);

  /// No description provided for @taskNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get taskNoDueDate;

  /// No description provided for @taskDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String taskDueDate(String date);

  /// No description provided for @taskAssignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get taskAssignTo;

  /// No description provided for @taskSharedTask.
  ///
  /// In en, this message translates to:
  /// **'Shared task (both of you)'**
  String get taskSharedTask;

  /// No description provided for @taskSharedTaskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anyone can complete it'**
  String get taskSharedTaskSubtitle;

  /// No description provided for @taskFailedToLoadMembers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load members'**
  String get taskFailedToLoadMembers;

  /// No description provided for @taskMeSuffix.
  ///
  /// In en, this message translates to:
  /// **'(me)'**
  String get taskMeSuffix;

  /// No description provided for @taskRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get taskRepeat;

  /// No description provided for @taskRepeatNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get taskRepeatNever;

  /// No description provided for @taskRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get taskRepeatDaily;

  /// No description provided for @taskRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get taskRepeatWeekly;

  /// No description provided for @taskRepeatBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get taskRepeatBiweekly;

  /// No description provided for @taskRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get taskRepeatMonthly;

  /// No description provided for @taskSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get taskSubtasks;

  /// No description provided for @taskAddSubtaskHint.
  ///
  /// In en, this message translates to:
  /// **'Add a subtask...'**
  String get taskAddSubtaskHint;

  /// No description provided for @taskDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard task?'**
  String get taskDiscardTitle;

  /// No description provided for @taskDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to go back?'**
  String get taskDiscardMessage;

  /// No description provided for @taskKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get taskKeepEditing;

  /// No description provided for @taskDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get taskDiscard;

  /// No description provided for @taskCreated.
  ///
  /// In en, this message translates to:
  /// **'Task created!'**
  String get taskCreated;

  /// No description provided for @taskEditTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get taskEditTask;

  /// No description provided for @taskLoadingTask.
  ///
  /// In en, this message translates to:
  /// **'Loading task…'**
  String get taskLoadingTask;

  /// No description provided for @taskFailedToLoadTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to load task'**
  String get taskFailedToLoadTask;

  /// No description provided for @taskNoHousehold.
  ///
  /// In en, this message translates to:
  /// **'Task has no household'**
  String get taskNoHousehold;

  /// No description provided for @taskUpdated.
  ///
  /// In en, this message translates to:
  /// **'Task updated!'**
  String get taskUpdated;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get taskDetails;

  /// No description provided for @taskLoadingDetails.
  ///
  /// In en, this message translates to:
  /// **'Loading task details…'**
  String get taskLoadingDetails;

  /// No description provided for @taskCouldNotLoadDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not load task details.'**
  String get taskCouldNotLoadDetails;

  /// No description provided for @taskDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get taskDeleteTitle;

  /// No description provided for @taskDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this task and all its subtasks.'**
  String get taskDeleteMessage;

  /// No description provided for @taskStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskStatusCompleted;

  /// No description provided for @taskReopenTask.
  ///
  /// In en, this message translates to:
  /// **'Reopen Task'**
  String get taskReopenTask;

  /// No description provided for @taskMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get taskMarkComplete;

  /// No description provided for @taskLabelCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get taskLabelCategory;

  /// No description provided for @taskLabelStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get taskLabelStarts;

  /// No description provided for @taskLabelDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get taskLabelDue;

  /// No description provided for @taskLabelAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get taskLabelAssignedTo;

  /// No description provided for @taskSharedBoth.
  ///
  /// In en, this message translates to:
  /// **'Shared (both)'**
  String get taskSharedBoth;

  /// No description provided for @taskLabelRepeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get taskLabelRepeats;

  /// No description provided for @taskLabelCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get taskLabelCreatedBy;

  /// No description provided for @taskRemoveAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment?'**
  String get taskRemoveAttachmentTitle;

  /// No description provided for @taskRemoveAttachmentMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{fileName}\" from this task? The file will remain in Google Drive.'**
  String taskRemoveAttachmentMessage(String fileName);

  /// No description provided for @taskRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get taskRemove;

  /// No description provided for @taskAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get taskAttachFile;

  /// No description provided for @taskAttachAfterSave.
  ///
  /// In en, this message translates to:
  /// **'You can attach files after saving the task.'**
  String get taskAttachAfterSave;

  /// No description provided for @taskPendingAttachments.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{file} other{files}} ready to upload'**
  String taskPendingAttachments(int count);

  /// No description provided for @taskUploadingAttachments.
  ///
  /// In en, this message translates to:
  /// **'Uploading attachments…'**
  String get taskUploadingAttachments;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// No description provided for @tasksCreateHouseholdFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a household first'**
  String get tasksCreateHouseholdFirst;

  /// No description provided for @tasksFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tasksFilterAll;

  /// No description provided for @tasksFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get tasksFilterPending;

  /// No description provided for @tasksFilterDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tasksFilterDone;

  /// No description provided for @tasksAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get tasksAllCategories;

  /// No description provided for @tasksMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tasksMore;

  /// No description provided for @tasksCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load tasks.'**
  String get tasksCouldNotLoad;

  /// No description provided for @tasksNoTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet.\nTap + to create one!'**
  String get tasksNoTasksYet;

  /// No description provided for @tasksAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get tasksAllCaughtUp;

  /// No description provided for @tasksNoCompletedYet.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks yet.'**
  String get tasksNoCompletedYet;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarActivePlans.
  ///
  /// In en, this message translates to:
  /// **'Active plans'**
  String get calendarActivePlans;

  /// No description provided for @calendarNewPlan.
  ///
  /// In en, this message translates to:
  /// **'New Plan'**
  String get calendarNewPlan;

  /// No description provided for @calendarLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading calendar…'**
  String get calendarLoading;

  /// No description provided for @calendarCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load calendar.'**
  String get calendarCouldNotLoad;

  /// No description provided for @calendarNoHousehold.
  ///
  /// In en, this message translates to:
  /// **'No household yet'**
  String get calendarNoHousehold;

  /// No description provided for @calendarLoadingTasks.
  ///
  /// In en, this message translates to:
  /// **'Loading tasks…'**
  String get calendarLoadingTasks;

  /// No description provided for @calendarCouldNotLoadTasks.
  ///
  /// In en, this message translates to:
  /// **'Could not load tasks.'**
  String get calendarCouldNotLoadTasks;

  /// No description provided for @attachTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach a File'**
  String get attachTitle;

  /// No description provided for @attachPickFile.
  ///
  /// In en, this message translates to:
  /// **'Pick a file'**
  String get attachPickFile;

  /// No description provided for @attachPickFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PDF, document, spreadsheet, or any file'**
  String get attachPickFileSubtitle;

  /// No description provided for @attachTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get attachTakePhoto;

  /// No description provided for @attachTakePhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the camera'**
  String get attachTakePhotoSubtitle;

  /// No description provided for @attachPickGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get attachPickGallery;

  /// No description provided for @attachPickGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an existing photo'**
  String get attachPickGallerySubtitle;

  /// No description provided for @attachUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading file…'**
  String get attachUploading;

  /// No description provided for @attachDriveNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Google Drive is not set up for this household. Ask the household admin to connect it.'**
  String get attachDriveNotSetUp;

  /// No description provided for @attachDriveDisabled.
  ///
  /// In en, this message translates to:
  /// **'Google Drive storage is currently disabled.'**
  String get attachDriveDisabled;

  /// No description provided for @attachSuccess.
  ///
  /// In en, this message translates to:
  /// **'File attached successfully!'**
  String get attachSuccess;

  /// No description provided for @attachUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String attachUploadFailed(String error);

  /// No description provided for @checklistNewChecklist.
  ///
  /// In en, this message translates to:
  /// **'New Checklist'**
  String get checklistNewChecklist;

  /// No description provided for @checklistHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Groceries, Travel Essentials'**
  String get checklistHint;

  /// No description provided for @checklistAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get checklistAddItem;

  /// No description provided for @checklistItemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get checklistItemName;

  /// No description provided for @checklistDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Checklist?'**
  String get checklistDeleteTitle;

  /// No description provided for @checklistDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete the checklist and all its items.'**
  String get checklistDeleteMessage;

  /// No description provided for @checklistCouldNotCreate.
  ///
  /// In en, this message translates to:
  /// **'Could not create checklist'**
  String get checklistCouldNotCreate;

  /// No description provided for @checklistCouldNotAdd.
  ///
  /// In en, this message translates to:
  /// **'Could not add item'**
  String get checklistCouldNotAdd;

  /// No description provided for @checklistCouldNotUpdate.
  ///
  /// In en, this message translates to:
  /// **'Could not update item'**
  String get checklistCouldNotUpdate;

  /// No description provided for @checklistCouldNotPush.
  ///
  /// In en, this message translates to:
  /// **'Could not push item as task'**
  String get checklistCouldNotPush;

  /// No description provided for @checklistCouldNotDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Could not delete item'**
  String get checklistCouldNotDeleteItem;

  /// No description provided for @checklistCouldNotDeleteList.
  ///
  /// In en, this message translates to:
  /// **'Could not delete checklist'**
  String get checklistCouldNotDeleteList;

  /// No description provided for @checklistAddedAsTask.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" added as task'**
  String checklistAddedAsTask(String title);

  /// No description provided for @checklistSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklists · {count}'**
  String checklistSectionTitle(int count);

  /// No description provided for @checklistNoChecklists.
  ///
  /// In en, this message translates to:
  /// **'No checklists yet'**
  String get checklistNoChecklists;

  /// No description provided for @checklistBadgePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get checklistBadgePlan;

  /// No description provided for @checklistBadgeList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get checklistBadgeList;

  /// No description provided for @checklistPushAsTask.
  ///
  /// In en, this message translates to:
  /// **'Push as Task'**
  String get checklistPushAsTask;

  /// No description provided for @checklistCountProgress.
  ///
  /// In en, this message translates to:
  /// **'{checked}/{total}'**
  String checklistCountProgress(int checked, int total);

  /// No description provided for @planNewPlan.
  ///
  /// In en, this message translates to:
  /// **'New Plan'**
  String get planNewPlan;

  /// No description provided for @planStartFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get planStartFromTemplate;

  /// No description provided for @planWeeklyDinnerPlanner.
  ///
  /// In en, this message translates to:
  /// **'Weekly Dinner Planner'**
  String get planWeeklyDinnerPlanner;

  /// No description provided for @planWeeklyDinnerDescription.
  ///
  /// In en, this message translates to:
  /// **'7 dinners for the week — one per day'**
  String get planWeeklyDinnerDescription;

  /// No description provided for @planOrStartFromScratch.
  ///
  /// In en, this message translates to:
  /// **'Or start from scratch'**
  String get planOrStartFromScratch;

  /// No description provided for @planTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan title'**
  String get planTitle;

  /// No description provided for @planTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Meal Prep Week, Holiday Trip'**
  String get planTitleHint;

  /// No description provided for @planGiveItAName.
  ///
  /// In en, this message translates to:
  /// **'Give it a name'**
  String get planGiveItAName;

  /// No description provided for @planTypeWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get planTypeWeek;

  /// No description provided for @planTypeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get planTypeMonth;

  /// No description provided for @planTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get planTypeCustom;

  /// No description provided for @planCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Create Plan'**
  String get planCreatePlan;

  /// No description provided for @planFailedToCreate.
  ///
  /// In en, this message translates to:
  /// **'Failed to create plan: {error}'**
  String planFailedToCreate(String error);

  /// No description provided for @planSelectDates.
  ///
  /// In en, this message translates to:
  /// **'Select start and end dates'**
  String get planSelectDates;

  /// No description provided for @planConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get planConfirm;

  /// No description provided for @planDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String planDaysCount(int count);

  /// No description provided for @planStartsDate.
  ///
  /// In en, this message translates to:
  /// **'Starts: {date}'**
  String planStartsDate(String date);

  /// No description provided for @planTemplateEntries.
  ///
  /// In en, this message translates to:
  /// **'{type} plan • {count} entries'**
  String planTemplateEntries(String type, int count);

  /// No description provided for @planLoadingPlan.
  ///
  /// In en, this message translates to:
  /// **'Loading plan…'**
  String get planLoadingPlan;

  /// No description provided for @planCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load plan.'**
  String get planCouldNotLoad;

  /// No description provided for @planInvalidMissingDates.
  ///
  /// In en, this message translates to:
  /// **'Invalid plan: missing dates'**
  String get planInvalidMissingDates;

  /// No description provided for @planInvalidUnreadableDates.
  ///
  /// In en, this message translates to:
  /// **'Invalid plan: unreadable dates'**
  String get planInvalidUnreadableDates;

  /// No description provided for @planSaveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as Template'**
  String get planSaveAsTemplate;

  /// No description provided for @planTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get planTemplateName;

  /// No description provided for @planFinalise.
  ///
  /// In en, this message translates to:
  /// **'Finalise'**
  String get planFinalise;

  /// No description provided for @planFinalisedChip.
  ///
  /// In en, this message translates to:
  /// **'Finalised'**
  String get planFinalisedChip;

  /// No description provided for @planTapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add meals, activities, or anything you\'re planning.'**
  String get planTapToAdd;

  /// No description provided for @planChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get planChecklist;

  /// No description provided for @planAddItemHint.
  ///
  /// In en, this message translates to:
  /// **'Add item...'**
  String get planAddItemHint;

  /// No description provided for @planNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Add things you need to buy or do.'**
  String get planNoItemsYet;

  /// No description provided for @planTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template \"{name}\" saved!'**
  String planTemplateSaved(String name);

  /// No description provided for @planFailedToSaveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Failed to save template: {error}'**
  String planFailedToSaveTemplate(String error);

  /// No description provided for @planFailedToAddItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to add item: {error}'**
  String planFailedToAddItem(String error);

  /// No description provided for @planFinalisePlan.
  ///
  /// In en, this message translates to:
  /// **'Finalise Plan'**
  String get planFinalisePlan;

  /// No description provided for @planLoadingEntries.
  ///
  /// In en, this message translates to:
  /// **'Loading plan entries…'**
  String get planLoadingEntries;

  /// No description provided for @planPushToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Push to Calendar?'**
  String get planPushToCalendar;

  /// No description provided for @planPushSummary.
  ///
  /// In en, this message translates to:
  /// **'{tasks} task(s) and {notes} note(s) will be created.\n\nSkipped entries won\'t be added to the calendar.'**
  String planPushSummary(int tasks, int notes);

  /// No description provided for @planPushToCalendarButton.
  ///
  /// In en, this message translates to:
  /// **'Push to Calendar'**
  String get planPushToCalendarButton;

  /// No description provided for @planFinalisedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Plan Finalised!'**
  String get planFinalisedSuccess;

  /// No description provided for @planEntriesPushed.
  ///
  /// In en, this message translates to:
  /// **'Your entries have been pushed to the calendar.'**
  String get planEntriesPushed;

  /// No description provided for @planViewCalendar.
  ///
  /// In en, this message translates to:
  /// **'View Calendar'**
  String get planViewCalendar;

  /// No description provided for @planFailedToFinalise.
  ///
  /// In en, this message translates to:
  /// **'Failed to finalise: {error}'**
  String planFailedToFinalise(String error);

  /// No description provided for @planNoEntriesToFinalise.
  ///
  /// In en, this message translates to:
  /// **'No entries to finalise.'**
  String get planNoEntriesToFinalise;

  /// No description provided for @planGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get planGoBack;

  /// No description provided for @planInfoBanner.
  ///
  /// In en, this message translates to:
  /// **'Choose what each entry becomes on your calendar. Tasks can be assigned and completed. Notes are lightweight reminders.'**
  String get planInfoBanner;

  /// No description provided for @planActionTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get planActionTask;

  /// No description provided for @planActionNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get planActionNote;

  /// No description provided for @planActionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get planActionSkip;

  /// No description provided for @planLoadingDay.
  ///
  /// In en, this message translates to:
  /// **'Loading day entries…'**
  String get planLoadingDay;

  /// No description provided for @planCouldNotLoadDay.
  ///
  /// In en, this message translates to:
  /// **'Could not load day entries.'**
  String get planCouldNotLoadDay;

  /// No description provided for @planFailedToAdd.
  ///
  /// In en, this message translates to:
  /// **'Failed to add: {error}'**
  String planFailedToAdd(String error);

  /// No description provided for @planFailedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String planFailedToDelete(String error);

  /// No description provided for @planNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New Label'**
  String get planNewLabel;

  /// No description provided for @planLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Dessert, Outing'**
  String get planLabelHint;

  /// No description provided for @planEditEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit Entry'**
  String get planEditEntry;

  /// No description provided for @planWhatsPlanned.
  ///
  /// In en, this message translates to:
  /// **'What\'s planned?'**
  String get planWhatsPlanned;

  /// No description provided for @planCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get planCustomLabel;

  /// No description provided for @planWhatsForLabel.
  ///
  /// In en, this message translates to:
  /// **'What\'s for {label}?'**
  String planWhatsForLabel(String label);

  /// No description provided for @planAddNeedsFor.
  ///
  /// In en, this message translates to:
  /// **'Add needs for \"{entry}\"'**
  String planAddNeedsFor(String entry);

  /// No description provided for @planNeedsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. pasta, mince, tomatoes'**
  String get planNeedsHint;

  /// No description provided for @planNeedsHelper.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas'**
  String get planNeedsHelper;

  /// No description provided for @planAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get planAddToList;

  /// No description provided for @planItemsAddedToChecklist.
  ///
  /// In en, this message translates to:
  /// **'{count} item(s) added to checklist'**
  String planItemsAddedToChecklist(int count);

  /// No description provided for @planFailedToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update: {error}'**
  String planFailedToUpdate(String error);

  /// No description provided for @planAddToChecklist.
  ///
  /// In en, this message translates to:
  /// **'Add to checklist'**
  String get planAddToChecklist;

  /// No description provided for @planEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get planEdit;

  /// No description provided for @planLabelDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get planLabelDinner;

  /// No description provided for @planLabelBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get planLabelBreakfast;

  /// No description provided for @planLabelLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get planLabelLunch;

  /// No description provided for @planLabelSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get planLabelSnack;

  /// No description provided for @planLabelActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get planLabelActivity;

  /// No description provided for @planLabelTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get planLabelTransport;

  /// No description provided for @planLabelAccommodation.
  ///
  /// In en, this message translates to:
  /// **'Accommodation'**
  String get planLabelAccommodation;

  /// No description provided for @householdCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Household'**
  String get householdCreateTitle;

  /// No description provided for @householdNameYour.
  ///
  /// In en, this message translates to:
  /// **'Name your household'**
  String get householdNameYour;

  /// No description provided for @householdNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is what you and your partner will see.\nYou can change it anytime.'**
  String get householdNameSubtitle;

  /// No description provided for @householdNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get householdNameLabel;

  /// No description provided for @householdNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Celis Home'**
  String get householdNameHint;

  /// No description provided for @householdEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name for your household'**
  String get householdEnterName;

  /// No description provided for @householdNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get householdNameMinLength;

  /// No description provided for @householdCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Household'**
  String get householdCreateButton;

  /// No description provided for @householdCreated.
  ///
  /// In en, this message translates to:
  /// **'Household created! Welcome home.'**
  String get householdCreated;

  /// No description provided for @householdCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create household. Please try again.'**
  String get householdCreateFailed;

  /// No description provided for @householdTitle.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get householdTitle;

  /// No description provided for @householdLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading household…'**
  String get householdLoading;

  /// No description provided for @householdCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load household.'**
  String get householdCouldNotLoad;

  /// No description provided for @householdNotFound.
  ///
  /// In en, this message translates to:
  /// **'No household found.'**
  String get householdNotFound;

  /// No description provided for @householdMyHousehold.
  ///
  /// In en, this message translates to:
  /// **'My Household'**
  String get householdMyHousehold;

  /// No description provided for @householdRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'You are the admin'**
  String get householdRoleAdmin;

  /// No description provided for @householdRoleMember.
  ///
  /// In en, this message translates to:
  /// **'You are a member'**
  String get householdRoleMember;

  /// No description provided for @householdMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get householdMembers;

  /// No description provided for @householdLoadingMembers.
  ///
  /// In en, this message translates to:
  /// **'Loading members…'**
  String get householdLoadingMembers;

  /// No description provided for @householdCouldNotLoadMembers.
  ///
  /// In en, this message translates to:
  /// **'Could not load members. Pull down to retry.'**
  String get householdCouldNotLoadMembers;

  /// No description provided for @householdYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'(You)'**
  String get householdYouSuffix;

  /// No description provided for @householdRoleAdminLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get householdRoleAdminLabel;

  /// No description provided for @householdRoleMemberLabel.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get householdRoleMemberLabel;

  /// No description provided for @householdStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get householdStorageSection;

  /// No description provided for @householdFileStorage.
  ///
  /// In en, this message translates to:
  /// **'File Storage'**
  String get householdFileStorage;

  /// No description provided for @householdFileStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attach files to tasks via Google Drive'**
  String get householdFileStorageSubtitle;

  /// No description provided for @householdInvitePartner.
  ///
  /// In en, this message translates to:
  /// **'Invite Partner'**
  String get householdInvitePartner;

  /// No description provided for @householdInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Send an invite to your partner\'s email. They\'ll be added to your household when they sign up or log in.'**
  String get householdInviteMessage;

  /// No description provided for @householdPartnerEmail.
  ///
  /// In en, this message translates to:
  /// **'Partner\'s email'**
  String get householdPartnerEmail;

  /// No description provided for @householdPartnerEmailHint.
  ///
  /// In en, this message translates to:
  /// **'partner@example.com'**
  String get householdPartnerEmailHint;

  /// No description provided for @householdInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get householdInvite;

  /// No description provided for @householdInviteValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get householdInviteValidEmail;

  /// No description provided for @householdInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent to {email}! They\'ll see the household when they sign up.'**
  String householdInviteSent(String email);

  /// No description provided for @householdInviteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send invite. Please try again.'**
  String get householdInviteFailed;

  /// No description provided for @driveTitle.
  ///
  /// In en, this message translates to:
  /// **'File Storage'**
  String get driveTitle;

  /// No description provided for @driveConnected.
  ///
  /// In en, this message translates to:
  /// **'Google Drive Connected'**
  String get driveConnected;

  /// No description provided for @driveConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive'**
  String get driveConnect;

  /// No description provided for @driveConnectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Household files are stored in your Google Drive.'**
  String get driveConnectedSubtitle;

  /// No description provided for @driveConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store photos, documents, and other files alongside your household tasks.'**
  String get driveConnectSubtitle;

  /// No description provided for @driveHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'HOW IT WORKS'**
  String get driveHowItWorks;

  /// No description provided for @driveInfoFolder.
  ///
  /// In en, this message translates to:
  /// **'A \"Pacelli\" folder is created in your Google Drive.'**
  String get driveInfoFolder;

  /// No description provided for @driveInfoAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach photos, PDFs, or spreadsheets to any task.'**
  String get driveInfoAttach;

  /// No description provided for @driveInfoMembers.
  ///
  /// In en, this message translates to:
  /// **'Household members can view attached files via links.'**
  String get driveInfoMembers;

  /// No description provided for @driveInfoQuota.
  ///
  /// In en, this message translates to:
  /// **'Files use YOUR Google Drive quota — no extra costs.'**
  String get driveInfoQuota;

  /// No description provided for @drivePrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Pacelli only accesses files it creates. It cannot see or modify your other Drive files.'**
  String get drivePrivacyNote;

  /// No description provided for @driveStorageActive.
  ///
  /// In en, this message translates to:
  /// **'Drive storage is active'**
  String get driveStorageActive;

  /// No description provided for @driveCanAttachNow.
  ///
  /// In en, this message translates to:
  /// **'You can now attach files to tasks.'**
  String get driveCanAttachNow;

  /// No description provided for @drivePacelliFolder.
  ///
  /// In en, this message translates to:
  /// **'Pacelli folder in Google Drive'**
  String get drivePacelliFolder;

  /// No description provided for @driveDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Drive?'**
  String get driveDisconnectTitle;

  /// No description provided for @driveDisconnectMessage.
  ///
  /// In en, this message translates to:
  /// **'Existing file attachments will still be accessible via their links, but you won\'t be able to upload new files until you reconnect.'**
  String get driveDisconnectMessage;

  /// No description provided for @driveDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get driveDisconnect;

  /// No description provided for @driveConnectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive'**
  String get driveConnectButton;

  /// No description provided for @driveDisconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Google Drive'**
  String get driveDisconnectButton;

  /// No description provided for @driveAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the household admin can connect or disconnect Google Drive storage.'**
  String get driveAdminOnly;

  /// No description provided for @driveAccessNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Drive access was not granted. Please try again.'**
  String get driveAccessNotGranted;

  /// No description provided for @driveConnectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Google Drive connected successfully!'**
  String get driveConnectedSuccess;

  /// No description provided for @driveConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect Google Drive: {error}'**
  String driveConnectFailed(String error);

  /// No description provided for @driveDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Google Drive disconnected.'**
  String get driveDisconnected;

  /// No description provided for @driveDisconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to disconnect: {error}'**
  String driveDisconnectFailed(String error);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get settingsHousehold;

  /// No description provided for @settingsHouseholdSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage household & members'**
  String get settingsHouseholdSubtitle;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders & alerts'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Encryption'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your data is protected'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsDataStorage.
  ///
  /// In en, this message translates to:
  /// **'Data Storage'**
  String get settingsDataStorage;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme & display'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Pacelli'**
  String get settingsAbout;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get settingsAboutVersion;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to log out. Please try again.'**
  String get settingsSignOutFailed;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} settings are coming in a future update. Stay tuned!'**
  String settingsComingSoon(String feature);

  /// No description provided for @settingsAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Pacelli helps your household stay organised — tasks, plans, checklists, and more, all in one place.'**
  String get settingsAboutDescription;

  /// No description provided for @settingsDataStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Storage'**
  String get settingsDataStorageTitle;

  /// No description provided for @settingsCurrentBackend.
  ///
  /// In en, this message translates to:
  /// **'Current backend:'**
  String get settingsCurrentBackend;

  /// No description provided for @settingsBackendLocal.
  ///
  /// In en, this message translates to:
  /// **'On This Device (SQLite)'**
  String get settingsBackendLocal;

  /// No description provided for @settingsBackendCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync (Firebase)'**
  String get settingsBackendCloud;

  /// No description provided for @settingsEndToEndEncrypted.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get settingsEndToEndEncrypted;

  /// No description provided for @settingsSwitchBackend.
  ///
  /// In en, this message translates to:
  /// **'To switch backends, tap \"Change\" below. Note: existing data will not be migrated automatically.'**
  String get settingsSwitchBackend;

  /// No description provided for @settingsDangerZone.
  ///
  /// In en, this message translates to:
  /// **'DANGER ZONE'**
  String get settingsDangerZone;

  /// No description provided for @settingsBurnAllData.
  ///
  /// In en, this message translates to:
  /// **'Burn All My Data'**
  String get settingsBurnAllData;

  /// No description provided for @settingsBurnExplanation.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all your data, saved settings, and sign out. This cannot be undone.'**
  String get settingsBurnExplanation;

  /// No description provided for @settingsBurnTitle.
  ///
  /// In en, this message translates to:
  /// **'Destroy All Data?'**
  String get settingsBurnTitle;

  /// No description provided for @settingsBurnWillDelete.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete:'**
  String get settingsBurnWillDelete;

  /// No description provided for @settingsBurnTasks.
  ///
  /// In en, this message translates to:
  /// **'All tasks, plans, and checklists'**
  String get settingsBurnTasks;

  /// No description provided for @settingsBurnCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories and settings'**
  String get settingsBurnCategories;

  /// No description provided for @settingsBurnLocalDb.
  ///
  /// In en, this message translates to:
  /// **'Local database (if used)'**
  String get settingsBurnLocalDb;

  /// No description provided for @settingsBurnCloudData.
  ///
  /// In en, this message translates to:
  /// **'Cloud data (if using Cloud Sync)'**
  String get settingsBurnCloudData;

  /// No description provided for @settingsBurnKeys.
  ///
  /// In en, this message translates to:
  /// **'Encryption keys and saved preferences'**
  String get settingsBurnKeys;

  /// No description provided for @settingsBurnCredentials.
  ///
  /// In en, this message translates to:
  /// **'Your username & password (full sign-out)'**
  String get settingsBurnCredentials;

  /// No description provided for @settingsBurnSession.
  ///
  /// In en, this message translates to:
  /// **'Your session — you\'ll need to log in again'**
  String get settingsBurnSession;

  /// No description provided for @settingsBurnIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. There is no way to recover your data after this.'**
  String get settingsBurnIrreversible;

  /// No description provided for @settingsBurnEverything.
  ///
  /// In en, this message translates to:
  /// **'Burn Everything'**
  String get settingsBurnEverything;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Encryption'**
  String get privacyTitle;

  /// No description provided for @privacyE2ETitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-End Encrypted'**
  String get privacyE2ETitle;

  /// No description provided for @privacyE2ESubtitle.
  ///
  /// In en, this message translates to:
  /// **'AES-256 encryption — the same standard used by banks and governments.'**
  String get privacyE2ESubtitle;

  /// No description provided for @privacyHowProtected.
  ///
  /// In en, this message translates to:
  /// **'How your data is protected'**
  String get privacyHowProtected;

  /// No description provided for @privacyAllContent.
  ///
  /// In en, this message translates to:
  /// **'All your personal content — task names, descriptions, plan titles, checklist items, your household name — is end-to-end encrypted before it leaves your device.'**
  String get privacyAllContent;

  /// No description provided for @privacyOnlyYou.
  ///
  /// In en, this message translates to:
  /// **'Only you and your household members can read your data. Not even the app developers can see it.'**
  String get privacyOnlyYou;

  /// No description provided for @privacyWhatEncrypted.
  ///
  /// In en, this message translates to:
  /// **'What is encrypted'**
  String get privacyWhatEncrypted;

  /// No description provided for @privacyTaskTitles.
  ///
  /// In en, this message translates to:
  /// **'Task titles and descriptions'**
  String get privacyTaskTitles;

  /// No description provided for @privacySubtaskTitles.
  ///
  /// In en, this message translates to:
  /// **'Subtask titles'**
  String get privacySubtaskTitles;

  /// No description provided for @privacyChecklistTitles.
  ///
  /// In en, this message translates to:
  /// **'Checklist and checklist item titles'**
  String get privacyChecklistTitles;

  /// No description provided for @privacyPlanTitles.
  ///
  /// In en, this message translates to:
  /// **'Plan titles, entry titles, labels, and descriptions'**
  String get privacyPlanTitles;

  /// No description provided for @privacyCategoryNames.
  ///
  /// In en, this message translates to:
  /// **'Category names'**
  String get privacyCategoryNames;

  /// No description provided for @privacyHouseholdName.
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get privacyHouseholdName;

  /// No description provided for @privacyDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get privacyDisplayName;

  /// No description provided for @privacyAttachmentNames.
  ///
  /// In en, this message translates to:
  /// **'File attachment names and descriptions'**
  String get privacyAttachmentNames;

  /// No description provided for @privacyAttachmentMetadata.
  ///
  /// In en, this message translates to:
  /// **'Attachment metadata (file type, links, thumbnails)'**
  String get privacyAttachmentMetadata;

  /// No description provided for @privacyWhatNotEncrypted.
  ///
  /// In en, this message translates to:
  /// **'What is not encrypted'**
  String get privacyWhatNotEncrypted;

  /// No description provided for @privacyTaskStatus.
  ///
  /// In en, this message translates to:
  /// **'Task status (pending, completed, etc.)'**
  String get privacyTaskStatus;

  /// No description provided for @privacyPriorityLevels.
  ///
  /// In en, this message translates to:
  /// **'Priority levels (low, medium, high, urgent)'**
  String get privacyPriorityLevels;

  /// No description provided for @privacyDueDates.
  ///
  /// In en, this message translates to:
  /// **'Due dates and timestamps'**
  String get privacyDueDates;

  /// No description provided for @privacyCheckedStatus.
  ///
  /// In en, this message translates to:
  /// **'Whether items are checked or completed'**
  String get privacyCheckedStatus;

  /// No description provided for @privacySortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order and display settings'**
  String get privacySortOrder;

  /// No description provided for @privacyCategoryIcons.
  ///
  /// In en, this message translates to:
  /// **'Category icons and colours'**
  String get privacyCategoryIcons;

  /// No description provided for @privacyFileAttachments.
  ///
  /// In en, this message translates to:
  /// **'File attachments (Google Drive)'**
  String get privacyFileAttachments;

  /// No description provided for @privacyDriveExplanation.
  ///
  /// In en, this message translates to:
  /// **'Files you attach to tasks are stored in the household owner\'s Google Drive, in a dedicated \"Pacelli\" folder. File names and descriptions are encrypted in Pacelli\'s database, but the actual files in Google Drive are protected by Google\'s own security — not Pacelli\'s E2E encryption.'**
  String get privacyDriveExplanation;

  /// No description provided for @privacyDriveAccess.
  ///
  /// In en, this message translates to:
  /// **'Household members access files via shareable view-only links. The files are stored using the owner\'s Google Drive storage quota — no extra costs for the app.'**
  String get privacyDriveAccess;

  /// No description provided for @privacyWhyNotEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Why some fields aren\'t encrypted'**
  String get privacyWhyNotEncrypted;

  /// No description provided for @privacyWhyExplanation.
  ///
  /// In en, this message translates to:
  /// **'These structural fields are needed for the app to filter, sort, and organise your data on the server. They don\'t contain personal information — they\'re labels like \"completed\" or \"high priority\", not your actual content.'**
  String get privacyWhyExplanation;

  /// No description provided for @privacyYourControl.
  ///
  /// In en, this message translates to:
  /// **'Your data, your control'**
  String get privacyYourControl;

  /// No description provided for @privacyDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'You can delete ALL your data at any time using \"Burn All My Data\" in Settings. When you delete your data, the encrypted content is permanently removed from our servers.'**
  String get privacyDeleteAll;

  /// No description provided for @privacyKeyGeneration.
  ///
  /// In en, this message translates to:
  /// **'Your encryption key is generated on your device and never stored in readable form on the server. Each household member receives their own encrypted copy of the shared key.'**
  String get privacyKeyGeneration;

  /// No description provided for @storageWhereDataLive.
  ///
  /// In en, this message translates to:
  /// **'Where should your data live?'**
  String get storageWhereDataLive;

  /// No description provided for @storageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your tasks, plans, and checklists are yours. Choose where to keep them.'**
  String get storageSubtitle;

  /// No description provided for @storageOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On This Device'**
  String get storageOnDevice;

  /// No description provided for @storageOnDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Data stays on your phone. No cloud, no sync, full privacy.'**
  String get storageOnDeviceDescription;

  /// No description provided for @storageCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get storageCloudSync;

  /// No description provided for @storageCloudSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Multi-device sync in real time. All your content is end-to-end encrypted.'**
  String get storageCloudSyncDescription;

  /// No description provided for @storageRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get storageRecommended;

  /// No description provided for @storagePrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync uses AES-256 end-to-end encryption. Your personal content (task names, descriptions, checklist items) is encrypted on your device before it ever leaves. Not even we can read it.'**
  String get storagePrivacyNote;

  /// No description provided for @storageFailedLocal.
  ///
  /// In en, this message translates to:
  /// **'Failed to set up local storage: {error}'**
  String storageFailedLocal(String error);

  /// No description provided for @storageFailedCloud.
  ///
  /// In en, this message translates to:
  /// **'Failed to set up cloud sync: {error}'**
  String storageFailedCloud(String error);

  /// No description provided for @errorDefault.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.\nPlease try again.'**
  String get errorDefault;

  /// No description provided for @taskRecurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get taskRecurrenceDaily;

  /// No description provided for @taskRecurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get taskRecurrenceWeekly;

  /// No description provided for @taskRecurrenceBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get taskRecurrenceBiweekly;

  /// No description provided for @taskRecurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get taskRecurrenceMonthly;

  /// No description provided for @taskSubtaskProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total}'**
  String taskSubtaskProgress(int completed, int total);

  /// No description provided for @taskNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get taskNew;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// No description provided for @commonOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOK;

  /// No description provided for @taskAddSubtask.
  ///
  /// In en, this message translates to:
  /// **'Add a subtask...'**
  String get taskAddSubtask;

  /// No description provided for @taskDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get taskDescription;

  /// No description provided for @taskLabelAssignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get taskLabelAssignTo;

  /// No description provided for @taskLabelPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskLabelPriority;

  /// No description provided for @taskLabelRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get taskLabelRepeat;

  /// No description provided for @taskRecurrenceNone.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get taskRecurrenceNone;

  /// No description provided for @taskUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get taskUnassigned;

  /// No description provided for @tasksFailedToLoadHousehold.
  ///
  /// In en, this message translates to:
  /// **'Failed to load household'**
  String get tasksFailedToLoadHousehold;

  /// No description provided for @tasksLoadingHousehold.
  ///
  /// In en, this message translates to:
  /// **'Loading household…'**
  String get tasksLoadingHousehold;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get priorityNone;

  /// No description provided for @recurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceEveryTwoWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get recurrenceEveryTwoWeeks;

  /// No description provided for @recurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurrenceMonthly;

  /// No description provided for @recurrenceNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get recurrenceNever;

  /// No description provided for @calendarTasksSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks · {dayLabel} · {count}'**
  String calendarTasksSectionTitle(String dayLabel, int count);

  /// No description provided for @calendarNoTasksOnDay.
  ///
  /// In en, this message translates to:
  /// **'No tasks on this day'**
  String get calendarNoTasksOnDay;

  /// No description provided for @calendarPlansSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Plans · {count}'**
  String calendarPlansSectionTitle(int count);

  /// No description provided for @calendarNoDraftPlans.
  ///
  /// In en, this message translates to:
  /// **'No draft plans'**
  String get calendarNoDraftPlans;

  /// No description provided for @calendarPlanEntries.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String calendarPlanEntries(int count);

  /// No description provided for @calendarChecklistItems.
  ///
  /// In en, this message translates to:
  /// **'{count} checklist items'**
  String calendarChecklistItems(int count);

  /// No description provided for @settingsBurnDriveWarning.
  ///
  /// In en, this message translates to:
  /// **'Heads up — this won\'t delete your Pacelli folder in Google Drive or any files on your device. You\'ll need to remove those manually if you\'d like.'**
  String get settingsBurnDriveWarning;

  /// No description provided for @settingsBurnDriveWarningShort.
  ///
  /// In en, this message translates to:
  /// **'Files in Google Drive or local storage must be deleted manually.'**
  String get settingsBurnDriveWarningShort;

  /// No description provided for @burnStatusBurning.
  ///
  /// In en, this message translates to:
  /// **'Burning your data...'**
  String get burnStatusBurning;

  /// No description provided for @burnStatusDestroying.
  ///
  /// In en, this message translates to:
  /// **'Destroying your data...'**
  String get burnStatusDestroying;

  /// No description provided for @burnStatusClearingLocal.
  ///
  /// In en, this message translates to:
  /// **'Clearing local storage...'**
  String get burnStatusClearingLocal;

  /// No description provided for @burnStatusClearingKeys.
  ///
  /// In en, this message translates to:
  /// **'Clearing encryption keys...'**
  String get burnStatusClearingKeys;

  /// No description provided for @burnStatusSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get burnStatusSigningOut;

  /// No description provided for @burnStatusRemovingSettings.
  ///
  /// In en, this message translates to:
  /// **'Removing saved settings...'**
  String get burnStatusRemovingSettings;

  /// No description provided for @burnStatusComplete.
  ///
  /// In en, this message translates to:
  /// **'All data destroyed.'**
  String get burnStatusComplete;

  /// No description provided for @burnStatusError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get burnStatusError;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get appearanceThemeMode;

  /// No description provided for @appearanceThemeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose light, dark, or follow your device settings'**
  String get appearanceThemeModeSubtitle;

  /// No description provided for @appearanceModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get appearanceModeSystem;

  /// No description provided for @appearanceModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceModeLight;

  /// No description provided for @appearanceModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceModeDark;

  /// No description provided for @appearanceColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Colour scheme'**
  String get appearanceColorScheme;

  /// No description provided for @appearanceColorSchemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a palette that suits you'**
  String get appearanceColorSchemeSubtitle;

  /// No description provided for @appearanceSchemePacelli.
  ///
  /// In en, this message translates to:
  /// **'Pacelli'**
  String get appearanceSchemePacelli;

  /// No description provided for @appearanceSchemePacelliDesc.
  ///
  /// In en, this message translates to:
  /// **'Sage green & terracotta'**
  String get appearanceSchemePacelliDesc;

  /// No description provided for @appearanceSchemeClaude.
  ///
  /// In en, this message translates to:
  /// **'Claude'**
  String get appearanceSchemeClaude;

  /// No description provided for @appearanceSchemeClaudeDesc.
  ///
  /// In en, this message translates to:
  /// **'Warm purple & coral'**
  String get appearanceSchemeClaudeDesc;

  /// No description provided for @appearanceSchemeGemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get appearanceSchemeGemini;

  /// No description provided for @appearanceSchemeGeminiDesc.
  ///
  /// In en, this message translates to:
  /// **'Ocean blue & coral'**
  String get appearanceSchemeGeminiDesc;

  /// No description provided for @attachCount.
  ///
  /// In en, this message translates to:
  /// **'Attachments ({count})'**
  String attachCount(int count);

  /// No description provided for @attachInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid link.'**
  String get attachInvalidLink;

  /// No description provided for @attachCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open file.'**
  String get attachCouldNotOpen;

  /// No description provided for @attachRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get attachRemoveTooltip;

  /// No description provided for @planAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get planAttachFile;

  /// No description provided for @planRemoveAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment?'**
  String get planRemoveAttachmentTitle;

  /// No description provided for @planRemoveAttachmentMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{fileName}\" from this entry? The file will remain in Google Drive.'**
  String planRemoveAttachmentMessage(String fileName);

  /// No description provided for @planAttachmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{file} other{files}}'**
  String planAttachmentCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
