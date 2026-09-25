import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

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
    Locale('ta'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PalliConnect'**
  String get appTitle;

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabDiary.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get tabDiary;

  /// No description provided for @tabMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get tabMessages;

  /// No description provided for @tabProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get tabProgress;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @switchStudent.
  ///
  /// In en, this message translates to:
  /// **'Switch student'**
  String get switchStudent;

  /// No description provided for @addStudent.
  ///
  /// In en, this message translates to:
  /// **'Add student'**
  String get addStudent;

  /// No description provided for @classSection.
  ///
  /// In en, this message translates to:
  /// **'{className}-{section}'**
  String classSection(String className, String section);

  /// No description provided for @todaysOverview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s school overview'**
  String get todaysOverview;

  /// No description provided for @schoolDayTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s School Day'**
  String schoolDayTitle(String name);

  /// No description provided for @todayAtSchool.
  ///
  /// In en, this message translates to:
  /// **'Today at school'**
  String get todayAtSchool;

  /// No description provided for @todaysLearning.
  ///
  /// In en, this message translates to:
  /// **'Today’s Learning'**
  String get todaysLearning;

  /// No description provided for @whatStudentLearned.
  ///
  /// In en, this message translates to:
  /// **'What {name} learned'**
  String whatStudentLearned(String name);

  /// No description provided for @homeworkStatus.
  ///
  /// In en, this message translates to:
  /// **'Homework Status'**
  String get homeworkStatus;

  /// No description provided for @todaysHighlight.
  ///
  /// In en, this message translates to:
  /// **'Today’s Highlight'**
  String get todaysHighlight;

  /// No description provided for @teachersNote.
  ///
  /// In en, this message translates to:
  /// **'Teacher’s note'**
  String get teachersNote;

  /// No description provided for @growingIn.
  ///
  /// In en, this message translates to:
  /// **'Growing In'**
  String get growingIn;

  /// No description provided for @todaysGrowth.
  ///
  /// In en, this message translates to:
  /// **'Today’s growth'**
  String get todaysGrowth;

  /// No description provided for @homework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get homework;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @pendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pendingCount(int count);

  /// No description provided for @completedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String completedCount(int count);

  /// No description provided for @newUpdatesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new updates'**
  String newUpdatesCount(int count);

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// No description provided for @absent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get absent;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @dueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get dueTomorrow;

  /// No description provided for @dueOnDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueOnDate(String date);

  /// No description provided for @dueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String dueInDays(int days);

  /// No description provided for @markAsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark as completed'**
  String get markAsCompleted;

  /// No description provided for @markedComplete.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get markedComplete;

  /// No description provided for @homeworkProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} completed'**
  String homeworkProgress(int done, int total);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get filterPending;

  /// No description provided for @filterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// No description provided for @noHomeworkTitle.
  ///
  /// In en, this message translates to:
  /// **'No homework pending'**
  String get noHomeworkTitle;

  /// No description provided for @noHomeworkBody.
  ///
  /// In en, this message translates to:
  /// **'Enjoy your day.'**
  String get noHomeworkBody;

  /// No description provided for @noNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get noNotificationsTitle;

  /// No description provided for @noNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'New school updates will appear here.'**
  String get noNotificationsBody;

  /// No description provided for @noActivitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'No activities recorded yet'**
  String get noActivitiesTitle;

  /// No description provided for @noActivitiesBody.
  ///
  /// In en, this message translates to:
  /// **'Achievements and events will show here when the school adds them.'**
  String get noActivitiesBody;

  /// No description provided for @searchDiary.
  ///
  /// In en, this message translates to:
  /// **'Search diary'**
  String get searchDiary;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Science, parent meeting…'**
  String get searchHint;

  /// No description provided for @teacherNotes.
  ///
  /// In en, this message translates to:
  /// **'Teacher notes'**
  String get teacherNotes;

  /// No description provided for @schoolNotices.
  ///
  /// In en, this message translates to:
  /// **'School notices'**
  String get schoolNotices;

  /// No description provided for @activities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activities;

  /// No description provided for @noDiaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded this day'**
  String get noDiaryTitle;

  /// No description provided for @noDiaryBody.
  ///
  /// In en, this message translates to:
  /// **'Homework, notes, and notices will appear here when published.'**
  String get noDiaryBody;

  /// No description provided for @academics.
  ///
  /// In en, this message translates to:
  /// **'Academics'**
  String get academics;

  /// No description provided for @homeworkPerformance.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get homeworkPerformance;

  /// No description provided for @growth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get growth;

  /// No description provided for @academicYear.
  ///
  /// In en, this message translates to:
  /// **'Academic year'**
  String get academicYear;

  /// No description provided for @averageLabel.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get averageLabel;

  /// No description provided for @attendancePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% attendance'**
  String attendancePercent(int percent);

  /// No description provided for @presentCount.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get presentCount;

  /// No description provided for @absentCount.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get absentCount;

  /// No description provided for @leaveCount.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveCount;

  /// No description provided for @attendanceWarning.
  ///
  /// In en, this message translates to:
  /// **'Attendance requires attention.'**
  String get attendanceWarning;

  /// No description provided for @feeDue.
  ///
  /// In en, this message translates to:
  /// **'Fee due'**
  String get feeDue;

  /// No description provided for @remainingAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining'**
  String remainingAmount(String amount);

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @tuitionFee.
  ///
  /// In en, this message translates to:
  /// **'Tuition fee'**
  String get tuitionFee;

  /// No description provided for @transportFee.
  ///
  /// In en, this message translates to:
  /// **'Transport fee'**
  String get transportFee;

  /// No description provided for @activityFee.
  ///
  /// In en, this message translates to:
  /// **'Activity fee'**
  String get activityFee;

  /// No description provided for @otherFees.
  ///
  /// In en, this message translates to:
  /// **'Other fees'**
  String get otherFees;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @remainingBalance.
  ///
  /// In en, this message translates to:
  /// **'Remaining balance'**
  String get remainingBalance;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get paymentHistory;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get paymentSuccessful;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentPending;

  /// No description provided for @paymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get paymentProcessing;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get paymentFailed;

  /// No description provided for @digitalId.
  ///
  /// In en, this message translates to:
  /// **'Digital student ID'**
  String get digitalId;

  /// No description provided for @tapToOpenId.
  ///
  /// In en, this message translates to:
  /// **'Tap to open ID card'**
  String get tapToOpenId;

  /// No description provided for @admissionNo.
  ///
  /// In en, this message translates to:
  /// **'Admission no.'**
  String get admissionNo;

  /// No description provided for @rollNo.
  ///
  /// In en, this message translates to:
  /// **'Roll no.'**
  String get rollNo;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @groupedUpdates.
  ///
  /// In en, this message translates to:
  /// **'{count} new school updates'**
  String groupedUpdates(int count);

  /// No description provided for @unableToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Unable to refresh right now.'**
  String get unableToRefresh;

  /// No description provided for @showingLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Showing your last synced information.'**
  String get showingLastSynced;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String lastUpdated(String time);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @tamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get tamil;

  /// No description provided for @schoolIdentity.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get schoolIdentity;

  /// No description provided for @studentInformation.
  ///
  /// In en, this message translates to:
  /// **'Student information'**
  String get studentInformation;

  /// No description provided for @verifyQrHint.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verifyQrHint;

  /// No description provided for @unitTests.
  ///
  /// In en, this message translates to:
  /// **'Unit tests'**
  String get unitTests;

  /// No description provided for @quarterlyExams.
  ///
  /// In en, this message translates to:
  /// **'Quarterly exams'**
  String get quarterlyExams;

  /// No description provided for @halfYearlyExams.
  ///
  /// In en, this message translates to:
  /// **'Half-yearly exams'**
  String get halfYearlyExams;

  /// No description provided for @annualExams.
  ///
  /// In en, this message translates to:
  /// **'Annual exams'**
  String get annualExams;

  /// No description provided for @subjectMarks.
  ///
  /// In en, this message translates to:
  /// **'Marks'**
  String get subjectMarks;

  /// No description provided for @teacherRemarks.
  ///
  /// In en, this message translates to:
  /// **'Teacher remarks'**
  String get teacherRemarks;

  /// No description provided for @achievement.
  ///
  /// In en, this message translates to:
  /// **'Achievement'**
  String get achievement;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get position;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @academicHistory.
  ///
  /// In en, this message translates to:
  /// **'Academic history'**
  String get academicHistory;

  /// No description provided for @homeworkConsistency.
  ///
  /// In en, this message translates to:
  /// **'Homework consistency'**
  String get homeworkConsistency;

  /// No description provided for @teacherObservations.
  ///
  /// In en, this message translates to:
  /// **'Teacher observations'**
  String get teacherObservations;

  /// No description provided for @schoolAssessedSkills.
  ///
  /// In en, this message translates to:
  /// **'School-assessed skills'**
  String get schoolAssessedSkills;

  /// No description provided for @offlinePending.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get offlinePending;

  /// No description provided for @importantAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Important announcement'**
  String get importantAnnouncement;

  /// No description provided for @parentMeeting.
  ///
  /// In en, this message translates to:
  /// **'Parent meeting'**
  String get parentMeeting;

  /// No description provided for @seeAllHomework.
  ///
  /// In en, this message translates to:
  /// **'See all homework'**
  String get seeAllHomework;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @tabBusTracking.
  ///
  /// In en, this message translates to:
  /// **'Bus Tracking'**
  String get tabBusTracking;

  /// No description provided for @etaToYourStop.
  ///
  /// In en, this message translates to:
  /// **'ETA to your stop'**
  String get etaToYourStop;

  /// No description provided for @nextStop.
  ///
  /// In en, this message translates to:
  /// **'Next Stop'**
  String get nextStop;

  /// No description provided for @tripStarted.
  ///
  /// In en, this message translates to:
  /// **'Trip Started'**
  String get tripStarted;

  /// No description provided for @tripEnded.
  ///
  /// In en, this message translates to:
  /// **'Trip Ended'**
  String get tripEnded;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @attachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachment;

  /// No description provided for @classTeacher.
  ///
  /// In en, this message translates to:
  /// **'Class teacher'**
  String get classTeacher;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percentValue(int value);

  /// No description provided for @idCardTitle.
  ///
  /// In en, this message translates to:
  /// **'STUDENT IDENTITY CARD'**
  String get idCardTitle;

  /// No description provided for @bloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood group'**
  String get bloodGroup;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get validUntil;

  /// No description provided for @academicDetails.
  ///
  /// In en, this message translates to:
  /// **'Academic details'**
  String get academicDetails;

  /// No description provided for @schoolFees.
  ///
  /// In en, this message translates to:
  /// **'School Fees'**
  String get schoolFees;

  /// No description provided for @totalFees.
  ///
  /// In en, this message translates to:
  /// **'Total Fees'**
  String get totalFees;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaid;

  /// No description provided for @amountDue.
  ///
  /// In en, this message translates to:
  /// **'Amount Due'**
  String get amountDue;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @feesPaid.
  ///
  /// In en, this message translates to:
  /// **'Fees Paid'**
  String get feesPaid;

  /// No description provided for @informLeave.
  ///
  /// In en, this message translates to:
  /// **'Inform Leave'**
  String get informLeave;

  /// No description provided for @informLate.
  ///
  /// In en, this message translates to:
  /// **'Inform Late'**
  String get informLate;

  /// No description provided for @requestLeave.
  ///
  /// In en, this message translates to:
  /// **'Request Leave'**
  String get requestLeave;

  /// No description provided for @leaveReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for leave'**
  String get leaveReason;

  /// No description provided for @lateReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for delay'**
  String get lateReason;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @aboutMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'About Messages'**
  String get aboutMessagesTitle;

  /// No description provided for @aboutMessagesContent.
  ///
  /// In en, this message translates to:
  /// **'Connect directly with your child\'s class teacher. Use quick actions at the top to request leave or inform the school about delays. You can also upload documents (up to 2MB) for official records.'**
  String get aboutMessagesContent;

  /// No description provided for @selectDocument.
  ///
  /// In en, this message translates to:
  /// **'Select a document'**
  String get selectDocument;

  /// No description provided for @fileLimitHint.
  ///
  /// In en, this message translates to:
  /// **'PDF, Word, or image · max 2MB'**
  String get fileLimitHint;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large. Max limit is 2MB.'**
  String get fileTooLarge;

  /// No description provided for @uploadedDocument.
  ///
  /// In en, this message translates to:
  /// **'Uploaded a document.'**
  String get uploadedDocument;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get typeMessage;

  /// No description provided for @filePickFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the file picker. Please try again.'**
  String get filePickFailed;

  /// No description provided for @messagesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load messages right now. Pull down to try again.'**
  String get messagesUnavailable;

  /// No description provided for @messageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message didn\'t send. Please try again.'**
  String get messageSendFailed;

  /// No description provided for @verifiedStudent.
  ///
  /// In en, this message translates to:
  /// **'Verified Student'**
  String get verifiedStudent;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @daysLabel.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get daysLabel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromDate;

  /// No description provided for @toDate.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toDate;

  /// No description provided for @reasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Family function, fever...'**
  String get reasonHint;

  /// No description provided for @submitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get submitRequest;

  /// No description provided for @pleaseSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a date'**
  String get pleaseSelectDate;

  /// No description provided for @pleaseSelectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Please select date range'**
  String get pleaseSelectDateRange;

  /// No description provided for @studentTeacher.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Teacher'**
  String studentTeacher(String name);

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get underReview;

  /// No description provided for @submittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get submittedForReview;

  /// No description provided for @cancelSubmission.
  ///
  /// In en, this message translates to:
  /// **'Cancel submission'**
  String get cancelSubmission;

  /// No description provided for @assignedOn.
  ///
  /// In en, this message translates to:
  /// **'Assigned on'**
  String get assignedOn;

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Due on'**
  String get dueOn;

  /// No description provided for @noPendingHomework.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get noPendingHomework;

  /// No description provided for @noReviewHomework.
  ///
  /// In en, this message translates to:
  /// **'No homework under review'**
  String get noReviewHomework;

  /// No description provided for @noCompletedHomework.
  ///
  /// In en, this message translates to:
  /// **'Your completed homework will appear here'**
  String get noCompletedHomework;

  /// No description provided for @stars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get stars;

  /// No description provided for @starsEarned.
  ///
  /// In en, this message translates to:
  /// **'Stars earned'**
  String get starsEarned;

  /// No description provided for @starsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'+{count} this week'**
  String starsThisWeek(int count);

  /// No description provided for @starFrom.
  ///
  /// In en, this message translates to:
  /// **'from {teacher}'**
  String starFrom(String teacher);

  /// No description provided for @noStarsTitle.
  ///
  /// In en, this message translates to:
  /// **'No stars yet'**
  String get noStarsTitle;

  /// No description provided for @noStarsBody.
  ///
  /// In en, this message translates to:
  /// **'Teachers give stars when your child does something good — kindness, great work, leadership. They\'ll show up here.'**
  String get noStarsBody;

  /// No description provided for @starsTapHint.
  ///
  /// In en, this message translates to:
  /// **'See why they were earned'**
  String get starsTapHint;

  /// No description provided for @skills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @latestExam.
  ///
  /// In en, this message translates to:
  /// **'Latest exam'**
  String get latestExam;

  /// No description provided for @noMarksYet.
  ///
  /// In en, this message translates to:
  /// **'No marks yet'**
  String get noMarksYet;

  /// No description provided for @growthEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get growthEmptyTitle;

  /// No description provided for @growthEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Notes from teachers and skill ratings will appear here.'**
  String get growthEmptyBody;

  /// No description provided for @skillLevelEmerging.
  ///
  /// In en, this message translates to:
  /// **'Emerging'**
  String get skillLevelEmerging;

  /// No description provided for @skillLevelDeveloping.
  ///
  /// In en, this message translates to:
  /// **'Developing'**
  String get skillLevelDeveloping;

  /// No description provided for @skillLevelProficient.
  ///
  /// In en, this message translates to:
  /// **'Proficient'**
  String get skillLevelProficient;

  /// No description provided for @skillLevelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get skillLevelAdvanced;

  /// No description provided for @skillScaleHint.
  ///
  /// In en, this message translates to:
  /// **'Emerging → Developing → Proficient → Advanced'**
  String get skillScaleHint;

  /// No description provided for @schoolLife.
  ///
  /// In en, this message translates to:
  /// **'School life'**
  String get schoolLife;

  /// No description provided for @timetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get timetable;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @schoolBus.
  ///
  /// In en, this message translates to:
  /// **'School bus'**
  String get schoolBus;

  /// No description provided for @newCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String newCount(int count);

  /// No description provided for @progressEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'As teachers record stars, activities and notes, your child\'s progress builds up here.'**
  String get progressEmptyHint;

  /// No description provided for @recordedBy.
  ///
  /// In en, this message translates to:
  /// **'By {teacher}'**
  String recordedBy(String teacher);

  /// No description provided for @classLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classLabelTitle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need the register number and password to sign in again.'**
  String get signOutConfirmBody;

  /// No description provided for @examSchedule.
  ///
  /// In en, this message translates to:
  /// **'Exam schedule'**
  String get examSchedule;

  /// No description provided for @reportCards.
  ///
  /// In en, this message translates to:
  /// **'Report cards'**
  String get reportCards;

  /// No description provided for @examOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get examOngoing;

  /// No description provided for @examUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get examUpcoming;

  /// No description provided for @noMarksTitle.
  ///
  /// In en, this message translates to:
  /// **'No marks yet'**
  String get noMarksTitle;

  /// No description provided for @noMarksBody.
  ///
  /// In en, this message translates to:
  /// **'Test and exam results will appear here as soon as teachers enter them.'**
  String get noMarksBody;

  /// No description provided for @noAttendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'No attendance yet'**
  String get noAttendanceTitle;

  /// No description provided for @noAttendanceBody.
  ///
  /// In en, this message translates to:
  /// **'Daily attendance will show here once the class teacher starts marking it.'**
  String get noAttendanceBody;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @timetableNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No timetable yet'**
  String get timetableNoneTitle;

  /// No description provided for @timetableNoneBody.
  ///
  /// In en, this message translates to:
  /// **'The school hasn\'t published this class\'s schedule yet.'**
  String get timetableNoneBody;

  /// No description provided for @timetableErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the timetable'**
  String get timetableErrorTitle;

  /// No description provided for @timetableErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get timetableErrorBody;

  /// No description provided for @noClassesOnDay.
  ///
  /// In en, this message translates to:
  /// **'No classes on {day}'**
  String noClassesOnDay(String day);

  /// No description provided for @periodsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} periods'**
  String periodsCount(int count);

  /// No description provided for @periodNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get periodNow;

  /// No description provided for @periodNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get periodNext;

  /// No description provided for @periodCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get periodCover;

  /// No description provided for @todaysPeriods.
  ///
  /// In en, this message translates to:
  /// **'Today\'s classes'**
  String get todaysPeriods;

  /// No description provided for @fullWeek.
  ///
  /// In en, this message translates to:
  /// **'Full week'**
  String get fullWeek;

  /// No description provided for @schoolDayOver.
  ///
  /// In en, this message translates to:
  /// **'School day is over'**
  String get schoolDayOver;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesShort(int count);

  /// No description provided for @tomorrowLabel.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrowLabel;

  /// No description provided for @pickDates.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get pickDates;

  /// No description provided for @whenLabel.
  ///
  /// In en, this message translates to:
  /// **'When?'**
  String get whenLabel;

  /// No description provided for @whyLabel.
  ///
  /// In en, this message translates to:
  /// **'Why?'**
  String get whyLabel;

  /// No description provided for @reasonUnwell.
  ///
  /// In en, this message translates to:
  /// **'Fever / unwell'**
  String get reasonUnwell;

  /// No description provided for @reasonDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor visit'**
  String get reasonDoctor;

  /// No description provided for @reasonFamily.
  ///
  /// In en, this message translates to:
  /// **'Family function'**
  String get reasonFamily;

  /// No description provided for @reasonTravel.
  ///
  /// In en, this message translates to:
  /// **'Travelling'**
  String get reasonTravel;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @addNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a note for the teacher (optional)'**
  String get addNoteOptional;

  /// No description provided for @describeReason.
  ///
  /// In en, this message translates to:
  /// **'Tell the teacher the reason'**
  String get describeReason;

  /// No description provided for @leaveDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String leaveDays(int count);

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your child\'s journey, connected'**
  String get appTagline;

  /// No description provided for @parentLogin.
  ///
  /// In en, this message translates to:
  /// **'Parent login'**
  String get parentLogin;

  /// No description provided for @parentLoginHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the register number and password issued by your school.'**
  String get parentLoginHelp;

  /// No description provided for @registerNumber.
  ///
  /// In en, this message translates to:
  /// **'Register number'**
  String get registerNumber;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @enterRegisterAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter the register number and password.'**
  String get enterRegisterAndPassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @exExams.
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get exExams;

  /// No description provided for @exResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get exResults;

  /// No description provided for @exUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get exUpcoming;

  /// No description provided for @exOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get exOngoing;

  /// No description provided for @exCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get exCompleted;

  /// No description provided for @exNoExamsTitle.
  ///
  /// In en, this message translates to:
  /// **'No exams here'**
  String get exNoExamsTitle;

  /// No description provided for @exNoExamsBody.
  ///
  /// In en, this message translates to:
  /// **'Exam timetables appear here as soon as the school publishes them.'**
  String get exNoExamsBody;

  /// No description provided for @exToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get exToday;

  /// No description provided for @exTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get exTomorrow;

  /// No description provided for @exInDays.
  ///
  /// In en, this message translates to:
  /// **'In {count} days'**
  String exInDays(int count);

  /// No description provided for @exDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get exDone;

  /// No description provided for @exNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {subject} · {when}'**
  String exNext(String subject, String when);

  /// No description provided for @exSubjectCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subject} other{{count} subjects}}'**
  String exSubjectCount(int count);

  /// No description provided for @exTimetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get exTimetable;

  /// No description provided for @exTapForSyllabus.
  ///
  /// In en, this message translates to:
  /// **'Tap a subject to see its syllabus.'**
  String get exTapForSyllabus;

  /// No description provided for @exSyllabus.
  ///
  /// In en, this message translates to:
  /// **'Syllabus'**
  String get exSyllabus;

  /// No description provided for @exNoSyllabus.
  ///
  /// In en, this message translates to:
  /// **'No syllabus added.'**
  String get exNoSyllabus;

  /// No description provided for @exOutOf.
  ///
  /// In en, this message translates to:
  /// **'Out of {max}'**
  String exOutOf(String max);

  /// No description provided for @exPassMark.
  ///
  /// In en, this message translates to:
  /// **'Pass mark {pass}'**
  String exPassMark(String pass);

  /// No description provided for @exResultsOut.
  ///
  /// In en, this message translates to:
  /// **'{released} of {total} subjects out'**
  String exResultsOut(int released, int total);

  /// No description provided for @exResultsNotOut.
  ///
  /// In en, this message translates to:
  /// **'Results not out yet'**
  String get exResultsNotOut;

  /// No description provided for @exAllResultsOut.
  ///
  /// In en, this message translates to:
  /// **'All results are out'**
  String get exAllResultsOut;

  /// No description provided for @exStatementOfMarks.
  ///
  /// In en, this message translates to:
  /// **'Statement of marks'**
  String get exStatementOfMarks;

  /// No description provided for @exStudentName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get exStudentName;

  /// No description provided for @exRegisterNo.
  ///
  /// In en, this message translates to:
  /// **'Register no.'**
  String get exRegisterNo;

  /// No description provided for @exClassSection.
  ///
  /// In en, this message translates to:
  /// **'Class & section'**
  String get exClassSection;

  /// No description provided for @exRollNo.
  ///
  /// In en, this message translates to:
  /// **'Roll no.'**
  String get exRollNo;

  /// No description provided for @exSNo.
  ///
  /// In en, this message translates to:
  /// **'S.No'**
  String get exSNo;

  /// No description provided for @exSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get exSubject;

  /// No description provided for @exMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get exMax;

  /// No description provided for @exPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get exPass;

  /// No description provided for @exMarks.
  ///
  /// In en, this message translates to:
  /// **'Marks'**
  String get exMarks;

  /// No description provided for @exResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get exResult;

  /// No description provided for @exResultPass.
  ///
  /// In en, this message translates to:
  /// **'PASS'**
  String get exResultPass;

  /// No description provided for @exResultFail.
  ///
  /// In en, this message translates to:
  /// **'FAIL'**
  String get exResultFail;

  /// No description provided for @exAbsent.
  ///
  /// In en, this message translates to:
  /// **'AB'**
  String get exAbsent;

  /// No description provided for @exTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get exTotal;

  /// No description provided for @exPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get exPercentage;

  /// No description provided for @exOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall result'**
  String get exOverall;

  /// No description provided for @exAwaited.
  ///
  /// In en, this message translates to:
  /// **'Awaited'**
  String get exAwaited;

  /// No description provided for @exPendingNote.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subject hasn\'t been published yet} other{{count} subjects haven\'t been published yet}} — it will appear here as soon as the teacher submits the marks.'**
  String exPendingNote(int count);

  /// No description provided for @exAbsentNote.
  ///
  /// In en, this message translates to:
  /// **'AB — absent for this paper.'**
  String get exAbsentNote;

  /// No description provided for @exNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get exNoResultsTitle;

  /// No description provided for @exNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Results appear here as teachers publish marks.'**
  String get exNoResultsBody;

  /// No description provided for @exNothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get exNothingScheduled;

  /// No description provided for @exOnNow.
  ///
  /// In en, this message translates to:
  /// **'On now · {exam}'**
  String exOnNow(String exam);

  /// No description provided for @exStartsIn.
  ///
  /// In en, this message translates to:
  /// **'{exam} · {when}'**
  String exStartsIn(String exam, String when);

  /// No description provided for @exLatestResult.
  ///
  /// In en, this message translates to:
  /// **'Latest: {exam}'**
  String exLatestResult(String exam);

  /// No description provided for @exYourChildTimetable.
  ///
  /// In en, this message translates to:
  /// **'{grade} timetable'**
  String exYourChildTimetable(String grade);

  /// No description provided for @exSeeResults.
  ///
  /// In en, this message translates to:
  /// **'See results'**
  String get exSeeResults;

  /// No description provided for @exDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get exDate;

  /// No description provided for @exTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get exTime;

  /// No description provided for @exGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get exGrade;

  /// No description provided for @exGraded.
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get exGraded;

  /// No description provided for @exOverallGrade.
  ///
  /// In en, this message translates to:
  /// **'Overall grade'**
  String get exOverallGrade;

  /// No description provided for @exGradeScale.
  ///
  /// In en, this message translates to:
  /// **'Grade scale'**
  String get exGradeScale;

  /// No description provided for @libBooksBorrowed.
  ///
  /// In en, this message translates to:
  /// **'Books borrowed'**
  String get libBooksBorrowed;

  /// No description provided for @libHoldingNow.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 book with {name} now} other{{count} books with {name} now}}'**
  String libHoldingNow(int count, String name);

  /// No description provided for @libAllReturned.
  ///
  /// In en, this message translates to:
  /// **'All returned — nothing borrowed now'**
  String get libAllReturned;

  /// No description provided for @libAttentionOverdue.
  ///
  /// In en, this message translates to:
  /// **'Attention required · overdue'**
  String get libAttentionOverdue;

  /// No description provided for @libAttentionDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Attention required · due soon'**
  String get libAttentionDueSoon;

  /// No description provided for @libBorrowedNow.
  ///
  /// In en, this message translates to:
  /// **'Borrowed now'**
  String get libBorrowedNow;

  /// No description provided for @libReturnedSection.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get libReturnedSection;

  /// No description provided for @libNoneNow.
  ///
  /// In en, this message translates to:
  /// **'Every library book has been returned.'**
  String get libNoneNow;

  /// No description provided for @libBookName.
  ///
  /// In en, this message translates to:
  /// **'Book name'**
  String get libBookName;

  /// No description provided for @libAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get libAuthor;

  /// No description provided for @libPublisher.
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get libPublisher;

  /// No description provided for @libBorrowedOn.
  ///
  /// In en, this message translates to:
  /// **'Borrowed on'**
  String get libBorrowedOn;

  /// No description provided for @libDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get libDueDate;

  /// No description provided for @libReturnedOn.
  ///
  /// In en, this message translates to:
  /// **'Returned on'**
  String get libReturnedOn;

  /// No description provided for @libDueIn.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String libDueIn(int days);

  /// No description provided for @libDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get libDueTomorrow;

  /// No description provided for @libDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get libDueToday;

  /// No description provided for @libOverdueBy.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Overdue by 1 day} other{Overdue by {days} days}}'**
  String libOverdueBy(int days);

  /// No description provided for @libReturnedChip.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get libReturnedChip;

  /// No description provided for @libOverdueNote.
  ///
  /// In en, this message translates to:
  /// **'Attention required — this book is past its due date. Please return it to the school library.'**
  String get libOverdueNote;

  /// No description provided for @libDueSoonNote.
  ///
  /// In en, this message translates to:
  /// **'Attention required — this book is due back soon.'**
  String get libDueSoonNote;

  /// No description provided for @libReturnAtDesk.
  ///
  /// In en, this message translates to:
  /// **'Books are borrowed and returned at the school library.'**
  String get libReturnAtDesk;

  /// No description provided for @libLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load library books. Pull down to try again.'**
  String get libLoadError;
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
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
