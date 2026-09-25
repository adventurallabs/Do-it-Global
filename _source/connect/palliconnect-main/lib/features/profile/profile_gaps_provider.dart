import 'package:core_models/core_models.dart' show StudentProfileGaps, ProfileGap;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/data/parent_repository.dart';

export 'package:core_models/core_models.dart' show ProfileGap, GapOwner, GapWeight;

/// How much of the child's file the family still owes.
///
/// Both apps read `StudentProfileGaps` from core_models, so the parent is
/// never asked for something the admin's screen does not show as missing.
final studentProfileGapsProvider = FutureProvider<StudentProfileGaps>((ref) async {
  final student = ref.watch(currentStudentProvider);
  if (student == null) return const StudentProfileGaps([]);

  final repo = ref.read(parentRepositoryProvider);
  var documentCount = 0;
  var hasTransport = false;
  try {
    documentCount = await repo.documentCount(student.id);
    hasTransport = await repo.hasTransportDetails(student.id);
  } catch (_) {
    // A failed count would otherwise read as "no documents" and nag a family
    // that has already sent everything.
    return const StudentProfileGaps([]);
  }

  return StudentProfileGaps.fromValues(
    photoUrl: student.photoUrl,
    gender: student.gender,
    bloodGroup: student.bloodGroup,
    dob: student.dob,
    emergencyContact: student.emergencyContact,
    address: student.address,
    needsTransport: student.needsTransport,
    hasTransportDetails: hasTransport,
    documentCount: documentCount,
  );
});

/// Only what the family can actually answer — the office's own gaps are not
/// theirs to chase.
final familyProfileGapsProvider = Provider<List<ProfileGap>>((ref) {
  return ref.watch(studentProfileGapsProvider).valueOrNull?.forFamily ?? const [];
});
