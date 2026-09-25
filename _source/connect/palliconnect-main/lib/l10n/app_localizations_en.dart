// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PalliConnect';

  @override
  String get tabToday => 'Today';

  @override
  String get tabDiary => 'Diary';

  @override
  String get tabMessages => 'Messages';

  @override
  String get tabProgress => 'Progress';

  @override
  String get tabProfile => 'Profile';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get switchStudent => 'Switch student';

  @override
  String get addStudent => 'Add student';

  @override
  String classSection(String className, String section) {
    return '$className-$section';
  }

  @override
  String get todaysOverview => 'Today\'s school overview';

  @override
  String schoolDayTitle(String name) {
    return '$name\'s School Day';
  }

  @override
  String get todayAtSchool => 'Today at school';

  @override
  String get todaysLearning => 'Today’s Learning';

  @override
  String whatStudentLearned(String name) {
    return 'What $name learned';
  }

  @override
  String get homeworkStatus => 'Homework Status';

  @override
  String get todaysHighlight => 'Today’s Highlight';

  @override
  String get teachersNote => 'Teacher’s note';

  @override
  String get growingIn => 'Growing In';

  @override
  String get todaysGrowth => 'Today’s growth';

  @override
  String get homework => 'Homework';

  @override
  String get attendance => 'Attendance';

  @override
  String get updates => 'Updates';

  @override
  String pendingCount(int count) {
    return '$count pending';
  }

  @override
  String completedCount(int count) {
    return '$count completed';
  }

  @override
  String newUpdatesCount(int count) {
    return '$count new updates';
  }

  @override
  String get present => 'Present';

  @override
  String get absent => 'Absent';

  @override
  String get leave => 'Leave';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get dueToday => 'Due today';

  @override
  String get overdue => 'Overdue';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get completed => 'Completed';

  @override
  String get dueTomorrow => 'Due tomorrow';

  @override
  String dueOnDate(String date) {
    return 'Due $date';
  }

  @override
  String dueInDays(int days) {
    return 'Due in $days days';
  }

  @override
  String get markAsCompleted => 'Mark as completed';

  @override
  String get markedComplete => 'Completed';

  @override
  String homeworkProgress(int done, int total) {
    return '$done of $total completed';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterPending => 'Pending';

  @override
  String get filterCompleted => 'Completed';

  @override
  String get noHomeworkTitle => 'No homework pending';

  @override
  String get noHomeworkBody => 'Enjoy your day.';

  @override
  String get noNotificationsTitle => 'You\'re all caught up';

  @override
  String get noNotificationsBody => 'New school updates will appear here.';

  @override
  String get noActivitiesTitle => 'No activities recorded yet';

  @override
  String get noActivitiesBody =>
      'Achievements and events will show here when the school adds them.';

  @override
  String get searchDiary => 'Search diary';

  @override
  String get searchHint => 'Science, parent meeting…';

  @override
  String get teacherNotes => 'Teacher notes';

  @override
  String get schoolNotices => 'School notices';

  @override
  String get activities => 'Activities';

  @override
  String get noDiaryTitle => 'Nothing recorded this day';

  @override
  String get noDiaryBody =>
      'Homework, notes, and notices will appear here when published.';

  @override
  String get academics => 'Academics';

  @override
  String get homeworkPerformance => 'Homework';

  @override
  String get growth => 'Growth';

  @override
  String get academicYear => 'Academic year';

  @override
  String get averageLabel => 'Average';

  @override
  String attendancePercent(int percent) {
    return '$percent% attendance';
  }

  @override
  String get presentCount => 'Present';

  @override
  String get absentCount => 'Absent';

  @override
  String get leaveCount => 'Leave';

  @override
  String get attendanceWarning => 'Attendance requires attention.';

  @override
  String get feeDue => 'Fee due';

  @override
  String remainingAmount(String amount) {
    return '$amount remaining';
  }

  @override
  String get viewDetails => 'View details';

  @override
  String get tuitionFee => 'Tuition fee';

  @override
  String get transportFee => 'Transport fee';

  @override
  String get activityFee => 'Activity fee';

  @override
  String get otherFees => 'Other fees';

  @override
  String get total => 'Total';

  @override
  String get paid => 'Paid';

  @override
  String get remainingBalance => 'Remaining balance';

  @override
  String get paymentHistory => 'Payment history';

  @override
  String get receipt => 'Receipt';

  @override
  String get paymentSuccessful => 'Successful';

  @override
  String get paymentPending => 'Pending';

  @override
  String get paymentProcessing => 'Processing';

  @override
  String get paymentFailed => 'Failed';

  @override
  String get digitalId => 'Digital student ID';

  @override
  String get tapToOpenId => 'Tap to open ID card';

  @override
  String get admissionNo => 'Admission no.';

  @override
  String get rollNo => 'Roll no.';

  @override
  String get notifications => 'Notifications';

  @override
  String groupedUpdates(int count) {
    return '$count new school updates';
  }

  @override
  String get unableToRefresh => 'Unable to refresh right now.';

  @override
  String get showingLastSynced => 'Showing your last synced information.';

  @override
  String get tryAgain => 'Try again';

  @override
  String lastUpdated(String time) {
    return 'Updated $time';
  }

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get tamil => 'Tamil';

  @override
  String get schoolIdentity => 'School';

  @override
  String get studentInformation => 'Student information';

  @override
  String get verifyQrHint => 'Verification code';

  @override
  String get unitTests => 'Unit tests';

  @override
  String get quarterlyExams => 'Quarterly exams';

  @override
  String get halfYearlyExams => 'Half-yearly exams';

  @override
  String get annualExams => 'Annual exams';

  @override
  String get subjectMarks => 'Marks';

  @override
  String get teacherRemarks => 'Teacher remarks';

  @override
  String get achievement => 'Achievement';

  @override
  String get position => 'Result';

  @override
  String get category => 'Category';

  @override
  String get academicHistory => 'Academic history';

  @override
  String get homeworkConsistency => 'Homework consistency';

  @override
  String get teacherObservations => 'Teacher observations';

  @override
  String get schoolAssessedSkills => 'School-assessed skills';

  @override
  String get offlinePending => 'Waiting to sync';

  @override
  String get importantAnnouncement => 'Important announcement';

  @override
  String get parentMeeting => 'Parent meeting';

  @override
  String get seeAllHomework => 'See all homework';

  @override
  String get calendar => 'Calendar';

  @override
  String get todayLabel => 'Today';

  @override
  String get tabBusTracking => 'Bus Tracking';

  @override
  String get etaToYourStop => 'ETA to your stop';

  @override
  String get nextStop => 'Next Stop';

  @override
  String get tripStarted => 'Trip Started';

  @override
  String get tripEnded => 'Trip Ended';

  @override
  String get vehicle => 'Vehicle';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get attachment => 'Attachment';

  @override
  String get classTeacher => 'Class teacher';

  @override
  String get selected => 'Selected';

  @override
  String percentValue(int value) {
    return '$value%';
  }

  @override
  String get idCardTitle => 'STUDENT IDENTITY CARD';

  @override
  String get bloodGroup => 'Blood group';

  @override
  String get validUntil => 'Valid until';

  @override
  String get academicDetails => 'Academic details';

  @override
  String get schoolFees => 'School Fees';

  @override
  String get totalFees => 'Total Fees';

  @override
  String get amountPaid => 'Amount Paid';

  @override
  String get amountDue => 'Amount Due';

  @override
  String get payNow => 'Pay Now';

  @override
  String get feesPaid => 'Fees Paid';

  @override
  String get informLeave => 'Inform Leave';

  @override
  String get informLate => 'Inform Late';

  @override
  String get requestLeave => 'Request Leave';

  @override
  String get leaveReason => 'Reason for leave';

  @override
  String get lateReason => 'Reason for delay';

  @override
  String get cancel => 'Cancel';

  @override
  String get send => 'Send';

  @override
  String get aboutMessagesTitle => 'About Messages';

  @override
  String get aboutMessagesContent =>
      'Connect directly with your child\'s class teacher. Use quick actions at the top to request leave or inform the school about delays. You can also upload documents (up to 2MB) for official records.';

  @override
  String get selectDocument => 'Select a document';

  @override
  String get fileLimitHint => 'PDF, Word, or image · max 2MB';

  @override
  String get fileTooLarge => 'File too large. Max limit is 2MB.';

  @override
  String get uploadedDocument => 'Uploaded a document.';

  @override
  String get typeMessage => 'Write a message…';

  @override
  String get filePickFailed =>
      'Couldn’t open the file picker. Please try again.';

  @override
  String get messagesUnavailable =>
      'Couldn\'t load messages right now. Pull down to try again.';

  @override
  String get messageSendFailed => 'Message didn\'t send. Please try again.';

  @override
  String get verifiedStudent => 'Verified Student';

  @override
  String get duration => 'Duration';

  @override
  String get daysLabel => 'days';

  @override
  String get close => 'Close';

  @override
  String get selectDate => 'Select Date';

  @override
  String get fromDate => 'From';

  @override
  String get toDate => 'To';

  @override
  String get reasonHint => 'e.g. Family function, fever...';

  @override
  String get submitRequest => 'Submit Request';

  @override
  String get pleaseSelectDate => 'Please select a date';

  @override
  String get pleaseSelectDateRange => 'Please select date range';

  @override
  String studentTeacher(String name) {
    return '$name\'s Teacher';
  }

  @override
  String get underReview => 'Under Review';

  @override
  String get submittedForReview => 'Submitted for review';

  @override
  String get cancelSubmission => 'Cancel submission';

  @override
  String get assignedOn => 'Assigned on';

  @override
  String get instructions => 'Instructions';

  @override
  String get dueOn => 'Due on';

  @override
  String get noPendingHomework => 'All caught up!';

  @override
  String get noReviewHomework => 'No homework under review';

  @override
  String get noCompletedHomework => 'Your completed homework will appear here';

  @override
  String get stars => 'Stars';

  @override
  String get starsEarned => 'Stars earned';

  @override
  String starsThisWeek(int count) {
    return '+$count this week';
  }

  @override
  String starFrom(String teacher) {
    return 'from $teacher';
  }

  @override
  String get noStarsTitle => 'No stars yet';

  @override
  String get noStarsBody =>
      'Teachers give stars when your child does something good — kindness, great work, leadership. They\'ll show up here.';

  @override
  String get starsTapHint => 'See why they were earned';

  @override
  String get skills => 'Skills';

  @override
  String get seeAll => 'See all';

  @override
  String get latestExam => 'Latest exam';

  @override
  String get noMarksYet => 'No marks yet';

  @override
  String get growthEmptyTitle => 'Nothing recorded yet';

  @override
  String get growthEmptyBody =>
      'Notes from teachers and skill ratings will appear here.';

  @override
  String get skillLevelEmerging => 'Emerging';

  @override
  String get skillLevelDeveloping => 'Developing';

  @override
  String get skillLevelProficient => 'Proficient';

  @override
  String get skillLevelAdvanced => 'Advanced';

  @override
  String get skillScaleHint => 'Emerging → Developing → Proficient → Advanced';

  @override
  String get schoolLife => 'School life';

  @override
  String get timetable => 'Timetable';

  @override
  String get events => 'Events';

  @override
  String get schoolBus => 'School bus';

  @override
  String newCount(int count) {
    return '$count new';
  }

  @override
  String get progressEmptyHint =>
      'As teachers record stars, activities and notes, your child\'s progress builds up here.';

  @override
  String recordedBy(String teacher) {
    return 'By $teacher';
  }

  @override
  String get classLabelTitle => 'Class';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'You\'ll need the register number and password to sign in again.';

  @override
  String get examSchedule => 'Exam schedule';

  @override
  String get reportCards => 'Report cards';

  @override
  String get examOngoing => 'Ongoing';

  @override
  String get examUpcoming => 'Upcoming';

  @override
  String get noMarksTitle => 'No marks yet';

  @override
  String get noMarksBody =>
      'Test and exam results will appear here as soon as teachers enter them.';

  @override
  String get noAttendanceTitle => 'No attendance yet';

  @override
  String get noAttendanceBody =>
      'Daily attendance will show here once the class teacher starts marking it.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get timetableNoneTitle => 'No timetable yet';

  @override
  String get timetableNoneBody =>
      'The school hasn\'t published this class\'s schedule yet.';

  @override
  String get timetableErrorTitle => 'Couldn\'t load the timetable';

  @override
  String get timetableErrorBody =>
      'Check your internet connection and try again.';

  @override
  String noClassesOnDay(String day) {
    return 'No classes on $day';
  }

  @override
  String periodsCount(int count) {
    return '$count periods';
  }

  @override
  String get periodNow => 'Now';

  @override
  String get periodNext => 'Next';

  @override
  String get periodCover => 'Cover';

  @override
  String get todaysPeriods => 'Today\'s classes';

  @override
  String get fullWeek => 'Full week';

  @override
  String get schoolDayOver => 'School day is over';

  @override
  String minutesShort(int count) {
    return '$count min';
  }

  @override
  String get tomorrowLabel => 'Tomorrow';

  @override
  String get pickDates => 'Pick dates';

  @override
  String get whenLabel => 'When?';

  @override
  String get whyLabel => 'Why?';

  @override
  String get reasonUnwell => 'Fever / unwell';

  @override
  String get reasonDoctor => 'Doctor visit';

  @override
  String get reasonFamily => 'Family function';

  @override
  String get reasonTravel => 'Travelling';

  @override
  String get reasonOther => 'Other';

  @override
  String get addNoteOptional => 'Add a note for the teacher (optional)';

  @override
  String get describeReason => 'Tell the teacher the reason';

  @override
  String leaveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get appTagline => 'Your child\'s journey, connected';

  @override
  String get parentLogin => 'Parent login';

  @override
  String get parentLoginHelp =>
      'Use the register number and password issued by your school.';

  @override
  String get registerNumber => 'Register number';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'Log in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get enterRegisterAndPassword =>
      'Enter the register number and password.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get exExams => 'Exams';

  @override
  String get exResults => 'Results';

  @override
  String get exUpcoming => 'Upcoming';

  @override
  String get exOngoing => 'Ongoing';

  @override
  String get exCompleted => 'Completed';

  @override
  String get exNoExamsTitle => 'No exams here';

  @override
  String get exNoExamsBody =>
      'Exam timetables appear here as soon as the school publishes them.';

  @override
  String get exToday => 'Today';

  @override
  String get exTomorrow => 'Tomorrow';

  @override
  String exInDays(int count) {
    return 'In $count days';
  }

  @override
  String get exDone => 'Done';

  @override
  String exNext(String subject, String when) {
    return 'Next: $subject · $when';
  }

  @override
  String exSubjectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subjects',
      one: '1 subject',
    );
    return '$_temp0';
  }

  @override
  String get exTimetable => 'Timetable';

  @override
  String get exTapForSyllabus => 'Tap a subject to see its syllabus.';

  @override
  String get exSyllabus => 'Syllabus';

  @override
  String get exNoSyllabus => 'No syllabus added.';

  @override
  String exOutOf(String max) {
    return 'Out of $max';
  }

  @override
  String exPassMark(String pass) {
    return 'Pass mark $pass';
  }

  @override
  String exResultsOut(int released, int total) {
    return '$released of $total subjects out';
  }

  @override
  String get exResultsNotOut => 'Results not out yet';

  @override
  String get exAllResultsOut => 'All results are out';

  @override
  String get exStatementOfMarks => 'Statement of marks';

  @override
  String get exStudentName => 'Name';

  @override
  String get exRegisterNo => 'Register no.';

  @override
  String get exClassSection => 'Class & section';

  @override
  String get exRollNo => 'Roll no.';

  @override
  String get exSNo => 'S.No';

  @override
  String get exSubject => 'Subject';

  @override
  String get exMax => 'Max';

  @override
  String get exPass => 'Pass';

  @override
  String get exMarks => 'Marks';

  @override
  String get exResult => 'Result';

  @override
  String get exResultPass => 'PASS';

  @override
  String get exResultFail => 'FAIL';

  @override
  String get exAbsent => 'AB';

  @override
  String get exTotal => 'Total';

  @override
  String get exPercentage => 'Percentage';

  @override
  String get exOverall => 'Overall result';

  @override
  String get exAwaited => 'Awaited';

  @override
  String exPendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subjects haven\'t been published yet',
      one: '1 subject hasn\'t been published yet',
    );
    return '$_temp0 — it will appear here as soon as the teacher submits the marks.';
  }

  @override
  String get exAbsentNote => 'AB — absent for this paper.';

  @override
  String get exNoResultsTitle => 'No results yet';

  @override
  String get exNoResultsBody =>
      'Results appear here as teachers publish marks.';

  @override
  String get exNothingScheduled => 'Nothing scheduled';

  @override
  String exOnNow(String exam) {
    return 'On now · $exam';
  }

  @override
  String exStartsIn(String exam, String when) {
    return '$exam · $when';
  }

  @override
  String exLatestResult(String exam) {
    return 'Latest: $exam';
  }

  @override
  String exYourChildTimetable(String grade) {
    return '$grade timetable';
  }

  @override
  String get exSeeResults => 'See results';

  @override
  String get exDate => 'Date';

  @override
  String get exTime => 'Time';

  @override
  String get exGrade => 'Grade';

  @override
  String get exGraded => 'Graded';

  @override
  String get exOverallGrade => 'Overall grade';

  @override
  String get exGradeScale => 'Grade scale';

  @override
  String get libBooksBorrowed => 'Books borrowed';

  @override
  String libHoldingNow(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books with $name now',
      one: '1 book with $name now',
    );
    return '$_temp0';
  }

  @override
  String get libAllReturned => 'All returned — nothing borrowed now';

  @override
  String get libAttentionOverdue => 'Attention required · overdue';

  @override
  String get libAttentionDueSoon => 'Attention required · due soon';

  @override
  String get libBorrowedNow => 'Borrowed now';

  @override
  String get libReturnedSection => 'Returned';

  @override
  String get libNoneNow => 'Every library book has been returned.';

  @override
  String get libBookName => 'Book name';

  @override
  String get libAuthor => 'Author';

  @override
  String get libPublisher => 'Publisher';

  @override
  String get libBorrowedOn => 'Borrowed on';

  @override
  String get libDueDate => 'Due date';

  @override
  String get libReturnedOn => 'Returned on';

  @override
  String libDueIn(int days) {
    return 'Due in $days days';
  }

  @override
  String get libDueTomorrow => 'Due tomorrow';

  @override
  String get libDueToday => 'Due today';

  @override
  String libOverdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue by $days days',
      one: 'Overdue by 1 day',
    );
    return '$_temp0';
  }

  @override
  String get libReturnedChip => 'Returned';

  @override
  String get libOverdueNote =>
      'Attention required — this book is past its due date. Please return it to the school library.';

  @override
  String get libDueSoonNote =>
      'Attention required — this book is due back soon.';

  @override
  String get libReturnAtDesk =>
      'Books are borrowed and returned at the school library.';

  @override
  String get libLoadError =>
      'Couldn\'t load library books. Pull down to try again.';
}
