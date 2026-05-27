import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/features/profile/domain/entities/profile_entity.dart';
import 'package:agrobravo/features/home/domain/entities/mission_entity.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_state.dart';
import 'package:agrobravo/features/documents/domain/entities/document_entity.dart';
import 'package:agrobravo/features/documents/domain/entities/document_enums.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<DocumentsCubit>()..loadDocuments(),
      child: Scaffold(
        appBar: AppHeader(
          mode: HeaderMode.back,
          title: context.t('Meus documentos', 'My documents'),
        ),
        body: BlocBuilder<DocumentsCubit, DocumentsState>(
          builder: (context, state) {
            return state.when(
              initial: () => const SizedBox.shrink(),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (message) => Center(child: Text(message)),
              loaded: (documents, isAlertDismissed, profile, mission) {
                return _buildBody(context, documents, profile, mission);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<DocumentEntity> documents,
    ProfileEntity? profile,
    MissionEntity? mission,
  ) {
    // List of all types that should be visible
    final allTypes = [
      DocumentType.passaporte,
      DocumentType.visto,
      DocumentType.vacina,
      DocumentType.seguro,
      DocumentType.carteiraMotorista,
      DocumentType.autorizacaoMenores,
    ];

    return RefreshIndicator(
      onRefresh: () => context.read<DocumentsCubit>().loadDocuments(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            context.t('Pendências e Atualizações', 'Pending & Updates'),
            style: AppTextStyles.h3.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.t(
              'Mantenha seus documentos em dia para sua viagem.',
              'Keep your documents up to date for your trip.',
            ),
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          ...allTypes.map((type) {
            final doc = documents.cast<DocumentEntity?>().firstWhere(
              (d) => d?.type == type,
              orElse: () => null,
            );
            return _DocumentTypeButton(
              type: type,
              document: doc,
              profile: profile,
              mission: mission,
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DocumentTypeButton extends StatelessWidget {
  final DocumentType type;
  final DocumentEntity? document;
  final ProfileEntity? profile;
  final MissionEntity? mission;

  const _DocumentTypeButton({
    required this.type,
    this.document,
    this.profile,
    this.mission,
  });

  String _getTypeLabel(BuildContext context, DocumentType type) {
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
        return context.t('Carteira de Motorista', 'Driver\'s License');
      case DocumentType.autorizacaoMenores:
        return context.t('Autorização de Menores', 'Minor Authorization');
      case DocumentType.outro:
        return context.t('Outro', 'Other');
    }
  }

  String _getStatusText(BuildContext context) {
    if (document == null) return context.t('Pendente de envio', 'Pending upload');
    if (document!.status == DocumentStatus.pendente) {
      return context.t('Aguardando aprovação', 'Awaiting approval');
    }
    if (document!.status == DocumentStatus.aprovado) {
      return context.t('Documento em dia', 'Document up to date');
    }
    if (document!.status == DocumentStatus.recusado) {
      return context.t('Recusado - Clique para reenviar', 'Rejected - Tap to resubmit');
    }
    if (document!.status == DocumentStatus.expirado) {
      return context.t('Expirado - Clique para atualizar', 'Expired - Tap to update');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Age
    bool isUnder18 = false;
    if (profile?.birthDate != null) {
      final today = DateTime.now();
      final birthDate = profile!.birthDate!;
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      isUnder18 = age < 18;
    }

    // MANDATORY LOGIC
    bool isTypeMandatory = false;

    if (mission != null) {
      switch (type) {
        case DocumentType.passaporte:
          isTypeMandatory = mission!.passaporteObrigatorio;
          break;
        case DocumentType.visto:
          isTypeMandatory = mission!.vistoObrigatorio;
          break;
        case DocumentType.vacina:
          isTypeMandatory = mission!.vacinaObrigatoria;
          break;
        case DocumentType.seguro:
          // O seguro viagem é gerado pelo painel administrativo, então não é exigido do viajante
          isTypeMandatory = false;
          break;
        case DocumentType.carteiraMotorista:
          isTypeMandatory = mission!.carteiraObrigatoria;
          break;
        case DocumentType.autorizacaoMenores:
          isTypeMandatory = mission!.autorizacaoObrigatoria && isUnder18;
          break;
        case DocumentType.outro:
          isTypeMandatory = false;
          break;
      }
    } else {
      // Se não estiver em nenhuma missão não precisamos cobrar os documentos
      isTypeMandatory = false;
    }

    bool isPending = false;
    if (document == null) {
      // If document is missing, it's only pending if it's mandatory
      isPending = isTypeMandatory;
    } else {
      // If document exists, it's pending if status is PENDENTE
      isPending = document!.status == DocumentStatus.pendente;
    }

    final bool isAlert =
        document != null &&
        (document!.status == DocumentStatus.recusado ||
            document!.status == DocumentStatus.expirado);

    // Status visual
    Color statusColor = AppColors.primary;
    if (document == null) {
      statusColor = isPending ? Colors.orange : Colors.grey;
    } else {
      switch (document!.status) {
        case DocumentStatus.aprovado:
          statusColor = AppColors.primary;
          break;
        case DocumentStatus.pendente:
          statusColor = Colors.orange;
          break;
        case DocumentStatus.recusado:
        case DocumentStatus.expirado:
          statusColor = AppColors.error;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () {
          final isHistoryType = type == DocumentType.seguro ||
              type == DocumentType.visto ||
              type == DocumentType.vacina;

          if (isHistoryType) {
            context.push(
              '/document-history',
              extra: {
                'type': type,
                'cubit': context.read<DocumentsCubit>(),
              },
            ).then((value) {
              if (context.mounted) {
                context.read<DocumentsCubit>().loadDocuments();
              }
            });
          } else {
            context.push(
              '/document-details',
              extra: {
                'type': type,
                'document': document,
                'cubit': context.read<DocumentsCubit>(),
              },
            ).then((value) {
              if (value == true && context.mounted) {
                context.read<DocumentsCubit>().loadDocuments();
              }
            });
          }
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: (isPending || isAlert)
                  ? statusColor.withOpacity(0.5)
                  : Theme.of(context).dividerColor.withOpacity(0.1),
              width: (isPending || isAlert) ? 1.5 : 1,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIcon(type), color: statusColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTypeLabel(context, type),
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getStatusText(context),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: (isPending || isAlert)
                            ? statusColor
                            : AppColors.textSecondary,
                        fontWeight: (isPending || isAlert)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPending || isAlert)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 12,
                  ),
                )
              else
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(DocumentType type) {
    switch (type) {
      case DocumentType.passaporte:
        return Icons.auto_stories;
      case DocumentType.visto:
        return Icons.public;
      case DocumentType.vacina:
        return Icons.vaccines;
      case DocumentType.seguro:
        return Icons.health_and_safety;
      case DocumentType.carteiraMotorista:
        return Icons.directions_car;
      case DocumentType.autorizacaoMenores:
        return Icons.family_restroom;
      case DocumentType.outro:
        return Icons.description;
    }
  }
}
