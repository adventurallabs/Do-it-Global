import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

Student _student({
  String? photoUrl = 'https://x/p.png',
  Gender? gender = Gender.female,
  String? bloodGroup = 'O+',
  DateTime? dob,
  String? emergencyContact = '9000000000',
  String address = '12 Temple Street',
  bool? needsTransport = false,
}) =>
    Student(
      id: 's1',
      name: 'Aarav',
      rollNumber: '1',
      photoUrl: photoUrl,
      fatherName: 'F',
      motherName: 'M',
      contactNumber: '9111111111',
      emergencyContact: emergencyContact,
      gender: gender,
      bloodGroup: bloodGroup,
      dob: dob ?? DateTime(2020, 5, 1),
      needsTransport: needsTransport,
      address: address,
      classroomId: 'c1',
      fees: 0,
      admissionNo: 'A1',
    );

Teacher _teacher({
  String? photoUrl = 'https://x/t.png',
  Gender? gender = Gender.male,
  DateTime? dob,
  String? emergencyContact = '9000000000',
  String address = '9 Mill Road',
}) =>
    Teacher(
      id: 't1',
      name: 'Hulk',
      contactNumber: '9222222222',
      photoUrl: photoUrl,
      qualification: 'MSc',
      gender: gender,
      emergencyContact: emergencyContact,
      address: address,
      salary: 0,
      dob: dob ?? DateTime(1990, 1, 1),
    );

void main() {
  group('StudentProfileGaps', () {
    test('a complete file owes nothing', () {
      final gaps = StudentProfileGaps.of(_student(), documentCount: 1);
      expect(gaps.isComplete, isTrue);
      expect(gaps.summary, isNull);
      expect(gaps.criticalCount, 0);
    });

    test('blood group and emergency contact are the critical two', () {
      final gaps = StudentProfileGaps.of(
        _student(bloodGroup: null, emergencyContact: null),
        documentCount: 1,
      );
      expect(gaps.criticalCount, 2);
      expect(
        gaps.gaps.where((g) => g.isCritical).map((g) => g.field).toSet(),
        {'bloodGroup', 'emergencyContact'},
      );
    });

    test('an empty string counts as missing, not as an answer', () {
      final gaps = StudentProfileGaps.of(
        _student(bloodGroup: '   ', emergencyContact: ''),
        documentCount: 1,
      );
      expect(gaps.gaps.map((g) => g.field), containsAll(['bloodGroup', 'emergencyContact']));
    });

    test('not being asked about transport is a gap; saying no is not', () {
      final unasked = StudentProfileGaps.of(
        _student(needsTransport: null),
        documentCount: 1,
      );
      expect(unasked.gaps.map((g) => g.field), contains('needsTransport'));

      final walks = StudentProfileGaps.of(
        _student(needsTransport: false),
        documentCount: 1,
      );
      expect(walks.gaps.map((g) => g.field), isNot(contains('needsTransport')));
      expect(walks.gaps.map((g) => g.field), isNot(contains('transportDetails')),
          reason: 'a walker is never asked for a bus stop');
    });

    test('a bus child without a stop is chased, and it is the office to chase', () {
      final gaps = StudentProfileGaps.of(
        _student(needsTransport: true),
        hasTransportDetails: false,
        documentCount: 1,
      );
      final detail = gaps.gaps.firstWhere((g) => g.field == 'transportDetails');
      expect(detail.owner, GapOwner.office);
      expect(gaps.forFamily.map((g) => g.field), isNot(contains('transportDetails')),
          reason: 'the parent cannot answer which bus the school assigns');

      final done = StudentProfileGaps.of(
        _student(needsTransport: true),
        hasTransportDetails: true,
        documentCount: 1,
      );
      expect(done.isComplete, isTrue);
    });

    test('documents are chased until there is at least one', () {
      expect(StudentProfileGaps.of(_student()).gaps.map((g) => g.field),
          contains('documents'));
      expect(StudentProfileGaps.of(_student(), documentCount: 2).isComplete, isTrue);
    });

    test('the summary names what is missing and stops counting at three', () {
      expect(
        StudentProfileGaps.of(_student(bloodGroup: null), documentCount: 1).summary,
        'Still needed: blood group',
      );
      expect(
        StudentProfileGaps.of(_student(bloodGroup: null, photoUrl: null), documentCount: 1)
            .summary,
        'Still needed: photo and blood group',
      );
      final many = StudentProfileGaps.of(
        _student(
            photoUrl: null,
            gender: null,
            bloodGroup: null,
            emergencyContact: null,
            address: ''),
      );
      expect(many.summary, contains('and 4 more'));
    });

    test('the family is only asked what the family knows', () {
      final gaps = StudentProfileGaps.of(
        _student(needsTransport: true, bloodGroup: null),
        hasTransportDetails: false,
      );
      expect(gaps.forFamily.map((g) => g.field), contains('bloodGroup'));
      expect(gaps.forOffice.map((g) => g.field), contains('transportDetails'));
      expect(gaps.forFamily.length + gaps.forOffice.length, gaps.gaps.length);
    });
  });

  group('TeacherProfileGaps', () {
    test('a complete staff file owes nothing', () {
      expect(TeacherProfileGaps.of(_teacher(), documentCount: 1).isComplete, isTrue);
    });

    test('an emergency contact is the critical one', () {
      final gaps = TeacherProfileGaps.of(
        _teacher(emergencyContact: null),
        documentCount: 1,
      );
      expect(gaps.criticalCount, 1);
      expect(gaps.gaps.single.field, 'emergencyContact');
    });

    test('everything on a staff file is the office to fill in', () {
      final gaps = TeacherProfileGaps.of(_teacher(photoUrl: null, gender: null));
      expect(gaps.gaps.every((g) => g.owner == GapOwner.office), isTrue);
    });
  });

  group('StudentTransport', () {
    test('it is only complete with a bus and both ends', () {
      const partial = StudentTransport(studentId: 's1', busId: 'b1');
      expect(partial.isComplete, isFalse);
      expect(partial.isPartial, isTrue);
      expect(partial.missing, ['pickup point', 'drop point']);

      const full = StudentTransport(
        studentId: 's1',
        busId: 'b1',
        pickupLocation: 'Temple corner',
        dropLocation: 'Temple corner',
      );
      expect(full.isComplete, isTrue);
      expect(full.missing, isEmpty);
    });

    test('nothing recorded is not the same as partly recorded', () {
      const none = StudentTransport(studentId: 's1');
      expect(none.isPartial, isFalse);
      expect(none.isComplete, isFalse);
      expect(none.missing.length, 3);
    });

    test('whitespace is not an address', () {
      const blank = StudentTransport(
          studentId: 's1', busId: 'b1', pickupLocation: '  ', dropLocation: 'Gate');
      expect(blank.isComplete, isFalse);
      expect(blank.missing, ['pickup point']);
    });
  });
}
