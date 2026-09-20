import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';

class CustomTextfield extends StatefulWidget {
  const CustomTextfield({
    super.key,
    required this.label,
    required this.hintText,
    required this.keyboardType,
    this.obscureText = false,
    required this.controller,
    this.validator,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.onChanged,
    this.enablePasswordToggle = false,
    this.inputFormatters,
    this.autofillHints,
  });

  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final Function(String)? onChanged;
  final bool enablePasswordToggle;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    // If it's a password field with a toggle, default it to hidden
    _isObscured = widget.enablePasswordToggle ? true : widget.obscureText;
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isObscured = !_isObscured;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? AppColors.dividerDark
        : AppColors.dividerLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),

        // TextFormField
        TextFormField(
          inputFormatters: widget.inputFormatters,
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _isObscured,
          autofillHints: widget.autofillHints,
          validator: widget.validator, // Validation handled entirely here
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: widget.onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),

            // Simplified Suffix Icon Logic (Static grey color)
            suffixIcon: widget.enablePasswordToggle
                ? GestureDetector(
                    onTap: _togglePasswordVisibility,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(
                        _isObscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 20,
                      ),
                    ),
                  )
                : widget.suffixIcon != null
                ? GestureDetector(
                    onTap: widget.onSuffixIconPressed,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(
                        widget.suffixIcon,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 20,
                      ),
                    ),
                  )
                : null,

            // Borders — now theme-aware
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dividerColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dividerColor, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
