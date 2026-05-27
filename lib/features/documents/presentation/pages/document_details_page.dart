import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/components/image_source_bottom_sheet.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/constants/translations.dart';
import '../cubit/documents_cubit.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/document_enums.dart';

class DocumentDetailsPage extends StatefulWidget {
  final DocumentType type;
  final DocumentEntity? currentDocument;
  final DocumentsCubit? cubit;

  const DocumentDetailsPage({
    super.key,
    required this.type,
    this.currentDocument,
    this.cubit,
  });

  @override
  State<DocumentDetailsPage> createState() => _DocumentDetailsPageState();
}

class _DocumentDetailsPageState extends State<DocumentDetailsPage> {
  final _numberController = TextEditingController();
  DateTime? _selectedDate;
  File? _selectedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentDocument != null) {
      _numberController.text = widget.currentDocument!.documentNumber ?? '';
      _selectedDate = widget.currentDocument!.expiryDate;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  String _getTypeLabel(BuildContext context) {
    switch (widget.type) {
      case DocumentType.passaporte:
        return context.t('Passaporte', 'Passport');
      case DocumentType.visto:
        return context.t('Visto', 'Visa');
      case DocumentType.vacina:
        return context.t('Carteira de Vacinação', 'Vaccination Card');
      case DocumentType.seguro:
        return context.t('Seguro Viagem', 'Travel Insurance');
      case DocumentType.carteiraMotorista:
        return context.t('Carteira de Motorista', "Driver's License");
      case DocumentType.autorizacaoMenores:
        return context.t('Autorização de Menores', 'Minor Authorization');
      case DocumentType.outro:
        return context.t('Outro', 'Other');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final hasImage =
        _selectedFile != null || widget.currentDocument?.imageUrl != null;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageSourceBottomSheet(
        title: hasImage
            ? context.t('Alterar foto do documento', 'Change document photo')
            : context.t('Tirar foto do documento', 'Take document photo'),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() => _selectedFile = File(image.path));
      }
    }
  }

  Future<void> _onSave(BuildContext context) async {
    if (_selectedFile == null && widget.currentDocument?.imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Por favor, selecione uma foto do documento',
              'Please select a photo of the document',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    final cubit = widget.cubit ?? getIt<DocumentsCubit>();

    try {
      if (_selectedFile != null) {
        await cubit.uploadDocument(
          type: widget.type,
          file: _selectedFile!,
          documentNumber: _numberController.text,
          expiryDate: _selectedDate,
        );
      } else if (widget.currentDocument != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'Selecione uma nova imagem para atualizar o documento.',
                'Select a new image to update the document.',
              ),
            ),
          ),
        );
        setState(() => _isUploading = false);
        return;
      }

      if (mounted) {
        Navigator.pop(context, true); // Signal success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('Erro ao salvar: $e', 'Error saving: $e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        mode: HeaderMode.back,
        title: _getTypeLabel(context),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(context),
              const SizedBox(height: AppSpacing.lg),

              Text(
                context.t('Imagem do Documento', 'Document Image'),
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildImagePreview(context),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: Text(
                  _selectedFile != null ||
                          widget.currentDocument?.imageUrl != null
                      ? context.t('Alterar Foto', 'Change Photo')
                      : context.t('Tirar Foto', 'Take Photo'),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                context.t('Número do Documento', 'Document Number'),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _numberController,
                decoration: InputDecoration(
                  hintText: context.t('Ex: CD123456', 'E.g.: CD123456'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                context.t('Data de Validade', 'Expiry Date'),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        _selectedDate ??
                        DateTime.now().add(const Duration(days: 365)),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null
                            ? context.t('Selecionar data', 'Select date')
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : () => _onSave(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          context.t(
                            'Salvar e Enviar para Análise',
                            'Save and Submit for Review',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    if (widget.currentDocument == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.t(
                  'Este documento ainda não foi enviado. Envie agora para análise.',
                  'This document has not been submitted yet. Submit it now for review.',
                ),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Color statusColor = Colors.orange;
    String statusText = context.t('Pendente de análise', 'Pending review');
    IconData icon = Icons.access_time;

    if (widget.currentDocument!.status == DocumentStatus.aprovado) {
      statusColor = AppColors.primary;
      statusText = context.t('Documento aprovado', 'Document approved');
      icon = Icons.check_circle_outline;
    } else if (widget.currentDocument!.status == DocumentStatus.recusado) {
      statusColor = AppColors.error;
      statusText = context.t('Documento recusado', 'Document rejected');
      icon = Icons.error_outline;
    } else if (widget.currentDocument!.status == DocumentStatus.expirado) {
      statusColor = AppColors.error;
      statusText = context.t('Documento expirado', 'Document expired');
      icon = Icons.warning_amber_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: statusColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  statusText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.currentDocument!.rejectionReason != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '${context.t('Motivo', 'Reason')}: ${widget.currentDocument!.rejectionReason}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _selectedFile != null
            ? Image.file(_selectedFile!, fit: BoxFit.cover)
            : (widget.currentDocument?.imageUrl != null
                  ? Image.network(
                      widget.currentDocument!.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined, size: 50),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_search,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t(
                              'Nenhuma imagem enviada',
                              'No image submitted',
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )),
      ),
    );
  }
}
