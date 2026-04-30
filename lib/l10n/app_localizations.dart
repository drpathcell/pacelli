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

  /// No description provided for @authContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueWithApple;

  /// No description provided for @authAppleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in failed. Please try again.'**
  String get authAppleSignInFailed;

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

  /// No description provided for @tasksCreateFirstTask.
  ///
  /// In en, this message translates to:
  /// **'Create your first task'**
  String get tasksCreateFirstTask;

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

  /// No description provided for @settingsSectionHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get settingsSectionHousehold;

  /// No description provided for @settingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsSectionApp;

  /// No description provided for @settingsSectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsSectionHelp;

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

  /// No description provided for @settingsAboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsAboutPrivacyPolicy;

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

  /// No description provided for @privacyFieldDetails.
  ///
  /// In en, this message translates to:
  /// **'Field-level details'**
  String get privacyFieldDetails;

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

  /// No description provided for @burnPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Account Deletion'**
  String get burnPasswordTitle;

  /// No description provided for @burnPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'To permanently delete your account and all data, please enter your password.'**
  String get burnPasswordMessage;

  /// No description provided for @burnPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get burnPasswordHint;

  /// No description provided for @burnPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get burnPasswordConfirm;

  /// No description provided for @burnPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get burnPasswordError;

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

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notifEnable;

  /// No description provided for @notifEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get reminders when tasks are due'**
  String get notifEnableSubtitle;

  /// No description provided for @notifTimingTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder timing'**
  String get notifTimingTitle;

  /// No description provided for @notifTimingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When should we remind you about due tasks?'**
  String get notifTimingSubtitle;

  /// No description provided for @notifTimingAtDue.
  ///
  /// In en, this message translates to:
  /// **'At due time'**
  String get notifTimingAtDue;

  /// No description provided for @notifTimingAtDueDesc.
  ///
  /// In en, this message translates to:
  /// **'Notify exactly when the task is due'**
  String get notifTimingAtDueDesc;

  /// No description provided for @notifTimingOneHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get notifTimingOneHour;

  /// No description provided for @notifTimingOneHourDesc.
  ///
  /// In en, this message translates to:
  /// **'Get a heads-up an hour early'**
  String get notifTimingOneHourDesc;

  /// No description provided for @notifTimingOneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get notifTimingOneDay;

  /// No description provided for @notifTimingOneDayDesc.
  ///
  /// In en, this message translates to:
  /// **'Remind at 9 AM the day before'**
  String get notifTimingOneDayDesc;

  /// No description provided for @notifInfoNote.
  ///
  /// In en, this message translates to:
  /// **'Notifications are delivered locally on this device. They work even when the app is closed.'**
  String get notifInfoNote;

  /// No description provided for @settingsImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get settingsImportExport;

  /// No description provided for @settingsImportExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore your data'**
  String get settingsImportExportSubtitle;

  /// No description provided for @ieTitle.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get ieTitle;

  /// No description provided for @ieExportSection.
  ///
  /// In en, this message translates to:
  /// **'EXPORT'**
  String get ieExportSection;

  /// No description provided for @ieExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export as JSON'**
  String get ieExportJson;

  /// No description provided for @ieExportJsonDesc.
  ///
  /// In en, this message translates to:
  /// **'Full backup of tasks, checklists, plans, and inventory'**
  String get ieExportJsonDesc;

  /// No description provided for @ieExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export tasks as CSV'**
  String get ieExportCsv;

  /// No description provided for @ieExportCsvDesc.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet-friendly list of tasks only'**
  String get ieExportCsvDesc;

  /// No description provided for @ieExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export saved successfully!'**
  String get ieExportSuccess;

  /// No description provided for @ieExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String ieExportFailed(String error);

  /// No description provided for @ieLastExport.
  ///
  /// In en, this message translates to:
  /// **'Last export: {date}'**
  String ieLastExport(String date);

  /// No description provided for @ieImportSection.
  ///
  /// In en, this message translates to:
  /// **'IMPORT'**
  String get ieImportSection;

  /// No description provided for @ieImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import from backup'**
  String get ieImportButton;

  /// No description provided for @ieImportDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore data from a Pacelli JSON backup file'**
  String get ieImportDesc;

  /// No description provided for @ieImportReading.
  ///
  /// In en, this message translates to:
  /// **'Reading file...'**
  String get ieImportReading;

  /// No description provided for @ieImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file: {error}'**
  String ieImportInvalid(String error);

  /// No description provided for @ieImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import data?'**
  String get ieImportConfirmTitle;

  /// No description provided for @ieImportConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will add the backed-up data to your current household. Existing data will not be deleted.'**
  String get ieImportConfirmMessage;

  /// No description provided for @ieImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import complete! {created} items created, {skipped} skipped.'**
  String ieImportSuccess(int created, int skipped);

  /// No description provided for @ieImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String ieImportFailed(String error);

  /// No description provided for @ieImportErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Warnings'**
  String get ieImportErrorsTitle;

  /// No description provided for @ieImportErrorsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items could not be imported'**
  String ieImportErrorsCount(int count);

  /// No description provided for @ieExportPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Set passphrase for backup'**
  String get ieExportPassphrase;

  /// No description provided for @ieExportPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a strong passphrase'**
  String get ieExportPassphraseHint;

  /// No description provided for @ieExportPassphraseRequired.
  ///
  /// In en, this message translates to:
  /// **'Passphrase is required to encrypt the backup'**
  String get ieExportPassphraseRequired;

  /// No description provided for @ieImportPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Enter passphrase'**
  String get ieImportPassphrase;

  /// No description provided for @ieImportEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This backup is encrypted'**
  String get ieImportEncrypted;

  /// No description provided for @ieInfoNote.
  ///
  /// In en, this message translates to:
  /// **'All backups are encrypted. Keep your passphrase safe — it cannot be recovered.'**
  String get ieInfoNote;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks, checklists, plans...'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchFilterTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get searchFilterTasks;

  /// No description provided for @searchFilterChecklists.
  ///
  /// In en, this message translates to:
  /// **'Checklists'**
  String get searchFilterChecklists;

  /// No description provided for @searchFilterPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get searchFilterPlans;

  /// No description provided for @searchFilterAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get searchFilterAttachments;

  /// No description provided for @searchLoading.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searchLoading;

  /// No description provided for @searchEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search your household'**
  String get searchEmptyState;

  /// No description provided for @searchResultTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get searchResultTask;

  /// No description provided for @searchResultChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get searchResultChecklist;

  /// No description provided for @searchResultPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get searchResultPlan;

  /// No description provided for @searchResultAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get searchResultAttachment;

  /// No description provided for @searchResultInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get searchResultInventory;

  /// No description provided for @inventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryTitle;

  /// No description provided for @inventoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your inventory is empty — tap + to add your first item'**
  String get inventoryEmpty;

  /// No description provided for @inventoryItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String inventoryItemCount(int count);

  /// No description provided for @inventoryLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get inventoryLowStock;

  /// No description provided for @inventoryExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get inventoryExpiringSoon;

  /// No description provided for @inventoryAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get inventoryAddItem;

  /// No description provided for @inventoryEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get inventoryEditItem;

  /// No description provided for @inventoryItemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get inventoryItemName;

  /// No description provided for @inventoryItemNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Olive oil, Paper towels'**
  String get inventoryItemNameHint;

  /// No description provided for @inventoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get inventoryDescription;

  /// No description provided for @inventoryCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get inventoryCategory;

  /// No description provided for @inventoryLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get inventoryLocation;

  /// No description provided for @inventoryQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get inventoryQuantity;

  /// No description provided for @inventoryUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get inventoryUnit;

  /// No description provided for @inventoryUnitPieces.
  ///
  /// In en, this message translates to:
  /// **'pieces'**
  String get inventoryUnitPieces;

  /// No description provided for @inventoryUnitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get inventoryUnitKg;

  /// No description provided for @inventoryUnitLitres.
  ///
  /// In en, this message translates to:
  /// **'litres'**
  String get inventoryUnitLitres;

  /// No description provided for @inventoryUnitBags.
  ///
  /// In en, this message translates to:
  /// **'bags'**
  String get inventoryUnitBags;

  /// No description provided for @inventoryUnitBoxes.
  ///
  /// In en, this message translates to:
  /// **'boxes'**
  String get inventoryUnitBoxes;

  /// No description provided for @inventoryLowStockThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low stock threshold'**
  String get inventoryLowStockThreshold;

  /// No description provided for @inventoryExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get inventoryExpiryDate;

  /// No description provided for @inventoryPurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase date'**
  String get inventoryPurchaseDate;

  /// No description provided for @inventoryNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get inventoryNotes;

  /// No description provided for @inventoryBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get inventoryBarcode;

  /// No description provided for @inventoryBarcodeNone.
  ///
  /// In en, this message translates to:
  /// **'No barcode'**
  String get inventoryBarcodeNone;

  /// No description provided for @inventoryBarcodeReal.
  ///
  /// In en, this message translates to:
  /// **'Product barcode'**
  String get inventoryBarcodeReal;

  /// No description provided for @inventoryBarcodeVirtual.
  ///
  /// In en, this message translates to:
  /// **'Virtual barcode'**
  String get inventoryBarcodeVirtual;

  /// No description provided for @inventorySave.
  ///
  /// In en, this message translates to:
  /// **'Save item'**
  String get inventorySave;

  /// No description provided for @inventoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get inventoryDelete;

  /// No description provided for @inventoryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this item? This cannot be undone.'**
  String get inventoryDeleteConfirm;

  /// No description provided for @inventoryCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get inventoryCategories;

  /// No description provided for @inventoryLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get inventoryLocations;

  /// No description provided for @inventoryManageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get inventoryManageCategories;

  /// No description provided for @inventoryManageLocations.
  ///
  /// In en, this message translates to:
  /// **'Manage Locations'**
  String get inventoryManageLocations;

  /// No description provided for @inventoryAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get inventoryAddCategory;

  /// No description provided for @inventoryAddLocation.
  ///
  /// In en, this message translates to:
  /// **'Add Location'**
  String get inventoryAddLocation;

  /// No description provided for @inventoryCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get inventoryCategoryName;

  /// No description provided for @inventoryLocationName.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get inventoryLocationName;

  /// No description provided for @inventoryCannotDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete — items are using this category'**
  String get inventoryCannotDeleteCategory;

  /// No description provided for @inventoryCannotDeleteLocation.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete — items are using this location'**
  String get inventoryCannotDeleteLocation;

  /// No description provided for @inventoryLogAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {count}'**
  String inventoryLogAdded(int count);

  /// No description provided for @inventoryLogRemoved.
  ///
  /// In en, this message translates to:
  /// **'Used {count}'**
  String inventoryLogRemoved(int count);

  /// No description provided for @inventoryLogAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Adjusted to {count}'**
  String inventoryLogAdjusted(int count);

  /// No description provided for @inventoryActivityLog.
  ///
  /// In en, this message translates to:
  /// **'Activity Log'**
  String get inventoryActivityLog;

  /// No description provided for @inventoryViewByCategory.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get inventoryViewByCategory;

  /// No description provided for @inventoryViewByLocation.
  ///
  /// In en, this message translates to:
  /// **'By Location'**
  String get inventoryViewByLocation;

  /// No description provided for @inventoryViewAll.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get inventoryViewAll;

  /// No description provided for @inventoryDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get inventoryDetails;

  /// No description provided for @inventoryAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get inventoryAttachments;

  /// No description provided for @inventoryCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by {name}'**
  String inventoryCreatedBy(String name);

  /// No description provided for @inventoryItemsExpiring.
  ///
  /// In en, this message translates to:
  /// **'{count} expiring soon'**
  String inventoryItemsExpiring(int count);

  /// No description provided for @inventoryItemsLowStock.
  ///
  /// In en, this message translates to:
  /// **'{count} low stock'**
  String inventoryItemsLowStock(int count);

  /// No description provided for @inventoryNoExpiry.
  ///
  /// In en, this message translates to:
  /// **'No expiry date'**
  String get inventoryNoExpiry;

  /// No description provided for @inventoryExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days} days'**
  String inventoryExpiresIn(int days);

  /// No description provided for @inventoryExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get inventoryExpired;

  /// No description provided for @inventoryExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get inventoryExpiresToday;

  /// No description provided for @inventoryDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get inventoryDiscardTitle;

  /// No description provided for @inventoryDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to go back?'**
  String get inventoryDiscardMessage;

  /// No description provided for @inventoryKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get inventoryKeepEditing;

  /// No description provided for @inventoryDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get inventoryDiscard;

  /// No description provided for @inventoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Item added!'**
  String get inventoryCreated;

  /// No description provided for @inventoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Item updated!'**
  String get inventoryUpdated;

  /// No description provided for @inventoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get inventoryDeleted;

  /// No description provided for @inventoryCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load inventory'**
  String get inventoryCouldNotLoad;

  /// No description provided for @inventoryUncategorised.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get inventoryUncategorised;

  /// No description provided for @inventoryNoLocation.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get inventoryNoLocation;

  /// No description provided for @inventoryIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get inventoryIconLabel;

  /// No description provided for @inventoryColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get inventoryColorLabel;

  /// No description provided for @inventoryCategoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Category created'**
  String get inventoryCategoryCreated;

  /// No description provided for @inventoryLocationCreated.
  ///
  /// In en, this message translates to:
  /// **'Location created'**
  String get inventoryLocationCreated;

  /// No description provided for @inventoryCategoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get inventoryCategoryDeleted;

  /// No description provided for @inventoryLocationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Location deleted'**
  String get inventoryLocationDeleted;

  /// No description provided for @inventoryCouldNotDelete.
  ///
  /// In en, this message translates to:
  /// **'Could not delete'**
  String get inventoryCouldNotDelete;

  /// No description provided for @inventoryScanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan Barcode'**
  String get inventoryScanBarcode;

  /// No description provided for @inventoryScanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a barcode or QR code'**
  String get inventoryScanPrompt;

  /// No description provided for @inventoryScanNotFound.
  ///
  /// In en, this message translates to:
  /// **'No item found with this barcode'**
  String get inventoryScanNotFound;

  /// No description provided for @inventoryScanFoundItem.
  ///
  /// In en, this message translates to:
  /// **'Found: {name}'**
  String inventoryScanFoundItem(String name);

  /// No description provided for @inventoryScanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Use this barcode?'**
  String get inventoryScanConfirmTitle;

  /// No description provided for @inventoryScanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get inventoryScanConfirm;

  /// No description provided for @inventoryScanRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get inventoryScanRescan;

  /// No description provided for @inventoryBarcodeTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode type'**
  String get inventoryBarcodeTypeLabel;

  /// No description provided for @inventoryBarcodeTypeNone.
  ///
  /// In en, this message translates to:
  /// **'No barcode'**
  String get inventoryBarcodeTypeNone;

  /// No description provided for @inventoryBarcodeTypeReal.
  ///
  /// In en, this message translates to:
  /// **'Scan product barcode'**
  String get inventoryBarcodeTypeReal;

  /// No description provided for @inventoryBarcodeTypeVirtual.
  ///
  /// In en, this message translates to:
  /// **'Generate virtual QR'**
  String get inventoryBarcodeTypeVirtual;

  /// No description provided for @inventoryTapToScan.
  ///
  /// In en, this message translates to:
  /// **'Tap to scan'**
  String get inventoryTapToScan;

  /// No description provided for @inventoryVirtualBarcodeGenerated.
  ///
  /// In en, this message translates to:
  /// **'Virtual QR generated'**
  String get inventoryVirtualBarcodeGenerated;

  /// No description provided for @inventoryViewQrCode.
  ///
  /// In en, this message translates to:
  /// **'View QR Code'**
  String get inventoryViewQrCode;

  /// No description provided for @inventoryQrCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Virtual Barcode'**
  String get inventoryQrCodeTitle;

  /// No description provided for @inventoryQrCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code to find this item'**
  String get inventoryQrCodeSubtitle;

  /// No description provided for @inventoryCameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan barcodes'**
  String get inventoryCameraPermissionDenied;

  /// No description provided for @inventoryExpiringNotification.
  ///
  /// In en, this message translates to:
  /// **'{name} is expiring soon'**
  String inventoryExpiringNotification(String name);

  /// No description provided for @inventoryLowStockNotification.
  ///
  /// In en, this message translates to:
  /// **'{name} is running low ({count} remaining)'**
  String inventoryLowStockNotification(String name, int count);

  /// No description provided for @inventoryCreateRestockTask.
  ///
  /// In en, this message translates to:
  /// **'Create restock task?'**
  String get inventoryCreateRestockTask;

  /// No description provided for @inventoryRestockTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Restock: {name}'**
  String inventoryRestockTaskTitle(String name);

  /// No description provided for @inventoryExpiryTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Use before expiry: {name}'**
  String inventoryExpiryTaskTitle(String name);

  /// No description provided for @inventoryRestockTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Restock task created'**
  String get inventoryRestockTaskCreated;

  /// No description provided for @inventoryExpiryTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Expiry task created'**
  String get inventoryExpiryTaskCreated;

  /// No description provided for @inventoryAutoCreateTask.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get inventoryAutoCreateTask;

  /// No description provided for @inventoryNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Notification sent'**
  String get inventoryNotificationSent;

  /// No description provided for @inventoryItemExpired.
  ///
  /// In en, this message translates to:
  /// **'Item expired'**
  String get inventoryItemExpired;

  /// No description provided for @inventoryCalendarExpiring.
  ///
  /// In en, this message translates to:
  /// **'Expiring Items'**
  String get inventoryCalendarExpiring;

  /// No description provided for @inventoryLowStockAlert.
  ///
  /// In en, this message translates to:
  /// **'Low stock! Create a shopping task?'**
  String get inventoryLowStockAlert;

  /// No description provided for @inventoryThresholdCrossed.
  ///
  /// In en, this message translates to:
  /// **'{name} dropped below {threshold}'**
  String inventoryThresholdCrossed(String name, int threshold);

  /// No description provided for @inventoryExpiryCalendarDot.
  ///
  /// In en, this message translates to:
  /// **'Item expiring'**
  String get inventoryExpiryCalendarDot;

  /// No description provided for @inventoryActivityLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get inventoryActivityLogEmpty;

  /// No description provided for @inventoryDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get inventoryDefaultLabel;

  /// No description provided for @commonErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonErrorGeneric;

  /// No description provided for @homeInventorySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get homeInventorySnapshot;

  /// No description provided for @homeInvTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get homeInvTotal;

  /// No description provided for @homeInventorySummary.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {alert} alert'**
  String homeInventorySummary(int count, int alert);

  /// No description provided for @homeInventorySummaryPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {alert} alerts'**
  String homeInventorySummaryPlural(int count, int alert);

  /// No description provided for @settingsAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get settingsAiAssistant;

  /// No description provided for @settingsAiAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your AI assistant to your household'**
  String get settingsAiAssistantSubtitle;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistantTitle;

  /// No description provided for @aiAssistantHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Integration'**
  String get aiAssistantHeroTitle;

  /// No description provided for @aiAssistantHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your AI assistant to manage your household with natural language.'**
  String get aiAssistantHeroSubtitle;

  /// No description provided for @aiAssistantStep1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Generate Auth Token'**
  String get aiAssistantStep1Title;

  /// No description provided for @aiAssistantStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Generate a Firebase ID token that authenticates the MCP server with your Pacelli account. Tokens expire after 1 hour — regenerate as needed.'**
  String get aiAssistantStep1Desc;

  /// No description provided for @aiAssistantGenerateToken.
  ///
  /// In en, this message translates to:
  /// **'Generate Token'**
  String get aiAssistantGenerateToken;

  /// No description provided for @aiAssistantRegenerateToken.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Token'**
  String get aiAssistantRegenerateToken;

  /// No description provided for @aiAssistantTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Auth Token'**
  String get aiAssistantTokenLabel;

  /// No description provided for @aiAssistantTokenWarning.
  ///
  /// In en, this message translates to:
  /// **'This token grants full access to your household data. Do not share it with anyone. It expires automatically after 1 hour.'**
  String get aiAssistantTokenWarning;

  /// No description provided for @aiAssistantTokenError.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate token. Please try again.'**
  String get aiAssistantTokenError;

  /// No description provided for @aiAssistantStep2Title.
  ///
  /// In en, this message translates to:
  /// **'2. API Endpoint'**
  String get aiAssistantStep2Title;

  /// No description provided for @aiAssistantStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'The Cloud Functions URL that the MCP server connects to. This is pre-configured for your Pacelli instance.'**
  String get aiAssistantStep2Desc;

  /// No description provided for @aiAssistantApiUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'API URL'**
  String get aiAssistantApiUrlLabel;

  /// No description provided for @aiAssistantStep3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Configure Your MCP Client'**
  String get aiAssistantStep3Title;

  /// No description provided for @aiAssistantStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'Add this to your MCP client\'s configuration file (e.g. Claude Desktop, Cursor, or any MCP-compatible app). Replace the path with your actual MCP server location.'**
  String get aiAssistantStep3Desc;

  /// No description provided for @aiAssistantConfig.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get aiAssistantConfig;

  /// No description provided for @aiAssistantStep4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Test Connection'**
  String get aiAssistantStep4Title;

  /// No description provided for @aiAssistantStep4Desc.
  ///
  /// In en, this message translates to:
  /// **'Verify that your token is valid and the connection is ready.'**
  String get aiAssistantStep4Desc;

  /// No description provided for @aiAssistantTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get aiAssistantTestConnection;

  /// No description provided for @aiAssistantStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready! Your token is valid. Start your MCP client to connect.'**
  String get aiAssistantStatusReady;

  /// No description provided for @aiAssistantStatusNoUser.
  ///
  /// In en, this message translates to:
  /// **'Not signed in. Please sign in to generate a token.'**
  String get aiAssistantStatusNoUser;

  /// No description provided for @aiAssistantStatusError.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed. Try regenerating your token.'**
  String get aiAssistantStatusError;

  /// No description provided for @aiAssistantCopied.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String aiAssistantCopied(String label);

  /// No description provided for @aiAssistantConnectionMode.
  ///
  /// In en, this message translates to:
  /// **'Connection Mode'**
  String get aiAssistantConnectionMode;

  /// No description provided for @aiAssistantModeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get aiAssistantModeLocal;

  /// No description provided for @aiAssistantModeHosted.
  ///
  /// In en, this message translates to:
  /// **'Hosted'**
  String get aiAssistantModeHosted;

  /// No description provided for @aiAssistantModeLocalDesc.
  ///
  /// In en, this message translates to:
  /// **'Run the MCP server on your computer. Best for development and single-user setups.'**
  String get aiAssistantModeLocalDesc;

  /// No description provided for @aiAssistantModeHostedDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect to a cloud-hosted MCP server. Best for always-on access from any device.'**
  String get aiAssistantModeHostedDesc;

  /// No description provided for @aiAssistantChooseProvider.
  ///
  /// In en, this message translates to:
  /// **'Choose your AI provider'**
  String get aiAssistantChooseProvider;

  /// No description provided for @aiAssistantChooseProviderDesc.
  ///
  /// In en, this message translates to:
  /// **'Select which AI assistant you\'d like to connect to Pacelli.'**
  String get aiAssistantChooseProviderDesc;

  /// No description provided for @aiAssistantEnterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Enter your {provider} API key'**
  String aiAssistantEnterApiKey(String provider);

  /// No description provided for @aiAssistantApiKeyDesc.
  ///
  /// In en, this message translates to:
  /// **'You can find your API key in your {provider} account settings. It will be stored securely on your device.'**
  String aiAssistantApiKeyDesc(String provider);

  /// No description provided for @aiAssistantApiKeySecure.
  ///
  /// In en, this message translates to:
  /// **'Your API key is encrypted and stored locally on your device. It never leaves your phone.'**
  String get aiAssistantApiKeySecure;

  /// No description provided for @aiAssistantConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get aiAssistantConnect;

  /// No description provided for @aiAssistantConnected.
  ///
  /// In en, this message translates to:
  /// **'AI assistant connected successfully!'**
  String get aiAssistantConnected;

  /// No description provided for @aiAssistantConnectError.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect. Please check your API key and try again.'**
  String get aiAssistantConnectError;

  /// No description provided for @aiAssistantDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get aiAssistantDisconnect;

  /// No description provided for @aiAssistantDisconnected.
  ///
  /// In en, this message translates to:
  /// **'AI assistant disconnected.'**
  String get aiAssistantDisconnected;

  /// No description provided for @aiAssistantStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get aiAssistantStatusConnected;

  /// No description provided for @aiAssistantConnectedTo.
  ///
  /// In en, this message translates to:
  /// **'Using {provider} as your AI assistant.'**
  String aiAssistantConnectedTo(String provider);

  /// No description provided for @aiAssistantAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced: MCP Configuration'**
  String get aiAssistantAdvancedTitle;

  /// No description provided for @aiAssistantAdvancedDesc.
  ///
  /// In en, this message translates to:
  /// **'For developers connecting external MCP clients (Claude Desktop, Cursor, etc.) directly to Pacelli\'s API.'**
  String get aiAssistantAdvancedDesc;

  /// No description provided for @aiAssistantTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get aiAssistantTipsTitle;

  /// No description provided for @aiAssistantTip1.
  ///
  /// In en, this message translates to:
  /// **'Tokens expire after 1 hour. Regenerate before each session.'**
  String get aiAssistantTip1;

  /// No description provided for @aiAssistantTip2.
  ///
  /// In en, this message translates to:
  /// **'All data is decrypted server-side — the AI sees plaintext but your Firestore stays encrypted.'**
  String get aiAssistantTip2;

  /// No description provided for @aiAssistantTip3.
  ///
  /// In en, this message translates to:
  /// **'Try asking: \"What tasks are due this week?\" or \"Create a shopping list for Saturday.\"'**
  String get aiAssistantTip3;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @aiChatWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'How can I help?'**
  String get aiChatWelcomeTitle;

  /// No description provided for @aiChatWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your household — tasks, plans, inventory, or just chat.'**
  String get aiChatWelcomeSubtitle;

  /// No description provided for @aiChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask your assistant...'**
  String get aiChatInputHint;

  /// No description provided for @aiChatSuggestion1.
  ///
  /// In en, this message translates to:
  /// **'What tasks are due this week?'**
  String get aiChatSuggestion1;

  /// No description provided for @aiChatSuggestion2.
  ///
  /// In en, this message translates to:
  /// **'Summarise my shopping list'**
  String get aiChatSuggestion2;

  /// No description provided for @aiChatSuggestion3.
  ///
  /// In en, this message translates to:
  /// **'What\'s expiring soon?'**
  String get aiChatSuggestion3;

  /// No description provided for @settingsCapabilities.
  ///
  /// In en, this message translates to:
  /// **'What Can Pacelli Do?'**
  String get settingsCapabilities;

  /// No description provided for @settingsCapabilitiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore all features and capabilities'**
  String get settingsCapabilitiesSubtitle;

  /// No description provided for @capScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get capScreenTitle;

  /// No description provided for @capGroupTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get capGroupTasks;

  /// No description provided for @capGroupTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Create, organise, and track household to-dos'**
  String get capGroupTasksDesc;

  /// No description provided for @capCreateTasks.
  ///
  /// In en, this message translates to:
  /// **'Create & manage tasks'**
  String get capCreateTasks;

  /// No description provided for @capCreateTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Add tasks with titles, descriptions, due dates, and priorities.'**
  String get capCreateTasksDesc;

  /// No description provided for @capRecurringTasks.
  ///
  /// In en, this message translates to:
  /// **'Recurring tasks'**
  String get capRecurringTasks;

  /// No description provided for @capRecurringTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Set tasks to repeat daily, weekly, or monthly.'**
  String get capRecurringTasksDesc;

  /// No description provided for @capTaskPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority levels'**
  String get capTaskPriority;

  /// No description provided for @capTaskPriorityDesc.
  ///
  /// In en, this message translates to:
  /// **'Low, medium, high, and urgent priorities to stay on top of what matters.'**
  String get capTaskPriorityDesc;

  /// No description provided for @capSharedTasks.
  ///
  /// In en, this message translates to:
  /// **'Shared tasks'**
  String get capSharedTasks;

  /// No description provided for @capSharedTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Assign tasks to household members and collaborate.'**
  String get capSharedTasksDesc;

  /// No description provided for @capSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get capSubtasks;

  /// No description provided for @capSubtasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Break large tasks into smaller, trackable steps.'**
  String get capSubtasksDesc;

  /// No description provided for @capGroupChecklists.
  ///
  /// In en, this message translates to:
  /// **'Checklists'**
  String get capGroupChecklists;

  /// No description provided for @capGroupChecklistsDesc.
  ///
  /// In en, this message translates to:
  /// **'Shopping lists, packing lists, and more'**
  String get capGroupChecklistsDesc;

  /// No description provided for @capShoppingLists.
  ///
  /// In en, this message translates to:
  /// **'Shopping & packing lists'**
  String get capShoppingLists;

  /// No description provided for @capShoppingListsDesc.
  ///
  /// In en, this message translates to:
  /// **'Create reusable checklists with quantities and check-off items.'**
  String get capShoppingListsDesc;

  /// No description provided for @capPushAsTask.
  ///
  /// In en, this message translates to:
  /// **'Push to task'**
  String get capPushAsTask;

  /// No description provided for @capPushAsTaskDesc.
  ///
  /// In en, this message translates to:
  /// **'Convert any checklist item into a standalone task.'**
  String get capPushAsTaskDesc;

  /// No description provided for @capGroupPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get capGroupPlans;

  /// No description provided for @capGroupPlansDesc.
  ///
  /// In en, this message translates to:
  /// **'Multi-day trip plans, meal plans, and schedules'**
  String get capGroupPlansDesc;

  /// No description provided for @capTripPlans.
  ///
  /// In en, this message translates to:
  /// **'Trip & event planning'**
  String get capTripPlans;

  /// No description provided for @capTripPlansDesc.
  ///
  /// In en, this message translates to:
  /// **'Create day-by-day plans with entries, checklists, and notes.'**
  String get capTripPlansDesc;

  /// No description provided for @capPlanTemplates.
  ///
  /// In en, this message translates to:
  /// **'Plan templates'**
  String get capPlanTemplates;

  /// No description provided for @capPlanTemplatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Save plans as templates and reuse them for future trips.'**
  String get capPlanTemplatesDesc;

  /// No description provided for @capFinalisePlan.
  ///
  /// In en, this message translates to:
  /// **'Finalise & convert'**
  String get capFinalisePlan;

  /// No description provided for @capFinalisePlanDesc.
  ///
  /// In en, this message translates to:
  /// **'Finalise a plan to convert entries into tasks or checklist items.'**
  String get capFinalisePlanDesc;

  /// No description provided for @capGroupInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get capGroupInventory;

  /// No description provided for @capGroupInventoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Track household items, stock levels, and expiry dates'**
  String get capGroupInventoryDesc;

  /// No description provided for @capTrackItems.
  ///
  /// In en, this message translates to:
  /// **'Item tracking'**
  String get capTrackItems;

  /// No description provided for @capTrackItemsDesc.
  ///
  /// In en, this message translates to:
  /// **'Record items with quantities, units, categories, and locations.'**
  String get capTrackItemsDesc;

  /// No description provided for @capExpiryAlerts.
  ///
  /// In en, this message translates to:
  /// **'Expiry & low-stock alerts'**
  String get capExpiryAlerts;

  /// No description provided for @capExpiryAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Get notified when items are about to expire or run low.'**
  String get capExpiryAlertsDesc;

  /// No description provided for @capBarcodeScanning.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning'**
  String get capBarcodeScanning;

  /// No description provided for @capBarcodeScanningDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan barcodes to quickly add or find items.'**
  String get capBarcodeScanningDesc;

  /// No description provided for @capLocations.
  ///
  /// In en, this message translates to:
  /// **'Storage locations'**
  String get capLocations;

  /// No description provided for @capLocationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Organise items by room, shelf, fridge, or custom locations.'**
  String get capLocationsDesc;

  /// No description provided for @capGroupCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get capGroupCalendar;

  /// No description provided for @capGroupCalendarDesc.
  ///
  /// In en, this message translates to:
  /// **'View tasks, plans, and expiry dates on a calendar'**
  String get capGroupCalendarDesc;

  /// No description provided for @capCalendarView.
  ///
  /// In en, this message translates to:
  /// **'Calendar view'**
  String get capCalendarView;

  /// No description provided for @capCalendarViewDesc.
  ///
  /// In en, this message translates to:
  /// **'See all due dates, plan entries, and expiring items at a glance.'**
  String get capCalendarViewDesc;

  /// No description provided for @capReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders & notifications'**
  String get capReminders;

  /// No description provided for @capRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Receive push notifications for deadlines and important events.'**
  String get capRemindersDesc;

  /// No description provided for @capGroupAi.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get capGroupAi;

  /// No description provided for @capGroupAiDesc.
  ///
  /// In en, this message translates to:
  /// **'Natural-language control and automation'**
  String get capGroupAiDesc;

  /// No description provided for @capNaturalLanguage.
  ///
  /// In en, this message translates to:
  /// **'Chat with your household'**
  String get capNaturalLanguage;

  /// No description provided for @capNaturalLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Ask questions and give commands in plain English via the in-app chat.'**
  String get capNaturalLanguageDesc;

  /// No description provided for @capMcpIntegration.
  ///
  /// In en, this message translates to:
  /// **'MCP integration'**
  String get capMcpIntegration;

  /// No description provided for @capMcpIntegrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect external AI tools (Claude, Cursor, etc.) to your household data.'**
  String get capMcpIntegrationDesc;

  /// No description provided for @capGroupSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get capGroupSecurity;

  /// No description provided for @capGroupSecurityDesc.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption and data control'**
  String get capGroupSecurityDesc;

  /// No description provided for @capEncryption.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption'**
  String get capEncryption;

  /// No description provided for @capEncryptionDesc.
  ///
  /// In en, this message translates to:
  /// **'All human-readable data is encrypted with AES-256 before leaving your device.'**
  String get capEncryptionDesc;

  /// No description provided for @capBurnData.
  ///
  /// In en, this message translates to:
  /// **'Burn all data'**
  String get capBurnData;

  /// No description provided for @capBurnDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all household data, keys, and credentials in one tap.'**
  String get capBurnDataDesc;

  /// No description provided for @capBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get capBackupRestore;

  /// No description provided for @capBackupRestoreDesc.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backups and restore them on any device.'**
  String get capBackupRestoreDesc;

  /// No description provided for @capGroupFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback & Insights'**
  String get capGroupFeedback;

  /// No description provided for @capGroupFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Share feedback, track app health, and review weekly usage'**
  String get capGroupFeedbackDesc;

  /// No description provided for @capSubmitFeedback.
  ///
  /// In en, this message translates to:
  /// **'Submit feedback'**
  String get capSubmitFeedback;

  /// No description provided for @capSubmitFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Report bugs, request features, or share general feedback with the development team.'**
  String get capSubmitFeedbackDesc;

  /// No description provided for @capAiChatFeedback.
  ///
  /// In en, this message translates to:
  /// **'AI response rating'**
  String get capAiChatFeedback;

  /// No description provided for @capAiChatFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Rate AI assistant responses with thumbs up or down to improve quality over time.'**
  String get capAiChatFeedbackDesc;

  /// No description provided for @capWeeklyDigest.
  ///
  /// In en, this message translates to:
  /// **'Weekly usage digest'**
  String get capWeeklyDigest;

  /// No description provided for @capWeeklyDigestDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatic weekly summary of tasks, plans, inventory changes, and app health metrics.'**
  String get capWeeklyDigestDesc;

  /// No description provided for @settingsManual.
  ///
  /// In en, this message translates to:
  /// **'House Manual'**
  String get settingsManual;

  /// No description provided for @settingsManualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guides, recipes, SOPs & how-tos'**
  String get settingsManualSubtitle;

  /// No description provided for @manualTitle.
  ///
  /// In en, this message translates to:
  /// **'House Manual'**
  String get manualTitle;

  /// No description provided for @manualSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search guides…'**
  String get manualSearchHint;

  /// No description provided for @manualEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get manualEmpty;

  /// No description provided for @manualEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first guide, recipe, or how-to'**
  String get manualEmptyHint;

  /// No description provided for @manualPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get manualPinned;

  /// No description provided for @manualManageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manualManageCategories;

  /// No description provided for @manualCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Entry'**
  String get manualCreateTitle;

  /// No description provided for @manualEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Entry'**
  String get manualEditTitle;

  /// No description provided for @manualEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get manualEntryTitle;

  /// No description provided for @manualCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get manualCategory;

  /// No description provided for @manualNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get manualNoCategory;

  /// No description provided for @manualAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get manualAddTag;

  /// No description provided for @manualPinEntry.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get manualPinEntry;

  /// No description provided for @manualContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get manualContent;

  /// No description provided for @manualContentHint.
  ///
  /// In en, this message translates to:
  /// **'Write your guide, recipe, or instructions here…'**
  String get manualContentHint;

  /// No description provided for @manualTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get manualTitleRequired;

  /// No description provided for @manualCategoryLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories'**
  String get manualCategoryLoadError;

  /// No description provided for @manualDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get manualDeleteTitle;

  /// No description provided for @manualDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove this entry from the house manual.'**
  String get manualDeleteConfirm;

  /// No description provided for @manualNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content yet. Tap edit to add some.'**
  String get manualNoContent;

  /// No description provided for @manualLastEdited.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get manualLastEdited;

  /// No description provided for @manualNoCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get manualNoCategoriesYet;

  /// No description provided for @manualAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get manualAddCategory;

  /// No description provided for @manualCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get manualCategoryName;

  /// No description provided for @manualDeleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get manualDeleteCategoryTitle;

  /// No description provided for @manualDeleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Entries in this category will become uncategorised.'**
  String get manualDeleteCategoryConfirm;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback & Insights'**
  String get settingsFeedback;

  /// No description provided for @settingsFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit feedback, view diagnostics and weekly digests'**
  String get settingsFeedbackSubtitle;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback & Insights'**
  String get feedbackTitle;

  /// No description provided for @feedbackTabSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get feedbackTabSubmit;

  /// No description provided for @feedbackTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get feedbackTabHistory;

  /// No description provided for @feedbackTabDigests.
  ///
  /// In en, this message translates to:
  /// **'Digests'**
  String get feedbackTabDigests;

  /// No description provided for @feedbackType.
  ///
  /// In en, this message translates to:
  /// **'Feedback type'**
  String get feedbackType;

  /// No description provided for @feedbackTypeGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get feedbackTypeGeneral;

  /// No description provided for @feedbackTypeBug.
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get feedbackTypeBug;

  /// No description provided for @feedbackTypeFeature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get feedbackTypeFeature;

  /// No description provided for @feedbackRating.
  ///
  /// In en, this message translates to:
  /// **'How was your experience?'**
  String get feedbackRating;

  /// No description provided for @feedbackPositive.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get feedbackPositive;

  /// No description provided for @feedbackNeutral.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get feedbackNeutral;

  /// No description provided for @feedbackNegative.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get feedbackNegative;

  /// No description provided for @feedbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Your feedback'**
  String get feedbackMessage;

  /// No description provided for @feedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened or what you\'d like to see...'**
  String get feedbackMessageHint;

  /// No description provided for @feedbackMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your feedback'**
  String get feedbackMessageRequired;

  /// No description provided for @feedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get feedbackSubmit;

  /// No description provided for @feedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get feedbackSubmitted;

  /// No description provided for @feedbackError.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit feedback'**
  String get feedbackError;

  /// No description provided for @feedbackNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No feedback submitted yet'**
  String get feedbackNoHistory;

  /// No description provided for @feedbackNoDigests.
  ///
  /// In en, this message translates to:
  /// **'No weekly digests yet'**
  String get feedbackNoDigests;

  /// No description provided for @feedbackNoDigestsHint.
  ///
  /// In en, this message translates to:
  /// **'Digests are generated weekly to summarise your household activity'**
  String get feedbackNoDigestsHint;

  /// No description provided for @feedbackDigestTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get feedbackDigestTasks;

  /// No description provided for @feedbackDigestChecklists.
  ///
  /// In en, this message translates to:
  /// **'Checklists'**
  String get feedbackDigestChecklists;

  /// No description provided for @feedbackDigestPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get feedbackDigestPlans;

  /// No description provided for @feedbackDigestInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get feedbackDigestInventory;

  /// No description provided for @feedbackDigestManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get feedbackDigestManual;

  /// No description provided for @feedbackDigestAI.
  ///
  /// In en, this message translates to:
  /// **'AI chats'**
  String get feedbackDigestAI;
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
