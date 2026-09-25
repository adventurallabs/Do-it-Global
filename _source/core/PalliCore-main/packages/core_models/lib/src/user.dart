import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

enum UserRole {
  @JsonValue('admin')
  admin,
  @JsonValue('teacher')
  teacher,
  /// A staff login whose `teachers.role` is 'librarian'.
  @JsonValue('librarian')
  librarian,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  final String id;
  final String email;
  final UserRole role;
  final String? name;
  @JsonKey(defaultValue: false)
  final bool mustChangePassword;

  User({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.mustChangePassword = false,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
