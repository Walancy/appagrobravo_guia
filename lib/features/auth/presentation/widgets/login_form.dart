import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrobravo/core/components/app_text_field.dart';
import 'package:agrobravo/core/components/primary_button.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/features/auth/presentation/widgets/auth_mode.dart';

class LoginForm extends StatefulWidget {
  final AuthMode authMode;
  final VoidCallback onForgotPasswordNavigation;
  final VoidCallback
  onLoginNavigation; // Navegação para Login (ex: sucesso -> login)
  final void Function(String email, String password, bool rememberMe)?
  onLoginAction;
  final void Function(String email)? onRecoverPasswordAction;
  final void Function(String password, String confirmPassword)?
  onResetPasswordAction;
  final void Function(String code)? onVerifyOtpAction;
  final void Function(String password, String confirmPassword)?
  onCreatePasswordAction;
  final String? errorMessage; // Nova prop para erros


  const LoginForm({
    super.key,
    required this.authMode,
    required this.onForgotPasswordNavigation,
    required this.onLoginNavigation,
    this.onLoginAction,
    this.onRecoverPasswordAction,
    this.onResetPasswordAction,
    this.onVerifyOtpAction,
    this.onCreatePasswordAction,
    this.errorMessage,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  // State
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    if (widget.authMode == AuthMode.login) {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('remembered_email');
      final password = prefs.getString('remembered_password');
      if (email != null && mounted) {
        setState(() {
          _emailController.text = email;
          if (password != null) {
            _passwordController.text = password;
          }
          _rememberMe = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.surface.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._buildContent(),
              if (widget.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }

  List<Widget> _buildContent() {
    switch (widget.authMode) {
      case AuthMode.login:
        return _buildLoginContent();
      case AuthMode.forgotPassword:
        return _buildForgotPasswordContent();
      case AuthMode.otpVerification:
        return _buildOtpVerificationContent();
      case AuthMode.createPassword:
        return _buildCreatePasswordContent();
      case AuthMode.resetPassword:
        return _buildResetPasswordContent();
      case AuthMode.success:
        return _buildSuccessContent();
      case AuthMode.emailVerification:
        return _buildEmailVerificationContent();
    }
  }

  // --- Conteúdos Específicos ---

  List<Widget> _buildLoginContent() {
    return [
      AppTextField(
        isLightModeOnDarkBackground: true,
        label: 'E-mail:',
        hint: 'example@gmail.com',
        controller: _emailController,
      ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        isLightModeOnDarkBackground: true,
        label: 'Senha:',
        hint: '**********',
        obscureText: _obscurePassword,
        controller: _passwordController,
        suffixIcon: _buildVisibilityIcon(true),
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          _buildCheckbox(
            value: _rememberMe,
            onChanged: (v) => setState(() => _rememberMe = v ?? false),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Lembrar conta',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.surface,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onForgotPasswordNavigation,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Esqueci minha senha',
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF00E676),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        label: 'Entrar',
        onPressed: () {
          widget.onLoginAction?.call(
            _emailController.text,
            _passwordController.text,
            _rememberMe,
          );
        },
      ),
    ];
  }

  List<Widget> _buildOtpVerificationContent() {
    return [
      Text(
        'Insira o código enviado para o seu e-mail.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.surface,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        isLightModeOnDarkBackground: true,
        label: 'Código:',
        hint: '123456',
        controller: _otpController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        label: 'Verificar código',
        onPressed: () {
          widget.onVerifyOtpAction?.call(_otpController.text);
        },
      ),
    ];
  }

  List<Widget> _buildCreatePasswordContent() {
    return [
      Text(
        'Para continuar, crie uma senha para sua conta.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.surface,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        isLightModeOnDarkBackground: true,
        label: 'Nova senha:',
        hint: '**********',
        obscureText: _obscurePassword,
        controller: _passwordController,
        suffixIcon: _buildVisibilityIcon(true),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        isLightModeOnDarkBackground: true,
        label: 'Confirmar senha:',
        hint: '**********',
        obscureText: _obscureConfirmPassword,
        controller: _confirmPasswordController,
        suffixIcon: _buildVisibilityIcon(false),
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        label: 'Criar senha',
        onPressed: () {
          widget.onCreatePasswordAction?.call(
            _passwordController.text,
            _confirmPasswordController.text,
          );
        },
      ),
    ];
  }

  List<Widget> _buildForgotPasswordContent() {
    return [
      Text(
        'Insira o email da sua conta para recuperar sua senha',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.surface,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        isLightModeOnDarkBackground: true,
        label: 'E-mail:',
        hint: 'example@gmail.com',
        controller: _emailController,
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        label: 'Enviar',
        onPressed: () {
          widget.onRecoverPasswordAction?.call(_emailController.text);
        },
      ),
    ];
  }

  List<Widget> _buildResetPasswordContent() {
    return [
      Text(
        'Insira sua nova senha',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.surface,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        isLightModeOnDarkBackground: true,
        label: 'Nova senha:',
        hint: '**********',
        obscureText: _obscurePassword,
        controller: _passwordController,
        suffixIcon: _buildVisibilityIcon(true),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        isLightModeOnDarkBackground: true,
        label: 'Confirmar senha:',
        hint: '**********',
        obscureText: _obscureConfirmPassword,
        controller: _confirmPasswordController,
        suffixIcon: _buildVisibilityIcon(false),
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        label: 'Salvar',
        onPressed: () {
          widget.onResetPasswordAction?.call(
            _passwordController.text,
            _confirmPasswordController.text,
          );
        },
      ),
    ];
  }

  List<Widget> _buildSuccessContent() {
    return [
      Text(
        'Sua senha foi alterada com sucesso, faça login novamente para continuar',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.surface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        label: 'Voltar para login',
        onPressed: widget.onLoginNavigation,
      ),
    ];
  }

  List<Widget> _buildEmailVerificationContent() {
    return [
      Text(
        'Enviamos um link de confirmação para o seu email. Por favor, verifique sua caixa de entrada.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.surface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        label: 'Voltar para login',
        onPressed: widget.onLoginNavigation,
      ),
    ];
  }

  // --- Helpers ---

  Widget _buildVisibilityIcon(bool isPassword) {
    final obscure = isPassword ? _obscurePassword : _obscureConfirmPassword;
    return IconButton(
      iconSize: 20,
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.surface,
      ),
      onPressed: () {
        setState(() {
          if (isPassword) {
            _obscurePassword = !_obscurePassword;
          } else {
            _obscureConfirmPassword = !_obscureConfirmPassword;
          }
        });
      },
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Theme(
      data: ThemeData(unselectedWidgetColor: AppColors.surface),
      child: SizedBox(
        height: 24,
        width: 24,
        child: Checkbox(
          value: value,
          activeColor: Colors.transparent,
          checkColor: AppColors.surface,
          side: const BorderSide(color: AppColors.surface, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
