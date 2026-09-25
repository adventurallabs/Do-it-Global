import 'package:flutter/material.dart';
import 'package:feature_auth/feature_auth.dart';

final ValueNotifier<LoginState> authStateNotifier = ValueNotifier(LoginSessionUnresolved());
