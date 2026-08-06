import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';

/// Modelo de uma ação para o [ActionsBottomSheet].
class BottomSheetAction {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const BottomSheetAction({
    required this.label,
    required this.icon,
    this.color,
    required this.onTap,
  });
}

/// Bottom sheet de ações no mesmo estilo visual do [CustomConfirmBottomSheet].
/// Drag handle + botões de ação empilhados + cancelar — limpo e consistente.
///
/// Uso:
/// ```dart
/// ActionsBottomSheet.show(
///   context,
///   actions: [
///     BottomSheetAction(label: 'Editar', icon: Icons.edit_outlined, onTap: _edit),
///     BottomSheetAction(label: 'Excluir', icon: Icons.delete_outline_rounded, color: Colors.red, onTap: _delete),
///   ],
/// );
/// ```
class ActionsBottomSheet extends StatelessWidget {
  final List<BottomSheetAction> actions;
  final String? title;

  const ActionsBottomSheet({
    super.key,
    required this.actions,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required List<BottomSheetAction> actions,
    String? title,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => ActionsBottomSheet(actions: actions, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 20),
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: onSurface,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Botões de ação empilhados
              ...actions.map((action) {
                final color = action.color ?? AppColors.primary;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        action.onTap();
                      },
                      icon: Icon(action.icon, size: 18),
                      label: Text(
                        action.label,
                        style: AppTextStyles.button.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // Cancelar
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Cancelar',
                    style: AppTextStyles.button.copyWith(
                      color: onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
