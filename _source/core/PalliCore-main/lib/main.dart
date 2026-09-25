import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_admin_classroom/feature_admin_classroom.dart';
import 'package:feature_admin_timetable/feature_admin_timetable.dart';
import 'package:feature_admin_directory/feature_admin_directory.dart';
import 'package:feature_announcements/feature_announcements.dart';
import 'package:feature_bus_tracking/feature_bus_tracking.dart';
import 'package:feature_teacher_dashboard/feature_teacher_dashboard.dart';
import 'package:feature_teacher_tools/feature_teacher_tools.dart';
import 'package:feature_admin_events/feature_admin_events.dart';
import 'package:feature_admin_fees/feature_admin_fees.dart';
import 'package:feature_admin_ops/feature_admin_ops.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dependency_injection.dart';
import 'router.dart';
import 'splash_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // splashMinDurationNotifier flips when the splash entrance finishes (see
  // splash_screen.dart), so the route never leaves it mid-animation. This
  // fallback only guards against the splash never getting to animate.
  Future.delayed(const Duration(seconds: 5), () => splashMinDurationNotifier.value = true);

  await dotenv.load(fileName: ".env");

  // A build whose .env lost a key still starts and still shows the login
  // screen — every sign-in then fails at the server's gateway, which reads
  // to the user as a wrong password. Refuse to start instead.
  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
  final supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
  if (!supabaseUrl.startsWith('https://') || supabaseAnonKey.length < 20) {
    FlutterNativeSplash.remove();
    runApp(const _MisconfiguredBuildApp());
    return;
  }

  // Initialize Supabase
  await SupabaseService.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  await setupDependencies();

  final client = Supabase.instance.client;
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: getIt<ClassroomRepository>()),
        RepositoryProvider.value(value: getIt<TeacherRepository>()),
        RepositoryProvider.value(value: getIt<StudentRepository>()),
        RepositoryProvider.value(value: getIt<TimetableRepository>()),
        RepositoryProvider.value(value: getIt<BusRepository>()),
        RepositoryProvider.value(value: getIt<AnnouncementRepository>()),
        RepositoryProvider.value(value: getIt<AttendanceRepository>()),
        RepositoryProvider.value(value: getIt<HomeworkRepository>()),
        RepositoryProvider.value(value: getIt<MarkRepository>()),
        RepositoryProvider.value(value: getIt<ClassLogRepository>()),
        RepositoryProvider.value(value: getIt<SchoolEventRepository>()),
        RepositoryProvider.value(value: getIt<EventProgramRepository>()),
        RepositoryProvider.value(value: getIt<SchoolSettingsRepository>()),
        RepositoryProvider.value(value: getIt<PersonMediaRepository>()),
        RepositoryProvider.value(value: getIt<ParentNoticeRepository>()),
        RepositoryProvider.value(value: getIt<FeePaymentRepository>()),
        RepositoryProvider.value(value: getIt<AcademicYearRepository>()),
        RepositoryProvider.value(value: getIt<StaffAttendanceRepository>()),
        RepositoryProvider.value(value: getIt<LeaveRequestRepository>()),
        RepositoryProvider.value(value: getIt<ExamRepository>()),
        RepositoryProvider.value(value: getIt<AdmissionRepository>()),
        RepositoryProvider.value(value: getIt<MessageRepository>()),
        RepositoryProvider.value(value: getIt<StudentLeaveRepository>()),
        RepositoryProvider.value(value: getIt<NotificationRepository>()),
        RepositoryProvider.value(value: getIt<ClassDaySummaryRepository>()),
        RepositoryProvider.value(value: getIt<ActivityRepository>()),
        RepositoryProvider.value(value: getIt<GrowthRepository>()),
        RepositoryProvider.value(value: getIt<ProgressRepository>()),
        RepositoryProvider.value(value: getIt<HomeworkCompletionRepository>()),
        RepositoryProvider.value(value: getIt<DiaryNoteRepository>()),
        RepositoryProvider.value(value: getIt<PeriodReassignmentRepository>()),
        RepositoryProvider.value(value: getIt<LibraryRepository>()),
      ],
      child: BlocProvider(
        create: (context) => LoginBloc(client),
        child: const PalliCoreApp(),
      ),
    ),
  );
}

class PalliCoreApp extends StatelessWidget {
  const PalliCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      // Keeps the go_router-refreshing notifier in sync with the auth bloc
      // for the whole app lifetime — not just while LoginScreen is mounted,
      // since sessions can resolve/expire/reset from any screen (OAuth
      // deep-link return, a background session restore, a forced password
      // change completing on ForcePasswordChangeScreen).
      listener: (context, state) => authStateNotifier.value = state,
      child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ClassroomBloc(
            getIt<ClassroomRepository>(),
            getIt<TeacherRepository>(),
            getIt<StudentRepository>(),
          ),
        ),
        BlocProvider(create: (context) => TimetableBloc(getIt<TimetableRepository>())),
        BlocProvider(create: (context) => DirectoryBloc(
          getIt<StudentRepository>(),
          getIt<TeacherRepository>(),
          getIt<ClassroomRepository>(),
          getIt<TimetableRepository>(),
        )),
        BlocProvider(create: (context) => AnnouncementBloc(getIt<AnnouncementRepository>())),
        BlocProvider(create: (context) => BusBloc(getIt<BusRepository>())),
        BlocProvider(create: (context) => TeacherDashboardBloc(
          getIt<TimetableRepository>(),
          getIt<ClassLogRepository>(),
          getIt<ClassroomRepository>(),
          getIt<PeriodReassignmentRepository>(),
          getIt<AttendanceRepository>(),
        )),
        BlocProvider(create: (context) => TeacherToolsBloc(getIt<ClassroomRepository>(), getIt<TimetableRepository>(), getIt<StudentRepository>(), getIt<HomeworkRepository>())),
        BlocProvider(
          create: (context) => SchoolEventBloc(
            getIt<SchoolEventRepository>(),
            getIt<ClassroomRepository>(),
            getIt<StudentRepository>(),
            getIt<ParentNoticeRepository>(),
            getIt<AnnouncementRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => FeeBloc(
            getIt<ClassroomRepository>(),
            getIt<StudentRepository>(),
            getIt<FeePaymentRepository>(),
            getIt<SchoolEventRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => DashboardBloc(
            getIt<StudentRepository>(),
            getIt<TeacherRepository>(),
            getIt<AttendanceRepository>(),
            getIt<ClassroomRepository>(),
            getIt<StaffAttendanceRepository>(),
            getIt<FeePaymentRepository>(),
            getIt<SchoolEventRepository>(),
            getIt<BusRepository>(),
            getIt<LeaveRequestRepository>(),
          ),
        ),
      ],
      child: BlocListener<LoginBloc, LoginState>(
        // Every bloc above is created once and lives as long as the app, so
        // signing out leaves the last user's data sitting in them. The next
        // person to sign in on the same phone would see it — their own name
        // in the header, someone else's classes underneath — until the app
        // was killed. Wipe the user-scoped state the moment a session ends.
        listenWhen: (previous, current) => previous is LoginSuccess && current is! LoginSuccess,
        listener: (context, state) {
          context.read<TeacherDashboardBloc>().add(ClearTeacherDashboard());
          context.read<TeacherToolsBloc>().add(ClearTeacherTools());
          TeacherExamData.invalidate();
        },
        child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, mode, _) {
          return MaterialApp.router(
            title: 'PalliCore',
            debugShowCheckedModeBanner: false,
            locale: const Locale('en', 'IN'),
            supportedLocales: const [Locale('en', 'IN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            builder: (context, child) {
              return MediaQuery(
                // The school reads clock times as 12-hour, so the phone's
                // 24-hour setting must not decide it. This covers everything
                // that asks the platform — TimeOfDay.format() and the time
                // picker; text we format ourselves goes through
                // Schedule.format12.
                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                child: IconTheme(
                  data: IconThemeData(color: AppColors.onSurface(context)),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: AppColors.onSurface(context)),
                    // Pages paint their own backdrop (see PremiumPageTransitionsBuilder);
                    // this solid fill only guards the frame before the first page.
                    child: ColoredBox(color: AdminLook.canvasOf(context), child: child ?? const SizedBox.shrink()),
                  ),
                ),
              );
            },
            routerConfig: router,
          );
        },
      ),
      ),
      ),
    );
  }
}

/// Shown instead of the app when the bundled .env is missing its Supabase
/// URL or key. Nothing here can be fixed on the phone — it needs a rebuild.
class _MisconfiguredBuildApp extends StatelessWidget {
  const _MisconfiguredBuildApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'This copy of PalliCore is missing its server settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sign-in cannot work in this build. Install the latest '
                    'version of the app, or ask your school admin for it.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
