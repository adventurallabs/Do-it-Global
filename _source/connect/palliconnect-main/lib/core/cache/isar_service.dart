import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  static late Isar _isar;

  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        // Schemas go here (e.g., HomeworkItemSchema, DiaryDayEntrySchema)
      ],
      directory: dir.path,
    );
  }

  static Isar get instance => _isar;
}
