import 'package:flutter_test/flutter_test.dart';

import 'package:feature_teacher_dashboard/feature_teacher_dashboard.dart';

void main() {
  test('exports the teacher dashboard screen', () {
    expect(TeacherDashboardScreen.new, isNotNull);
  });
}
