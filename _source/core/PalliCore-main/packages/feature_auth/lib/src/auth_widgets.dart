import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

/// The field and the error banner shared by the login and sign-up screens.
///
/// They were private to the login screen until sign-up needed the same shapes;
/// two copies would have drifted the first time either was touched.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;
  final VoidCallback? onToggleObscure;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.obscure = false,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return SoftField(
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        obscureText: obscure,
        style: TextStyle(color: AdminLook.inkOf(context)),
        decoration: InputDecoration(
          hintText: label,
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: AdminLook.muteOf(context), size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AdminLook.muteOf(context),
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// Collapses to nothing when there is no message, so the card does not keep a
/// gap open for an error that has not happened.
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              key: ValueKey(message),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
