import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';

class DocumentsAlertCard extends StatelessWidget {
  const DocumentsAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        context.push('/documents').then((_) {
          if (context.mounted) {
            context.read<DocumentsCubit>().loadDocuments();
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.red.withOpacity(0.15)
              : const Color(0xFFFFF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.red.withOpacity(0.3)
                : const Color(0xFFFFD1D1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red.withOpacity(0.2)
                    : const Color(0xFFFFE3E3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_late_outlined,
                color: Color(0xFFE53935),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      'Documentos Pendentes',
                      'Pending Documents',
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.red[200] : const Color(0xFFC62828),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      'Regularize seus documentos obrigatórios para a viagem.',
                      'Please upload your mandatory documents for the trip.',
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? Colors.red[100] : const Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.red[200] : const Color(0xFFC62828),
            ),
          ],
        ),
      ),
    );
  }
}
