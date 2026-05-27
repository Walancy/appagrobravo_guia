import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:agrobravo/core/components/app_text_field.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:agrobravo/features/profile/presentation/cubit/profile_state.dart';
import 'package:agrobravo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:agrobravo/core/components/custom_confirm_bottom_sheet.dart';

class AccountDataPage extends StatefulWidget {
  const AccountDataPage({super.key});

  @override
  State<AccountDataPage> createState() => _AccountDataPageState();
}

class _AccountDataPageState extends State<AccountDataPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _ssnController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _complementController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _passportController = TextEditingController();
  DateTime? _birthDate;

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _ssnController.dispose();
    _zipCodeController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _neighborhoodController.dispose();
    _complementController.dispose();
    _nationalityController.dispose();
    _passportController.dispose();
    super.dispose();
  }

  void _initializeControllers(profile) {
    if (_initialized) return;
    _nameController.text = profile.name;
    final phoneDigits = (profile.phone ?? '').replaceAll(RegExp(r'\D'), '');
    _phoneController.text = _phoneMaskFormatter
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: phoneDigits),
        )
        .text;
    _cpfController.text = profile.cpf ?? '';
    _ssnController.text = profile.ssn ?? '';
    _zipCodeController.text = profile.zipCode ?? '';
    _stateController.text = profile.state ?? '';
    _cityController.text = profile.city ?? '';
    _streetController.text = profile.street ?? '';
    _numberController.text = profile.number ?? '';
    _neighborhoodController.text = profile.neighborhood ?? '';
    _complementController.text = profile.complement ?? '';
    _nationalityController.text = profile.nationality ?? '';
    _passportController.text = profile.passport ?? '';
    _birthDate = profile.birthDate;
    _initialized = true;
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  void _showDeleteAccountDialog(BuildContext context) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomConfirmBottomSheet(
        title: context.t('Excluir Conta', 'Delete Account'),
        message: context.t(
          'Tem certeza de que deseja excluir permanentemente sua conta? Esta ação é irreversível e todos os seus dados serão apagados.',
          'Are you sure you want to permanently delete your account? This action is irreversible and all your data will be erased.',
        ),
        confirmLabel: context.t('Sim, excluir', 'Yes, delete'),
        cancelLabel: context.t('Cancelar', 'Cancel'),
        confirmColor: AppColors.error,
      ),
    );

    if (confirm == true && context.mounted) {
      // Mostrar indicador de progresso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingContext) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final authCubit = context.read<AuthCubit>();
      final result = await authCubit.deleteAccount();
      
      if (context.mounted) {
        Navigator.pop(context); // Remove o loading indicador
        result.fold(
          (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t('Erro ao excluir conta: $error', 'Error deleting account: $error')),
                backgroundColor: AppColors.error,
              ),
            );
          },
          (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t('Sua conta foi excluída com sucesso.', 'Your account has been successfully deleted.')),
                backgroundColor: AppColors.primary,
              ),
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ProfileCubit>()..loadProfile(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppHeader(mode: HeaderMode.back, title: context.t('Dados da conta', 'Account details')),
        body: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            state.maybeWhen(
              loaded: (profile, _, __, ___, ____, _____, ______, _______) {
                _initializeControllers(profile);
              },
              orElse: () {},
            );
          },
          builder: (context, state) {
            return state.when(
              initial: () => const Center(child: CircularProgressIndicator()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (message) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          context.t('Não foi possível carregar os dados. Verifique sua conexão.', 'Could not load data. Check your connection.'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ProfileCubit>().loadProfile();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            ),
                          ),
                          child: Text(
                            context.t('Tentar Novamente', 'Try Again'),
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loaded: (profile, _, __, ___, ____, _____, ______, _______) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('Informações Pessoais', 'Personal Information'),
                          style: AppTextStyles.h3.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildTextField(
                          context,
                          _nameController,
                          context.t('Nome Completo', 'Full Name'),
                        ),
                        _buildTextField(
                          context,
                          _phoneController,
                          context.t('Telefone', 'Phone'),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_phoneMaskFormatter],
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                context,
                                _cpfController,
                                'CPF',
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _buildTextField(
                                context,
                                _ssnController,
                                'SSN',
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),
                        _buildDatePicker(context, context.t('Data de Nascimento', 'Date of Birth')),

                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          context.t('Endereço', 'Address'),
                          style: AppTextStyles.h3.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildTextField(
                          context,
                          _zipCodeController,
                          context.t('CEP', 'Zip Code'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                context,
                                _stateController,
                                context.t('Estado', 'State'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _buildTextField(
                                context,
                                _cityController,
                                context.t('Cidade', 'City'),
                              ),
                            ),
                          ],
                        ),
                        _buildTextField(
                          context,
                          _neighborhoodController,
                          context.t('Bairro', 'Neighborhood'),
                        ),
                        _buildTextField(context, _streetController, context.t('Rua', 'Street')),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                context,
                                _numberController,
                                context.t('Número', 'Number'),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 2,
                              child: _buildTextField(
                                context,
                                _complementController,
                                context.t('Complemento', 'Complement'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          context.t('Documentação Internacional', 'International Documentation'),
                          style: AppTextStyles.h3.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildTextField(
                          context,
                          _nationalityController,
                          context.t('Nacionalidade', 'Nationality'),
                        ),
                        _buildTextField(
                          context,
                          _passportController,
                          context.t('Passaporte', 'Passport'),
                        ),

                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              final data = {
                                'name': _nameController.text,
                                'phone': _phoneController.text,
                                'cpf': _cpfController.text,
                                'ssn': _ssnController.text,
                                'zipCode': _zipCodeController.text,
                                'state': _stateController.text,
                                'city': _cityController.text,
                                'street': _streetController.text,
                                'number': _numberController.text,
                                'neighborhood': _neighborhoodController.text,
                                'complement': _complementController.text,
                                'nationality': _nationalityController.text,
                                'passport': _passportController.text,
                                if (_birthDate != null) 'birthDate': _birthDate,
                              };
                              context.read<ProfileCubit>().updateAccountData(data);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.t('Dados atualizados com sucesso!', 'Data updated successfully!')),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLg,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              context.t('Salvar Alterações', 'Save Changes'),
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton(
                            onPressed: () => _showDeleteAccountDialog(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLg,
                                ),
                              ),
                            ),
                            child: Text(
                              context.t('Excluir conta', 'Delete account'),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppTextField(
        label: label,
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: () => _selectBirthDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _birthDate == null
                        ? context.t('Selecionar data', 'Select date')
                        : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
