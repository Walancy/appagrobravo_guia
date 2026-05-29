import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:intl/intl.dart';

/// Bottom sheet que combina calendário + seletor de hora/minuto.
/// Retorna [DateTime] com a data e hora selecionadas, ou null se cancelado.
class DateTimePickerSheet extends StatefulWidget {
  final DateTime? initial;
  final DateTime firstDate;

  const DateTimePickerSheet({
    super.key,
    this.initial,
    required this.firstDate,
  });

  /// Abre o bottom sheet e retorna o [DateTime] selecionado, ou null.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initial,
  }) {
    final now = DateTime.now();
    final minDate = now.add(const Duration(minutes: 1));
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DateTimePickerSheet(
        initial: initial,
        firstDate: minDate,
      ),
    );
  }

  @override
  State<DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<DateTimePickerSheet> {
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? widget.firstDate;
    _selectedDate = DateTime(init.year, init.month, init.day);
    _selectedHour = init.hour;
    _selectedMinute = (init.minute ~/ 5) * 5; // arredonda para múltiplo de 5

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute ~/ 5);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _confirm() {
    final result = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedHour,
      _selectedMinute,
    );

    if (result.isBefore(widget.firstDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Escolha uma data/hora futura.',
              'Choose a future date/time.',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = DateFormat("dd/MM/yyyy", 'pt_BR');

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
            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B6EF5).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: Color(0xFF5B6EF5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.t('Escolher data e hora', 'Choose date and time'),
                    style: AppTextStyles.h3.copyWith(fontSize: 17),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Calendário ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: widget.firstDate,
                lastDate: DateTime.now().add(const Duration(days: 365)),
                onDateChanged: (d) =>
                    setState(() => _selectedDate = d),
              ),
            ),

            // ── Seletor de hora/minuto ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Color(0xFF5B6EF5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.t('Horário', 'Time'),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: const Color(0xFF5B6EF5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF5B6EF5).withValues(alpha: 0.25),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        // Horas
                        Expanded(child: _buildWheelColumn(
                          label: context.t('Hora', 'Hour'),
                          controller: _hourController,
                          items: List.generate(24, (i) => i.toString().padLeft(2, '0')),
                          onChanged: (i) => setState(() => _selectedHour = i),
                        )),
                        // Separador
                        Text(
                          ':',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        // Minutos (de 5 em 5)
                        Expanded(child: _buildWheelColumn(
                          label: context.t('Min', 'Min'),
                          controller: _minuteController,
                          items: List.generate(12, (i) => (i * 5).toString().padLeft(2, '0')),
                          onChanged: (i) => setState(() => _selectedMinute = i * 5),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Preview do resultado
                  Center(
                    child: Text(
                      '${fmt.format(_selectedDate)} às '
                      '${_selectedHour.toString().padLeft(2, '0')}:'
                      '${_selectedMinute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: const Color(0xFF5B6EF5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
                        backgroundColor: const Color(0xFF5B6EF5),
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

  Widget _buildWheelColumn({
    required String label,
    required FixedExtentScrollController controller,
    required List<String> items,
    required void Function(int index) onChanged,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 100,
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            perspective: 0.003,
            diameterRatio: 1.8,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildListDelegate(
              children: items.map((item) {
                return Center(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
