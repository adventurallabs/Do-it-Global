import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../models/student.dart';

class StudentAvatar extends StatelessWidget {
  final Student student;
  final double radius;

  const StudentAvatar({
    super.key,
    required this.student,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandSweep(),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.ice,
        backgroundImage:
            student.photoUrl != null ? NetworkImage(student.photoUrl!) : null,
        child: student.photoUrl == null
            ? Text(
                student.initials,
                style: TextStyle(
                  color: AppColors.royalBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.72,
                ),
              )
            : null,
      ),
    );
  }
}
