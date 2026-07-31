import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:agrobravo/core/components/app_text_field.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/widgets/date_time_picker_sheet.dart';
import 'package:agrobravo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:agrobravo/features/notifications/domain/entities/participante_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ReminderModal extends StatefulWidget {
  final String groupId;
  const ReminderModal({super.key, required this.groupId});

  @override
  State<ReminderModal> createState() => _ReminderModalState();
}

class _ReminderModalState extends State<ReminderModal> {
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingToAll = true;
  bool _isAgendando = false;
  bool _agendandoSemHorario = false; // flag para indicar erro visual
  DateTime? _agendadoPara;
  List<ParticipanteEntity> _participantes = [];
  final Set<String> _selectedIds = {};
  bool _loadingParticipantes = true;

  @override
  void initState() {
    super.initState();
    _loadParticipantes();
  }

  Future<void> _loadParticipantes() async {
    final repo = getIt<NotificationsRepository>();
    final result = await repo.getGrupoParticipantes(widget.groupId);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loadingParticipantes = false),
      (list) {
        setState(() {
          _participantes = list;
          _selectedIds.addAll(list.map((p) => p.id));
          _loadingParticipantes = false;
        });
      },
    );
  }

  Future<void> _pickDateTime() async {
    final result = await DateTimePickerSheet.show(
      context,
      initial: _agendadoPara,
    );
    if (result != null && mounted) {
      setState(() {
        _agendadoPara = result;
        _agendandoSemHorario = false; // horário definido, remove erro
      });
    }
  }

  Future<void> _send() async {
    final text = _descriptionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.t('Digite uma mensagem.', 'Type a message.'))),
      );
      return;
    }

    if (!_isSendingToAll && _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'Selecione ao menos um destinatário.',
            'Select at least one recipient.',
          )),
        ),
      );
      return;
    }

    // Valida horário obrigatório quando agendando
    if (_isAgendando && _agendadoPara == null) {
      setState(() => _agendandoSemHorario = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'Defina a data e hora do agendamento.',
            'Set the date and time for scheduling.',
          )),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = getIt<NotificationsRepository>();
      final destinatarios = _isSendingToAll ? null : _selectedIds.toList();
      final title = context.t('Lembrete do Guia', 'Guide Reminder');

      final result = _isAgendando
          ? await repo.agendarLembrete(
              groupId: widget.groupId,
              title: title,
              message: text,
              agendadoPara: _agendadoPara!,
              destinatarios: destinatarios,
            )
          : await repo.sendGroupNotification(
              groupId: widget.groupId,
              title: title,
              message: text,
              destinatarios: destinatarios,
            );

      if (!mounted) return;

      result.fold(
        (l) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${l.toString()}')),
        ),
        (_) {
          Navigator.pop(context);
          final msg = _isAgendando
              ? context.t('Lembrete agendado!', 'Reminder scheduled!')
              : context.t('Lembrete enviado!', 'Reminder sent!');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('Novo lembrete', 'New reminder'),
                              style: AppTextStyles.h3.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              context.t(
                                'Envie ou agende um lembrete',
                                'Send or schedule a reminder',
                              ),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.t('Histórico', 'History'),
                        icon: Icon(
                          Icons.history_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(
                              '/lembretes-historico/${widget.groupId}');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Toggle: Enviar para todos
                        _buildToggleTodos(context, isDark),
                        if (!_isSendingToAll) ...[
                          const SizedBox(height: 12),
                          _buildParticipantesList(context, isDark),
                        ],
                        const SizedBox(height: 12),
                        // Toggle: Agendar
                        _buildToggleAgendar(context, isDark),
                        if (_isAgendando) ...[
                          const SizedBox(height: 12),
                          _buildDateTimePicker(context, isDark),
                        ],
                        const SizedBox(height: 16),
                        AppTextField(
                          label: context.t('Mensagem', 'Message'),
                          controller: _descriptionController,
                          hint: context.t(
                              'Escreva o lembrete...', 'Write the reminder...'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                      color: Theme.of(context).dividerColor),
                                ),
                                child: Text(
                                  context.t('Voltar', 'Back'),
                                  style: AppTextStyles.button.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _send,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isAgendando
                                                ? Icons.schedule_rounded
                                                : Icons.send_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isAgendando
                                                ? context.t('Agendar', 'Schedule')
                                                : context.t('Enviar', 'Send'),
                                            style: AppTextStyles.button.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Toggles e pickers ─────────────────────────────────────────────────────

  Widget _buildToggleTodos(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.group_outlined, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.t('Enviar para todos', 'Send to everyone'),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          CupertinoSwitch(
            value: _isSendingToAll,
            activeTrackColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _isSendingToAll = val;
                if (val) {
                  _selectedIds
                    ..clear()
                    ..addAll(_participantes.map((p) => p.id));
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleAgendar(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: _isAgendando
            ? AppColors.primary.withValues(alpha: 0.08)
            : isDark
                ? Colors.grey[850]
                : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        border: _isAgendando
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 20,
            color: _isAgendando
                ? AppColors.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.t('Agendar envio', 'Schedule sending'),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: _isAgendando
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          CupertinoSwitch(
            value: _isAgendando,
            activeTrackColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _isAgendando = val;
                if (!val) {
                  _agendadoPara = null;
                  _agendandoSemHorario = false;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker(BuildContext context, bool isDark) {
    final fmt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');
    final hasError = _agendandoSemHorario && _agendadoPara == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasError
                    ? Colors.red
                    : _agendadoPara != null
                        ? AppColors.primary
                        : Theme.of(context).dividerColor,
                width: hasError ? 1.5 : 1,
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: hasError
                      ? Colors.red
                      : _agendadoPara != null
                          ? AppColors.primary
                          : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _agendadoPara != null
                        ? fmt.format(_agendadoPara!.toLocal())
                        : context.t(
                            'Toque para escolher data e hora',
                            'Tap to choose date and time',
                          ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: hasError
                          ? Colors.red
                          : _agendadoPara != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.grey,
                      fontWeight: _agendadoPara != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: hasError ? Colors.red : Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        // Mensagem de erro quando agendando sem horário
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  context.t(
                    'Defina a data e hora para agendar',
                    'Set the date and time to schedule',
                  ),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildParticipantesList(BuildContext context, bool isDark) {
    if (_loadingParticipantes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_participantes.isEmpty) {
      return Center(
        child: Text(
          context.t(
              'Nenhum participante encontrado.', 'No participants found.'),
          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                context.t('Destinatários', 'Recipients'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  if (_selectedIds.length == _participantes.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(_participantes.map((p) => p.id));
                  }
                }),
                child: Text(
                  _selectedIds.length == _participantes.length
                      ? context.t('Desmarcar todos', 'Deselect all')
                      : context.t('Selecionar todos', 'Select all'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _participantes.length,
            separatorBuilder: (_, i) =>
                Divider(height: 1, color: Theme.of(context).dividerColor),
            itemBuilder: (context, index) {
              final p = _participantes[index];
              final isSelected = _selectedIds.contains(p.id);
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedIds.remove(p.id);
                  } else {
                    _selectedIds.add(p.id);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: p.foto != null
                            ? CachedNetworkImageProvider(p.foto!)
                            : null,
                        child: p.foto == null
                            ? Text(
                                p.nome.isNotEmpty
                                    ? p.nome[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nome,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (p.isGuia)
                              Text(
                                context.t('Guia', 'Guide'),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: isSelected,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) => setState(() {
                          if (val == true) {
                            _selectedIds.add(p.id);
                          } else {
                            _selectedIds.remove(p.id);
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            '${_selectedIds.length} de ${_participantes.length} selecionado(s)',
            '${_selectedIds.length} of ${_participantes.length} selected',
          ),
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
