// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'பள்ளிகனெக்ட்';

  @override
  String get tabToday => 'இன்று';

  @override
  String get tabDiary => 'டைரி';

  @override
  String get tabMessages => 'செய்திகள்';

  @override
  String get tabProgress => 'முன்னேற்றம்';

  @override
  String get tabProfile => 'சுயவிவரம்';

  @override
  String get goodMorning => 'காலை வணக்கம்';

  @override
  String get goodAfternoon => 'மதிய வணக்கம்';

  @override
  String get goodEvening => 'மாலை வணக்கம்';

  @override
  String get switchStudent => 'மாணவரை மாற்று';

  @override
  String get addStudent => 'மாணவரைச் சேர்';

  @override
  String classSection(String className, String section) {
    return '$className-$section';
  }

  @override
  String get todaysOverview => 'இன்றைய பள்ளி சுருக்கம்';

  @override
  String schoolDayTitle(String name) {
    return '$name-இன் பள்ளி நாள்';
  }

  @override
  String get todayAtSchool => 'இன்று பள்ளியில்';

  @override
  String get todaysLearning => 'இன்றைய கற்றல்';

  @override
  String whatStudentLearned(String name) {
    return '$name கற்றவை';
  }

  @override
  String get homeworkStatus => 'வீட்டுப்பாட நிலை';

  @override
  String get todaysHighlight => 'இன்றைய சிறப்பு';

  @override
  String get teachersNote => 'ஆசிரியர் குறிப்பு';

  @override
  String get growingIn => 'வளர்ந்து வருபவை';

  @override
  String get todaysGrowth => 'இன்றைய வளர்ச்சி';

  @override
  String get homework => 'வீட்டுப்பாடம்';

  @override
  String get attendance => 'வருகை';

  @override
  String get updates => 'அறிவிப்புகள்';

  @override
  String pendingCount(int count) {
    return '$count நிலுவை';
  }

  @override
  String completedCount(int count) {
    return '$count முடிந்தது';
  }

  @override
  String newUpdatesCount(int count) {
    return '$count புதிய அறிவிப்புகள்';
  }

  @override
  String get present => 'வந்தார்';

  @override
  String get absent => 'வராத நாள்';

  @override
  String get leave => 'விடுப்பு';

  @override
  String get needsAttention => 'கவனம் தேவை';

  @override
  String get dueToday => 'இன்று கடைசி நாள்';

  @override
  String get overdue => 'தாமதம்';

  @override
  String get upcoming => 'வரவிருக்கும்';

  @override
  String get completed => 'முடிந்தது';

  @override
  String get dueTomorrow => 'நாளை கடைசி நாள்';

  @override
  String dueOnDate(String date) {
    return '$date அன்று கடைசி நாள்';
  }

  @override
  String dueInDays(int days) {
    return '$days நாட்களில் கடைசி நாள்';
  }

  @override
  String get markAsCompleted => 'முடிந்ததாக குறி';

  @override
  String get markedComplete => 'முடிந்தது';

  @override
  String homeworkProgress(int done, int total) {
    return '$total-இல் $done முடிந்தது';
  }

  @override
  String get filterAll => 'அனைத்தும்';

  @override
  String get filterPending => 'நிலுவை';

  @override
  String get filterCompleted => 'முடிந்தவை';

  @override
  String get noHomeworkTitle => 'நிலுவை வீட்டுப்பாடம் இல்லை';

  @override
  String get noHomeworkBody => 'இன்றைய நாளை மகிழ்ச்சியாக கழிக்கவும்.';

  @override
  String get noNotificationsTitle => 'அனைத்தும் பார்த்துவிட்டீர்கள்';

  @override
  String get noNotificationsBody => 'புதிய பள்ளி அறிவிப்புகள் இங்கே தோன்றும்.';

  @override
  String get noActivitiesTitle => 'செயல்பாடுகள் இன்னும் பதிவு செய்யப்படவில்லை';

  @override
  String get noActivitiesBody =>
      'பள்ளி சேர்க்கும் போது சாதனைகளும் நிகழ்வுகளும் இங்கே காட்டப்படும்.';

  @override
  String get searchDiary => 'டைரியில் தேடு';

  @override
  String get searchHint => 'அறிவியல், பெற்றோர் கூட்டம்…';

  @override
  String get teacherNotes => 'ஆசிரியர் குறிப்புகள்';

  @override
  String get schoolNotices => 'பள்ளி அறிவிப்புகள்';

  @override
  String get activities => 'செயல்பாடுகள்';

  @override
  String get noDiaryTitle => 'இந்த நாளில் பதிவு இல்லை';

  @override
  String get noDiaryBody =>
      'வீட்டுப்பாடம், குறிப்புகள், அறிவிப்புகள் வெளியிடப்படும்போது இங்கே தோன்றும்.';

  @override
  String get academics => 'கல்வி';

  @override
  String get homeworkPerformance => 'வீட்டுப்பாடம்';

  @override
  String get growth => 'வளர்ச்சி';

  @override
  String get academicYear => 'கல்வி ஆண்டு';

  @override
  String get averageLabel => 'சராசரி';

  @override
  String attendancePercent(int percent) {
    return '$percent% வருகை';
  }

  @override
  String get presentCount => 'வந்த நாட்கள்';

  @override
  String get absentCount => 'வராத நாட்கள்';

  @override
  String get leaveCount => 'விடுப்பு';

  @override
  String get attendanceWarning => 'வருகை கவனம் தேவை.';

  @override
  String get feeDue => 'கட்டணம் நிலுவை';

  @override
  String remainingAmount(String amount) {
    return '$amount மீதம்';
  }

  @override
  String get viewDetails => 'விவரங்களைப் பார்';

  @override
  String get tuitionFee => 'பள்ளிக் கட்டணம்';

  @override
  String get transportFee => 'போக்குவரத்துக் கட்டணம்';

  @override
  String get activityFee => 'செயல்பாட்டுக் கட்டணம்';

  @override
  String get otherFees => 'பிற கட்டணங்கள்';

  @override
  String get total => 'மொத்தம்';

  @override
  String get paid => 'செலுத்தியது';

  @override
  String get remainingBalance => 'மீதமுள்ள தொகை';

  @override
  String get paymentHistory => 'கட்டண வரலாறு';

  @override
  String get receipt => 'ரசீது';

  @override
  String get paymentSuccessful => 'வெற்றி';

  @override
  String get paymentPending => 'நிலுவை';

  @override
  String get paymentProcessing => 'செயல்பாட்டில்';

  @override
  String get paymentFailed => 'தோல்வி';

  @override
  String get digitalId => 'டிஜிட்டல் மாணவர் அட்டை';

  @override
  String get tapToOpenId => 'அட்டையைத் திறக்க தட்டவும்';

  @override
  String get admissionNo => 'சேர்க்கை எண்';

  @override
  String get rollNo => 'வகுப்பு எண்';

  @override
  String get notifications => 'அறிவிப்புகள்';

  @override
  String groupedUpdates(int count) {
    return '$count புதிய பள்ளி அறிவிப்புகள்';
  }

  @override
  String get unableToRefresh => 'இப்போது புதுப்பிக்க முடியவில்லை.';

  @override
  String get showingLastSynced =>
      'கடைசியாக ஒத்திசைக்கப்பட்ட தகவல் காட்டப்படுகிறது.';

  @override
  String get tryAgain => 'மீண்டும் முயற்சி';

  @override
  String lastUpdated(String time) {
    return 'புதுப்பிக்கப்பட்டது $time';
  }

  @override
  String get language => 'மொழி';

  @override
  String get english => 'ஆங்கிலம்';

  @override
  String get tamil => 'தமிழ்';

  @override
  String get schoolIdentity => 'பள்ளி';

  @override
  String get studentInformation => 'மாணவர் தகவல்';

  @override
  String get verifyQrHint => 'சரிபார்ப்பு குறியீடு';

  @override
  String get unitTests => 'யூனிட் தேர்வுகள்';

  @override
  String get quarterlyExams => 'காலாண்டுத் தேர்வுகள்';

  @override
  String get halfYearlyExams => 'அரையாண்டுத் தேர்வுகள்';

  @override
  String get annualExams => 'ஆண்டுத் தேர்வுகள்';

  @override
  String get subjectMarks => 'மதிப்பெண்கள்';

  @override
  String get teacherRemarks => 'ஆசிரியர் கருத்து';

  @override
  String get achievement => 'சாதனை';

  @override
  String get position => 'முடிவு';

  @override
  String get category => 'வகை';

  @override
  String get academicHistory => 'கல்வி வரலாறு';

  @override
  String get homeworkConsistency => 'வீட்டுப்பாடத் தொடர்ச்சி';

  @override
  String get teacherObservations => 'ஆசிரியர் கவனிப்புகள்';

  @override
  String get schoolAssessedSkills => 'பள்ளி மதிப்பீட்டுத் திறன்கள்';

  @override
  String get offlinePending => 'ஒத்திசைவு காத்திருக்கிறது';

  @override
  String get importantAnnouncement => 'முக்கிய அறிவிப்பு';

  @override
  String get parentMeeting => 'பெற்றோர் கூட்டம்';

  @override
  String get seeAllHomework => 'அனைத்து வீட்டுப்பாடமும்';

  @override
  String get calendar => 'நாட்காட்டி';

  @override
  String get todayLabel => 'இன்று';

  @override
  String get tabBusTracking => 'பேருந்து கண்காணிப்பு';

  @override
  String get etaToYourStop => 'உங்கள் நிறுத்தத்திற்கு வரவிருக்கும் நேரம்';

  @override
  String get nextStop => 'அடுத்த நிறுத்தம்';

  @override
  String get tripStarted => 'பயணம் தொடங்கியது';

  @override
  String get tripEnded => 'பயணம் முடிந்தது';

  @override
  String get vehicle => 'வாகனம்';

  @override
  String get yesterday => 'நேற்று';

  @override
  String get attachment => 'இணைப்பு';

  @override
  String get classTeacher => 'வகுப்பு ஆசிரியர்';

  @override
  String get selected => 'தேர்ந்தெடுக்கப்பட்டது';

  @override
  String percentValue(int value) {
    return '$value%';
  }

  @override
  String get idCardTitle => 'மாணவர் அடையாள அட்டை';

  @override
  String get bloodGroup => 'இரத்த வகை';

  @override
  String get validUntil => 'காலாவதி தேதி';

  @override
  String get academicDetails => 'கல்வி விவரங்கள்';

  @override
  String get schoolFees => 'பள்ளிக் கட்டணம்';

  @override
  String get totalFees => 'மொத்த கட்டணம்';

  @override
  String get amountPaid => 'செலுத்திய தொகை';

  @override
  String get amountDue => 'நிலுவைத் தொகை';

  @override
  String get payNow => 'கட்டணம் செலுத்து';

  @override
  String get feesPaid => 'கட்டணம் செலுத்தப்பட்டது';

  @override
  String get informLeave => 'விடுப்புத் தகவல்';

  @override
  String get informLate => 'தாமதத் தகவல்';

  @override
  String get requestLeave => 'விடுப்பு விண்ணப்பம்';

  @override
  String get leaveReason => 'விடுப்பிற்கான காரணம்';

  @override
  String get lateReason => 'தாமதத்திற்கான காரணம்';

  @override
  String get cancel => 'ரத்து';

  @override
  String get send => 'அனுப்பு';

  @override
  String get aboutMessagesTitle => 'செய்திகள் பற்றி';

  @override
  String get aboutMessagesContent =>
      'உங்கள் குழந்தையின் வகுப்பு ஆசிரியருடன் நேரடியாகத் தொடர்பு கொள்ளுங்கள். விடுப்பு விண்ணப்பிக்க அல்லது தாமதத்தைப் பற்றி தெரிவிக்க மேலே உள்ள விரைவான தேர்வுகளைப் பயன்படுத்தவும். அதிகாரப்பூர்வ ஆவணங்களையும் (2MB வரை) பதிவேற்றலாம்.';

  @override
  String get selectDocument => 'ஆவணத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get fileLimitHint => 'PDF, Word அல்லது படம் · அதிகபட்சம் 2MB';

  @override
  String get fileTooLarge => 'கோப்பு அளவு அதிகம். அதிகபட்ச அளவு 2MB.';

  @override
  String get uploadedDocument => 'ஆவணம் பதிவேற்றப்பட்டது.';

  @override
  String get typeMessage => 'செய்தி எழுதுங்கள்…';

  @override
  String get filePickFailed =>
      'கோப்பைத் தேர்ந்தெடுக்க முடியவில்லை. மீண்டும் முயலவும்.';

  @override
  String get messagesUnavailable =>
      'இப்போது செய்திகளை ஏற்ற முடியவில்லை. கீழே இழுத்து மீண்டும் முயலவும்.';

  @override
  String get messageSendFailed => 'செய்தி அனுப்பப்படவில்லை. மீண்டும் முயலவும்.';

  @override
  String get verifiedStudent => 'சரிபார்க்கப்பட்ட மாணவர்';

  @override
  String get duration => 'கால அளவு';

  @override
  String get daysLabel => 'நாட்கள்';

  @override
  String get close => 'மூடு';

  @override
  String get selectDate => 'தேதியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get fromDate => 'தொடங்கும் தேதி';

  @override
  String get toDate => 'முடிவடையும் தேதி';

  @override
  String get reasonHint => 'உதாரணம்: குடும்ப விழா, காய்ச்சல்...';

  @override
  String get submitRequest => 'விண்ணப்பிக்கவும்';

  @override
  String get pleaseSelectDate => 'தயவுசெய்து தேதியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get pleaseSelectDateRange => 'தயவுசெய்து தேதிகளைத் தேர்ந்தெடுக்கவும்';

  @override
  String studentTeacher(String name) {
    return '$name-இன் ஆசிரியர்';
  }

  @override
  String get underReview => 'மதிப்பாய்வில் உள்ளது';

  @override
  String get submittedForReview => 'மதிப்பாய்விற்கு சமர்ப்பிக்கப்பட்டது';

  @override
  String get cancelSubmission => 'சமர்ப்பிப்பை ரத்து செய்';

  @override
  String get assignedOn => 'ஒதுக்கப்பட்ட நாள்';

  @override
  String get instructions => 'அறிவுறுத்தல்கள்';

  @override
  String get dueOn => 'கடைசி நாள்';

  @override
  String get noPendingHomework => 'அனைத்தும் முடிந்துவிட்டது!';

  @override
  String get noReviewHomework => 'மதிப்பாய்வில் வீட்டுப்பாடம் எதுவுமில்லை';

  @override
  String get noCompletedHomework =>
      'உங்கள் முடிந்த வீட்டுப்பாடங்கள் இங்கே தோன்றும்';

  @override
  String get stars => 'நட்சத்திரங்கள்';

  @override
  String get starsEarned => 'பெற்ற நட்சத்திரங்கள்';

  @override
  String starsThisWeek(int count) {
    return 'இந்த வாரம் +$count';
  }

  @override
  String starFrom(String teacher) {
    return '$teacher வழங்கியது';
  }

  @override
  String get noStarsTitle => 'இன்னும் நட்சத்திரங்கள் இல்லை';

  @override
  String get noStarsBody =>
      'உங்கள் குழந்தை நல்ல செயல் செய்யும்போது — அன்பு, சிறந்த வேலை, தலைமைப் பண்பு — ஆசிரியர்கள் நட்சத்திரம் வழங்குவார்கள். அவை இங்கே தோன்றும்.';

  @override
  String get starsTapHint => 'எதற்காகப் பெற்றார் எனப் பாருங்கள்';

  @override
  String get skills => 'திறன்கள்';

  @override
  String get seeAll => 'அனைத்தும்';

  @override
  String get latestExam => 'சமீபத்திய தேர்வு';

  @override
  String get noMarksYet => 'இன்னும் மதிப்பெண்கள் இல்லை';

  @override
  String get growthEmptyTitle => 'இன்னும் எதுவும் பதிவு செய்யப்படவில்லை';

  @override
  String get growthEmptyBody =>
      'ஆசிரியர் குறிப்புகளும் திறன் மதிப்பீடுகளும் இங்கே தோன்றும்.';

  @override
  String get skillLevelEmerging => 'தொடக்க நிலை';

  @override
  String get skillLevelDeveloping => 'வளர்ந்து வருகிறது';

  @override
  String get skillLevelProficient => 'திறமையானவர்';

  @override
  String get skillLevelAdvanced => 'மேம்பட்ட நிலை';

  @override
  String get skillScaleHint =>
      'தொடக்க நிலை → வளர்ந்து வருகிறது → திறமையானவர் → மேம்பட்ட நிலை';

  @override
  String get schoolLife => 'பள்ளி வாழ்க்கை';

  @override
  String get timetable => 'கால அட்டவணை';

  @override
  String get events => 'நிகழ்வுகள்';

  @override
  String get schoolBus => 'பள்ளிப் பேருந்து';

  @override
  String newCount(int count) {
    return '$count புதியவை';
  }

  @override
  String get progressEmptyHint =>
      'ஆசிரியர்கள் நட்சத்திரங்கள், செயல்பாடுகள், குறிப்புகளைப் பதிவு செய்யும்போது உங்கள் குழந்தையின் முன்னேற்றம் இங்கே தெரியும்.';

  @override
  String recordedBy(String teacher) {
    return '$teacher பதிவு செய்தது';
  }

  @override
  String get classLabelTitle => 'வகுப்பு';

  @override
  String get signOut => 'வெளியேறு';

  @override
  String get signOutConfirmTitle => 'வெளியேற வேண்டுமா?';

  @override
  String get signOutConfirmBody =>
      'மீண்டும் உள்நுழைய பதிவு எண்ணும் கடவுச்சொல்லும் தேவைப்படும்.';

  @override
  String get examSchedule => 'தேர்வு அட்டவணை';

  @override
  String get reportCards => 'மதிப்பெண் அட்டைகள்';

  @override
  String get examOngoing => 'நடைபெறுகிறது';

  @override
  String get examUpcoming => 'வரவிருக்கிறது';

  @override
  String get noMarksTitle => 'இன்னும் மதிப்பெண்கள் இல்லை';

  @override
  String get noMarksBody =>
      'ஆசிரியர்கள் மதிப்பெண்களைப் பதிவு செய்தவுடன் இங்கே தோன்றும்.';

  @override
  String get noAttendanceTitle => 'இன்னும் வருகைப் பதிவு இல்லை';

  @override
  String get noAttendanceBody =>
      'வகுப்பு ஆசிரியர் வருகையைப் பதிவு செய்யத் தொடங்கியதும் இங்கே தெரியும்.';

  @override
  String get previousMonth => 'முந்தைய மாதம்';

  @override
  String get nextMonth => 'அடுத்த மாதம்';

  @override
  String get timetableNoneTitle => 'இன்னும் கால அட்டவணை இல்லை';

  @override
  String get timetableNoneBody =>
      'இந்த வகுப்பின் கால அட்டவணையை பள்ளி இன்னும் வெளியிடவில்லை.';

  @override
  String get timetableErrorTitle => 'கால அட்டவணையை ஏற்ற முடியவில்லை';

  @override
  String get timetableErrorBody =>
      'இணைய இணைப்பைச் சரிபார்த்து மீண்டும் முயலவும்.';

  @override
  String noClassesOnDay(String day) {
    return '$day அன்று வகுப்புகள் இல்லை';
  }

  @override
  String periodsCount(int count) {
    return '$count பாட வேளைகள்';
  }

  @override
  String get periodNow => 'இப்போது';

  @override
  String get periodNext => 'அடுத்து';

  @override
  String get periodCover => 'மாற்று ஆசிரியர்';

  @override
  String get todaysPeriods => 'இன்றைய வகுப்புகள்';

  @override
  String get fullWeek => 'முழு வாரம்';

  @override
  String get schoolDayOver => 'இன்றைய பள்ளி நேரம் முடிந்தது';

  @override
  String minutesShort(int count) {
    return '$count நிமி';
  }

  @override
  String get tomorrowLabel => 'நாளை';

  @override
  String get pickDates => 'தேதிகளைத் தேர்வு செய்க';

  @override
  String get whenLabel => 'எப்போது?';

  @override
  String get whyLabel => 'காரணம்?';

  @override
  String get reasonUnwell => 'காய்ச்சல் / உடல்நலக் குறைவு';

  @override
  String get reasonDoctor => 'மருத்துவர் சந்திப்பு';

  @override
  String get reasonFamily => 'குடும்ப நிகழ்ச்சி';

  @override
  String get reasonTravel => 'பயணம்';

  @override
  String get reasonOther => 'மற்றவை';

  @override
  String get addNoteOptional => 'ஆசிரியருக்கு குறிப்பு சேர்க்கவும் (விருப்பம்)';

  @override
  String get describeReason => 'காரணத்தை ஆசிரியரிடம் கூறுங்கள்';

  @override
  String leaveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count நாட்கள்',
      one: '1 நாள்',
    );
    return '$_temp0';
  }

  @override
  String get appTagline => 'உங்கள் குழந்தையின் பயணம், இணைக்கப்பட்டது';

  @override
  String get parentLogin => 'பெற்றோர் உள்நுழைவு';

  @override
  String get parentLoginHelp =>
      'பள்ளி வழங்கிய பதிவு எண்ணையும் கடவுச்சொல்லையும் பயன்படுத்துங்கள்.';

  @override
  String get registerNumber => 'பதிவு எண்';

  @override
  String get passwordLabel => 'கடவுச்சொல்';

  @override
  String get loginButton => 'உள்நுழைக';

  @override
  String get signingIn => 'உள்நுழைகிறது…';

  @override
  String get enterRegisterAndPassword =>
      'பதிவு எண்ணையும் கடவுச்சொல்லையும் உள்ளிடவும்.';

  @override
  String get showPassword => 'கடவுச்சொல்லைக் காட்டு';

  @override
  String get hidePassword => 'கடவுச்சொல்லை மறை';

  @override
  String get exExams => 'தேர்வுகள்';

  @override
  String get exResults => 'முடிவுகள்';

  @override
  String get exUpcoming => 'வரவிருக்கும்';

  @override
  String get exOngoing => 'நடைபெறுகிறது';

  @override
  String get exCompleted => 'முடிந்தவை';

  @override
  String get exNoExamsTitle => 'இங்கே தேர்வுகள் இல்லை';

  @override
  String get exNoExamsBody =>
      'பள்ளி வெளியிட்டவுடன் தேர்வு அட்டவணைகள் இங்கே தோன்றும்.';

  @override
  String get exToday => 'இன்று';

  @override
  String get exTomorrow => 'நாளை';

  @override
  String exInDays(int count) {
    return '$count நாட்களில்';
  }

  @override
  String get exDone => 'முடிந்தது';

  @override
  String exNext(String subject, String when) {
    return 'அடுத்தது: $subject · $when';
  }

  @override
  String exSubjectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count பாடங்கள்',
      one: '1 பாடம்',
    );
    return '$_temp0';
  }

  @override
  String get exTimetable => 'அட்டவணை';

  @override
  String get exTapForSyllabus =>
      'பாடத்திட்டத்தைப் பார்க்க ஒரு பாடத்தைத் தட்டவும்.';

  @override
  String get exSyllabus => 'பாடத்திட்டம்';

  @override
  String get exNoSyllabus => 'பாடத்திட்டம் சேர்க்கப்படவில்லை.';

  @override
  String exOutOf(String max) {
    return 'மொத்தம் $max';
  }

  @override
  String exPassMark(String pass) {
    return 'தேர்ச்சி மதிப்பெண் $pass';
  }

  @override
  String exResultsOut(int released, int total) {
    return '$total பாடங்களில் $released வெளியானது';
  }

  @override
  String get exResultsNotOut => 'முடிவுகள் இன்னும் வெளியாகவில்லை';

  @override
  String get exAllResultsOut => 'அனைத்து முடிவுகளும் வெளியானது';

  @override
  String get exStatementOfMarks => 'மதிப்பெண் பட்டியல்';

  @override
  String get exStudentName => 'பெயர்';

  @override
  String get exRegisterNo => 'பதிவு எண்';

  @override
  String get exClassSection => 'வகுப்பு & பிரிவு';

  @override
  String get exRollNo => 'வரிசை எண்';

  @override
  String get exSNo => 'வ.எண்';

  @override
  String get exSubject => 'பாடம்';

  @override
  String get exMax => 'மொத்தம்';

  @override
  String get exPass => 'தேர்ச்சி';

  @override
  String get exMarks => 'மதிப்பெண்';

  @override
  String get exResult => 'முடிவு';

  @override
  String get exResultPass => 'தேர்ச்சி';

  @override
  String get exResultFail => 'தோல்வி';

  @override
  String get exAbsent => 'AB';

  @override
  String get exTotal => 'மொத்தம்';

  @override
  String get exPercentage => 'சதவீதம்';

  @override
  String get exOverall => 'ஒட்டுமொத்த முடிவு';

  @override
  String get exAwaited => 'காத்திருப்பு';

  @override
  String exPendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count பாடங்கள் இன்னும் வெளியிடப்படவில்லை',
      one: '1 பாடம் இன்னும் வெளியிடப்படவில்லை',
    );
    return '$_temp0 — ஆசிரியர் மதிப்பெண்களைச் சமர்ப்பித்தவுடன் இங்கே தோன்றும்.';
  }

  @override
  String get exAbsentNote => 'AB — இந்தத் தேர்வுக்கு வரவில்லை.';

  @override
  String get exNoResultsTitle => 'இன்னும் முடிவுகள் இல்லை';

  @override
  String get exNoResultsBody =>
      'ஆசிரியர்கள் மதிப்பெண்களை வெளியிடும்போது முடிவுகள் இங்கே தோன்றும்.';

  @override
  String get exNothingScheduled => 'எதுவும் திட்டமிடப்படவில்லை';

  @override
  String exOnNow(String exam) {
    return 'இப்போது · $exam';
  }

  @override
  String exStartsIn(String exam, String when) {
    return '$exam · $when';
  }

  @override
  String exLatestResult(String exam) {
    return 'சமீபத்தியது: $exam';
  }

  @override
  String exYourChildTimetable(String grade) {
    return '$grade அட்டவணை';
  }

  @override
  String get exSeeResults => 'முடிவுகளைப் பார்';

  @override
  String get exDate => 'தேதி';

  @override
  String get exTime => 'நேரம்';

  @override
  String get exGrade => 'தரம்';

  @override
  String get exGraded => 'தரம் வழங்கப்படும்';

  @override
  String get exOverallGrade => 'ஒட்டுமொத்த தரம்';

  @override
  String get exGradeScale => 'தர அளவு';

  @override
  String get libBooksBorrowed => 'கடன் வாங்கிய புத்தகங்கள்';

  @override
  String libHoldingNow(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name இடம் இப்போது $count புத்தகங்கள்',
      one: '$name இடம் இப்போது 1 புத்தகம்',
    );
    return '$_temp0';
  }

  @override
  String get libAllReturned =>
      'அனைத்தும் திருப்பி அளிக்கப்பட்டன — இப்போது எதுவும் இல்லை';

  @override
  String get libAttentionOverdue => 'கவனம் தேவை · காலக்கெடு கடந்தது';

  @override
  String get libAttentionDueSoon =>
      'கவனம் தேவை · விரைவில் திருப்பித் தர வேண்டும்';

  @override
  String get libBorrowedNow => 'தற்போது கடன் வாங்கியவை';

  @override
  String get libReturnedSection => 'திருப்பி அளிக்கப்பட்டவை';

  @override
  String get libNoneNow =>
      'நூலகப் புத்தகங்கள் அனைத்தும் திருப்பி அளிக்கப்பட்டன.';

  @override
  String get libBookName => 'புத்தகத்தின் பெயர்';

  @override
  String get libAuthor => 'நூலாசிரியர்';

  @override
  String get libPublisher => 'பதிப்பகம்';

  @override
  String get libBorrowedOn => 'கடன் வாங்கிய தேதி';

  @override
  String get libDueDate => 'திருப்பித் தர வேண்டிய தேதி';

  @override
  String get libReturnedOn => 'திருப்பி அளித்த தேதி';

  @override
  String libDueIn(int days) {
    return '$days நாட்களில் திருப்பித் தர வேண்டும்';
  }

  @override
  String get libDueTomorrow => 'நாளை திருப்பித் தர வேண்டும்';

  @override
  String get libDueToday => 'இன்று திருப்பித் தர வேண்டும்';

  @override
  String libOverdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days நாட்கள் தாமதம்',
      one: '1 நாள் தாமதம்',
    );
    return '$_temp0';
  }

  @override
  String get libReturnedChip => 'திருப்பி அளிக்கப்பட்டது';

  @override
  String get libOverdueNote =>
      'கவனம் தேவை — இந்தப் புத்தகத்தின் காலக்கெடு கடந்துவிட்டது. தயவுசெய்து பள்ளி நூலகத்தில் திருப்பி அளிக்கவும்.';

  @override
  String get libDueSoonNote =>
      'கவனம் தேவை — இந்தப் புத்தகத்தை விரைவில் திருப்பித் தர வேண்டும்.';

  @override
  String get libReturnAtDesk =>
      'புத்தகங்கள் பள்ளி நூலகத்தில் வழங்கப்பட்டு, அங்கேயே திருப்பிப் பெறப்படும்.';

  @override
  String get libLoadError =>
      'நூலகப் புத்தகங்களை ஏற்ற முடியவில்லை. மீண்டும் முயல கீழே இழுக்கவும்.';
}
