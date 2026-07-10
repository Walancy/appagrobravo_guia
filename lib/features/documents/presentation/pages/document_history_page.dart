import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/data/countries.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_state.dart';
import 'package:agrobravo/features/documents/domain/entities/document_entity.dart';
import 'package:agrobravo/features/documents/domain/entities/document_enums.dart';

/// Rótulo bilíngue do tipo de documento (compartilhado pela página e widgets).
String _documentTypeLabel(BuildContext context, DocumentType type) {
  switch (type) {
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

class DocumentHistoryPage extends StatelessWidget {
  final DocumentType type;
  final DocumentsCubit cubit;

  const DocumentHistoryPage({
    super.key,
    required this.type,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: Scaffold(
        appBar: AppHeader(
          mode: HeaderMode.back,
          title: _documentTypeLabel(context, type),
        ),
        body: BlocBuilder<DocumentsCubit, DocumentsState>(
          builder: (context, state) {
            return state.maybeWhen(
              loaded: (documents, isAlertDismissed, profile, mission) {
                final typeDocuments =
                    documents.where((d) => d.type == type).toList();

                return _buildBody(context, typeDocuments);
              },
              orElse: () => const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<DocumentEntity> documents) {
    final latestDocument = documents.isNotEmpty ? documents.first : null;

    if (documents.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.xl),
          _HistoryIntro(type: type),
          const SizedBox(height: AppSpacing.lg),
          _EmptyHistoryCard(
            onTap: () => _openDetails(context, null),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: 80,
      ),
      children: [
        _HistoryIntro(type: type),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _openDetails(context, null),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text(
              latestDocument == null
                  ? context.t('Enviar documento', 'Submit document')
                  : context.t('Adicionar novo documento', 'Add new document'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.t('Histórico de envios', 'Submission history'),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...documents.map((doc) => _buildHistoryCard(context, doc)),
      ],
    );
  }

  void _openDetails(BuildContext context, DocumentEntity? document) {
    context.push(
      '/document-details',
      extra: {
        'type': type,
        'document': document,
        'cubit': cubit,
      },
    ).then((value) {
      if (value == true) {
        cubit.loadDocuments();
      }
    });
  }

  Widget _buildHistoryCard(BuildContext context, DocumentEntity document) {
    Color statusColor = AppColors.primary;
    String statusText = '';

    switch (document.status) {
      case DocumentStatus.aprovado:
        statusColor = AppColors.primary;
        statusText = context.t('Aprovado', 'Approved');
        break;
      case DocumentStatus.pendente:
        statusColor = Colors.orange;
        statusText = context.t('Pendente de aprovação', 'Pending approval');
        break;
      case DocumentStatus.recusado:
      case DocumentStatus.expirado:
        statusColor = AppColors.error;
        statusText = document.status == DocumentStatus.recusado
            ? context.t('Recusado', 'Rejected')
            : context.t('Expirado', 'Expired');
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => _openDetails(context, document),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.03),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _isPdf(document)
                      ? AppColors.error.withValues(alpha: 0.1)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _isPdf(document)
                      ? const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: AppColors.error,
                          size: 28,
                        )
                      : document.imageUrl != null
                          ? Image.network(
                              document.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.description_outlined,
                                size: 24,
                              ),
                            )
                          : const Icon(Icons.description_outlined, size: 24),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(builder: (context) {
                      if (type == DocumentType.visto &&
                          document.visaCountry?.isNotEmpty == true) {
                        final country = countryByCode(document.visaCountry);
                        if (country != null) {
                          final flagChars =
                              country.code.toUpperCase().codeUnits;
                          final flag = flagChars.length == 2
                              ? String.fromCharCode(
                                      0x1F1E6 - 0x41 + flagChars[0]) +
                                  String.fromCharCode(
                                      0x1F1E6 - 0x41 + flagChars[1])
                              : '🏳';
                          return Row(
                            children: [
                              Text(flag, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  country.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }
                      }

                      return Text(
                        document.title?.isNotEmpty == true
                            ? document.title!
                            : _documentTypeLabel(context, type),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                    if (type == DocumentType.visto &&
                        document.visaCountry?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        document.title?.isNotEmpty == true
                            ? document.title!
                            : _documentTypeLabel(context, type),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (document.documentNumber?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.t('Nº ', 'No. ') + document.documentNumber!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      context.t('Enviado em: ', 'Submitted on: ') +
                          (document.uploadDate != null
                              ? "${document.uploadDate!.day}/${document.uploadDate!.month}/${document.uploadDate!.year}"
                              : context.t('N/D', 'N/A')),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPdf(DocumentEntity document) {
    final url = document.imageUrl?.toLowerCase() ?? '';
    return url.contains('.pdf') || url.contains('/pdf');
  }
}

class _HistoryIntro extends StatelessWidget {
  final DocumentType type;

  const _HistoryIntro({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.folder_copy_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _documentTypeLabel(context, type),
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.t(
                    'Acompanhe o envio atual e substitua o arquivo quando necessário.',
                    'Track the current submission and replace the file when needed.',
                  ),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyHistoryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.t('Nenhum documento enviado', 'No document submitted'),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.t(
                  'Toque para anexar um PDF ou imagem e enviar para análise.',
                  'Tap to attach a PDF or image and submit for review.',
                ),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
