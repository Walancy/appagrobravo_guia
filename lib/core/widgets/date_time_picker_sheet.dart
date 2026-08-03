import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:intl/intl.dart';

/// Bottom sheet com seletor estilo roda iOS/Cupertino para Data e Hora.
/// Funciona identicamente no iOS e Android.
/// Retorna [DateTime] com a data e hora selecionadas, ou null se cancelado.
class DateTimePickerSheet extends StatefulWidget {
  final DateTime? initial;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final CupertinoDatePickerMode mode;

  const DateTimePickerSheet({
    super.key,
    this.initial,
    this.firstDate,
    this.lastDate,
    this.mode = CupertinoDatePickerMode.dateAndTime,
  });

  /// Abre o bottom sheet e retorna o [DateTime] selecionado, ou null.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initial,
    DateTime? firstDate,
    DateTime? lastDate,
    CupertinoDatePickerMode mode = CupertinoDatePickerMode.dateAndTime,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DateTimePickerSheet(
        initial: initial,
        firstDate: firstDate,
        lastDate: lastDate,
        mode: mode,
      ),
    );
  }

  @override
  State<DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<DateTimePickerSheet> {
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.initial ?? DateTime.now();
  }

  void _confirm() {
    if (widget.firstDate != null &&
        _selectedDateTime.isBefore(
          widget.firstDate!.subtract(const Duration(seconds: 30)),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Escolha uma data/hora válida.',
              'Choose a valid date/time.',
            ),
          ),
        ),
      );
      return;
    }

    if (widget.lastDate != null &&
        _selectedDateTime.isAfter(
          widget.lastDate!.add(const Duration(seconds: 30)),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'A data/hora não pode ser no futuro.',
              'The date/time cannot be in the future.',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.pop(context, _selectedDateTime);
  }

  String _formatPreview() {
    if (widget.mode == CupertinoDatePickerMode.date) {
      return DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR')
          .format(_selectedDateTime);
    } else if (widget.mode == CupertinoDatePickerMode.time) {
      return DateFormat("HH:mm", 'pt_BR').format(_selectedDateTime);
    }
    return DateFormat("EEE, dd 'de' MMMM 'de' yyyy 'às' HH:mm", 'pt_BR')
        .format(_selectedDateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
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
            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('Escolher data e hora', 'Choose date and time'),
                          style: AppTextStyles.h3.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatPreview(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── CupertinoDatePicker (Roda de seleção estilo iOS para iOS e Android) ──
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isDark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: widget.mode,
                  initialDateTime: _selectedDateTime,
                  minimumDate: widget.firstDate,
                  maximumDate:
                      widget.lastDate ??
                      DateTime.now().add(const Duration(days: 3650)),
                  use24hFormat: true,
                  onDateTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      _selectedDateTime = newDateTime;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Botões ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
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
                        context.t('Cancelar', 'Cancel'),
                        style: AppTextStyles.button.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.t('Confirmar', 'Confirm'),
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
