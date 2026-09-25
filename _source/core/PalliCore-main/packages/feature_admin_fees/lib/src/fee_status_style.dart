import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

Color feeStatusColor(FeeStatus status) {
  switch (status) {
    case FeeStatus.fullyPaid:
      return AppColors.success;
    case FeeStatus.partiallyPaid:
      return AppColors.warning;
    case FeeStatus.notPaid:
      return AppColors.error;
  }
}
