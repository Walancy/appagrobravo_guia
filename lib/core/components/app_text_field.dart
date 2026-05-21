import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? prefixText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final bool isLightModeOnDarkBackground;
  final void Function(String)? onChanged;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.prefixText,
    this.controller,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textStyle,
    this.hintStyle,
    this.isLightModeOnDarkBackground = false,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isLightModeOnDarkBackground 
      ? AppColors.surface 
      : Theme.of(context).colorScheme.onSurface;
      
    final fillColor = isLightModeOnDarkBackground 
      ? AppColors.surface.withOpacity(0.15)
      : Theme.of(context).dividerColor.withOpacity(0.08);
      
    final borderColor = isLightModeOnDarkBackground
      ? AppColors.surface.withOpacity(0.6)
      : Theme.of(context).colorScheme.onSurface.withOpacity(0.4);

    final focusedBorderColor = isLightModeOnDarkBackground
      ? AppColors.surface
      : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isLightModeOnDarkBackground 
                  ? AppColors.surface.withOpacity(0.9) 
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          maxLines: maxLines,
          minLines: minLines,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          readOnly: readOnly,
          onTap: onTap,
          textCapitalization: textCapitalization,
          style: textStyle ?? AppTextStyles.bodyMedium.copyWith(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: hintStyle ?? AppTextStyles.bodyMedium.copyWith(
              color: isLightModeOnDarkBackground
                  ? AppColors.surface.withOpacity(0.5)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            prefixText: prefixText,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
            ),
            suffixIcon: suffixIcon,
            suffixIconColor: textColor,
          ),
        ),
      ],
    );
  }
}
