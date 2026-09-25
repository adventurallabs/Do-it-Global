import 'package:get_it/get_it.dart';
import 'package:core_data/core_data.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Supabase
  final supabaseService = SupabaseService();
  getIt.registerSingleton<SupabaseService>(supabaseService);
  final client = supabaseService.client;

  // Repositories
  getIt.registerLazySingleton(() => ClassroomRepository(client));
  getIt.registerLazySingleton(() => TeacherRepository(client));
  getIt.registerLazySingleton(() => StudentRepository(client));
  getIt.registerLazySingleton(() => TimetableRepository(client));
  getIt.registerLazySingleton(() => BusRepository(client));
  getIt.registerLazySingleton(() => AnnouncementRepository(client));
  getIt.registerLazySingleton(() => AttendanceRepository(client));
  getIt.registerLazySingleton(() => HomeworkRepository(client));
  getIt.registerLazySingleton(() => MarkRepository(client));
  getIt.registerLazySingleton(() => ClassLogRepository(client));
  getIt.registerLazySingleton(() => SchoolEventRepository(client));
  getIt.registerLazySingleton(() => EventProgramRepository(client));
  getIt.registerLazySingleton(() => SchoolSettingsRepository(client));
  getIt.registerLazySingleton(() => PersonMediaRepository(client));
  getIt.registerLazySingleton(() => ParentNoticeRepository(client));
  getIt.registerLazySingleton(() => FeePaymentRepository(client));
  getIt.registerLazySingleton(() => AcademicYearRepository(client));
  getIt.registerLazySingleton(() => StaffAttendanceRepository(client));
  getIt.registerLazySingleton(() => LeaveRequestRepository(client));
  getIt.registerLazySingleton(() => ExamRepository(client));
  getIt.registerLazySingleton(() => AdmissionRepository(client));
  getIt.registerLazySingleton(() => MessageRepository(client));
  getIt.registerLazySingleton(() => StudentLeaveRepository(client));
  getIt.registerLazySingleton(() => NotificationRepository(client));
  getIt.registerLazySingleton(() => ClassDaySummaryRepository(client));
  getIt.registerLazySingleton(() => ActivityRepository(client));
  getIt.registerLazySingleton(() => GrowthRepository(client));
  getIt.registerLazySingleton(() => ProgressRepository(client));
  getIt.registerLazySingleton(() => HomeworkCompletionRepository(client));
  getIt.registerLazySingleton(() => DiaryNoteRepository(client));
  getIt.registerLazySingleton(() => PeriodReassignmentRepository(client));
  getIt.registerLazySingleton(() => LibraryRepository(client));
}
