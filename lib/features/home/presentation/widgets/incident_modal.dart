import 'package:flutter/material.dart';
import 'package:agrobravo/core/components/app_text_field.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/features/home/domain/repositories/dashboard_actions_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class IncidentModal extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic>? incidentToEdit;

  const IncidentModal({
    super.key,
    required this.groupId,
    this.incidentToEdit,
  });

  @override
  State<IncidentModal> createState() => _IncidentModalState();
}

class _IncidentModalState extends State<IncidentModal> {
  bool _isLoading = false;
  List<String> _attachedFilePaths = [];
  String? _existingPhotoUrl;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  String? _selectedType;
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.incidentToEdit != null) {
      final incident = widget.incidentToEdit!;
      _selectedType = incident['tipo'];
      _locationController.text = incident['local'] ?? '';
      _descriptionController.text = incident['descricao'] ?? '';
      _actionController.text = incident['acao_tomada'] ?? '';
      _existingPhotoUrl = incident['foto_url'];

      if (incident['data_ocorrencia'] != null) {
        try {
          _selectedDate = DateTime.parse(incident['data_ocorrencia']);
        } catch (_) {}
      }
      if (incident['hora_ocorrencia'] != null) {
        final parts = incident['hora_ocorrencia'].toString().split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 12;
          final m = int.tryParse(parts[1]) ?? 0;
          _selectedTime = TimeOfDay(hour: h, minute: m);
        }
      }
    }

    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    _timeController.text =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  List<String> _getTypes(BuildContext context) => [
    context.t('Médico', 'Medical'),
    context.t('Logístico', 'Logistical'),
    context.t('Comportamental', 'Behavioral'),
    context.t('Financeiro', 'Financial'),
    context.t('Outros', 'Other'),
  ];

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _descriptionController.dispose();
    _actionController.dispose();
    _locationController.dispose();
    super.dispose();
  }  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra de arrastar (Drag Handle)
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.incidentToEdit != null
                              ? context.t('Editar incidente', 'Edit incident')
                              : context.t('Registrar incidente', 'Register incident'),
                          style: AppTextStyles.h3.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    context.t('Descreva o que houve nos campos abaixo', 'Describe what happened in the fields below'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDropdown(
                    context.t('Tipo do incidente', 'Incident type'),
                    context.t('Selecione o tipo', 'Select type'),
                    _getTypes(context),
                    _selectedType,
                    (val) => setState(() => _selectedType = val),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context.t('Local', 'Location'),
                    _locationController,
                    hint: context.t('Digite o local', 'Enter the location'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          context.t('Data', 'Date'),
                          _dateController,
                          readOnly: true,
                          onTap: _pickDate,
                          suffixIcon: const Icon(Icons.calendar_today, size: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          context.t('Hora', 'Time'),
                          _timeController,
                          readOnly: true,
                          onTap: _pickTime,
                          suffixIcon: const Icon(Icons.access_time, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context.t('Descrição detalhada', 'Detailed description'),
                    _descriptionController,
                    hint: context.t('Descreva o incidente', 'Describe the incident'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context.t('Ação tomada', 'Action taken'),
                    _actionController,
                    hint: context.t('Descreva a ação tomada', 'Describe the action taken'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('Foto(s)', 'Photo(s)'),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.image_outlined,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.t('Foto salva anteriormente', 'Previously saved photo'),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _existingPhotoUrl = null),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_attachedFilePaths.isNotEmpty)
                        Column(
                          children:
                              _attachedFilePaths.map((path) {
                                final fileName = path.split('/').last;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.image_outlined,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            fileName,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap:
                                              () => setState(
                                                () => _attachedFilePaths.remove(
                                                  path,
                                                ),
                                              ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      if (_existingPhotoUrl == null && _attachedFilePaths.isEmpty) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final isCamera = await showModalBottomSheet<bool>(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder:
                                  (context) => _AttachPhotoBottomSheet(
                                    onSourceSelected:
                                        (camera) => Navigator.pop(context, camera),
                                  ),
                            );
                            if (isCamera != null) {
                              final source =
                                  isCamera
                                      ? ImageSource.camera
                                      : ImageSource.gallery;
                              try {
                                final image = await picker.pickImage(source: source);
                                if (image != null) {
                                  setState(
                                    () => _attachedFilePaths.add(image.path),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(context.t('Erro ao selecionar foto.', 'Error selecting photo.')),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.attach_file_rounded, size: 20),
                          label: Text(context.t('Anexar foto', 'Attach photo')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          child: Text(
                            context.t('Voltar', 'Back'),
                            style: AppTextStyles.button.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  if (_selectedType == null ||
                                      _descriptionController.text.isEmpty ||
                                      _actionController.text.isEmpty ||
                                      _locationController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.t('Preencha os campos obrigatórios.', 'Please fill in the required fields.'),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => _isLoading = true);
                                  final repo = getIt<DashboardActionsRepository>();

                                  DateTime parsedDate;
                                  try {
                                    parsedDate = DateFormat('dd/MM/yyyy')
                                        .parse(_dateController.text);
                                  } catch (e) {
                                    parsedDate = DateTime.now();
                                  }

                                  final result = widget.incidentToEdit != null
                                      ? await repo.updateIncident(
                                          id: widget.incidentToEdit!['id'],
                                          groupId: widget.groupId,
                                          type: _selectedType!,
                                          location: _locationController.text,
                                          date: parsedDate,
                                          time: _timeController.text,
                                          description: _descriptionController.text,
                                          actionTaken: _actionController.text,
                                          existingPhotoUrl: _existingPhotoUrl,
                                          newLocalPhotoPaths: _attachedFilePaths,
                                        )
                                      : await repo.registerIncident(
                                          groupId: widget.groupId,
                                          type: _selectedType!,
                                          location: _locationController.text,
                                          date: parsedDate,
                                          time: _timeController.text,
                                          description: _descriptionController.text,
                                          actionTaken: _actionController.text,
                                          photoPaths: _attachedFilePaths,
                                        );

                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                    result.fold(
                                      (l) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${context.t('Erro', 'Error')}: ${l.toString().replaceAll("Exception: ", "")}',
                                            ),
                                          ),
                                        );
                                      },
                                      (_) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              widget.incidentToEdit != null
                                                  ? context.t('Incidente atualizado com sucesso!', 'Incident updated successfully!')
                                                  : context.t('Incidente registrado com sucesso!', 'Incident reported successfully!'),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  widget.incidentToEdit != null
                                      ? context.t('Salvar alterações', 'Save changes')
                                      : context.t('Enviar relato', 'Submit report'),
                                  style: AppTextStyles.button.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String hint,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    final borderColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.03);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items:
              items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            filled: true,
            fillColor: Theme.of(context).dividerColor.withOpacity(0.08),
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
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return AppTextField(
      label: label,
      controller: controller,
      hint: hint,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      suffixIcon: suffixIcon,
    );
  }
}

class _AttachPhotoBottomSheet extends StatelessWidget {
  final Function(bool isCamera) onSourceSelected;

  const _AttachPhotoBottomSheet({required this.onSourceSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(context.t('Anexar foto', 'Attach photo'), style: AppTextStyles.h3.copyWith(fontSize: 18)),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.03),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t('Selecione uma opção', 'Select an option'),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildOption(
                context: context,
                label: context.t('Galeria', 'Gallery'),
                icon: Icons.image_outlined,
                onTap: () => onSourceSelected(false),
              ),
              const SizedBox(width: AppSpacing.xl),
              _buildOption(
                context: context,
                label: context.t('Câmera', 'Camera'),
                icon: Icons.camera_alt_outlined,
                onTap: () => onSourceSelected(true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
