import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:intl/intl.dart';
import 'package:agrobravo/core/components/app_text_field.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/widgets/date_time_picker_sheet.dart';
import 'package:agrobravo/core/services/event_alarm_service.dart';
import 'package:agrobravo/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:agrobravo/features/itinerary/domain/entities/guia_evento_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Resultado retornado ao fechar o sheet — permite o card atualizar seu ícone.
class ChecklistResult {
  final GuiaEventoStatus? status;
  final bool alarmScheduled;
  final DateTime? alarmTime;

  const ChecklistResult({
    this.status,
    this.alarmScheduled = false,
    this.alarmTime,
  });
}

class ChecklistBottomSheet extends StatefulWidget {
  final String eventName;
  final String? eventLocation;
  final IconData eventIcon;
  final String groupId;
  final String eventId;

  /// Horário de término do evento — usado para agendar o alarme de checkout.
  /// Quando nulo, nenhum alarme é agendado.
  final DateTime? endDateTime;

  const ChecklistBottomSheet({
    super.key,
    required this.eventName,
    this.eventLocation,
    this.eventIcon = Icons.event_outlined,
    required this.groupId,
    required this.eventId,
    this.endDateTime,
  });

  @override
  State<ChecklistBottomSheet> createState() => _ChecklistBottomSheetState();
}

class _ChecklistBottomSheetState extends State<ChecklistBottomSheet> {
  final TextEditingController _searchController = TextEditingController();

  // Horário editável pelo guia (inicializado com DateTime.now() na abertura de cada ação)
  late TimeOfDay _selectedTime;

  List<Map<String, dynamic>> _allTravelers = [];
  List<Map<String, dynamic>> _filteredTravelers = [];

  GuiaEventoStatus? _guiaStatus;
  bool _isLoading = true;
  bool _isActing = false;
  DateTime? _lastActionTime;
  String? _error;

  // Cores semânticas de cada estágio
  static const Color _checkinColor = Colors.green;
  static final Color _checkoutColor = Colors.orange.shade700;
  static const Color _doneColor = Color(0xFF2E7D32); // green-800

  String get _currentGuiaId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
    _searchController.addListener(_filterTravelers);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Carregamento ─────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final repo = getIt<ItineraryRepository>();

    final results = await Future.wait([
      repo.getGroupParticipants(widget.groupId),
      repo.getEventAttendance(widget.eventId),
      repo.getGuiaEventoStatus(widget.eventId, _currentGuiaId),
    ]);

    if (!mounted) return;

    final participantsResult =
        results[0] as dartz.Either<Exception, List<Map<String, dynamic>>>;
    final attendanceResult =
        results[1] as dartz.Either<Exception, List<String>>;
    final guiaStatusResult =
        results[2] as dartz.Either<Exception, GuiaEventoStatus?>;

    participantsResult.fold(
      (error) => setState(() {
        _error = error.toString();
        _isLoading = false;
      }),
      (participants) {
        final presentUserIds = attendanceResult.getOrElse(() => []);
        final status = guiaStatusResult.getOrElse(() => null);

        final updatedParticipants = participants
            .map((p) => {...p, 'isChecked': presentUserIds.contains(p['userId'])})
            .toList();

        setState(() {
          _allTravelers = updatedParticipants;
          _filteredTravelers = updatedParticipants;
          _guiaStatus = status;
          _isLoading = false;
        });
      },
    );
  }

  void _filterTravelers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTravelers = _allTravelers.where((t) {
        final name = (t['name'] as String? ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  // ─── Helpers de tempo ─────────────────────────────────────────────────────

  /// Converte [_selectedTime] + data atual em um DateTime concreto.
  DateTime get _selectedDateTime {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
  }

  /// Abre o time picker para o guia editar o horário.
  Future<void> _pickTime() async {
    final picked = await DateTimePickerSheet.show(
      context,
      initial: _selectedDateTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = TimeOfDay(hour: picked.hour, minute: picked.minute));
    }
  }

  // ─── Construção da lista de presenças ─────────────────────────────────────

  List<Map<String, dynamic>> get _presencas => _allTravelers
      .map((t) => {
            'user_id': t['userId'] as String,
            'presente': t['isChecked'] == true,
          })
      .toList();

  // ─── Ações ────────────────────────────────────────────────────────────────

  Future<void> _confirmarCheckin() async {
    final now = DateTime.now();
    if (_lastActionTime != null && now.difference(_lastActionTime!).inMilliseconds < 1500) {
      debugPrint('[ChecklistBottomSheet] Check-in ignorado para evitar duplo clique.');
      return;
    }
    _lastActionTime = now;

    setState(() => _isActing = true);
    final repo = getIt<ItineraryRepository>();
    final checkinAt = _selectedDateTime;

    final result = await repo.registrarCheckin(
      widget.eventId,
      _currentGuiaId,
      checkinAt,
      _presencas,
    );

    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t('Erro ao fazer check-in', 'Error on check-in')}: $e')),
        );
      },
      (status) async {
        bool alarmScheduled = false;

        // Agenda alarme SOMENTE se endDateTime estiver disponível
        if (widget.endDateTime != null) {
          await EventAlarmService.instance.agendarAlarmeCheckout(
            eventoId: widget.eventId,
            eventoNome: widget.eventName,
            endDateTime: widget.endDateTime!,
          );
          alarmScheduled = true;
        } else {
          debugPrint(
              '[ChecklistBottomSheet] ⚠ endDateTime é nulo para o evento "${widget.eventName}" — nenhum alarme será agendado.');
        }

        if (mounted) {
          // Fecha o sheet e retorna o resultado para o card atualizar o ícone
          Navigator.of(context).pop(
            ChecklistResult(
              status: status,
              alarmScheduled: alarmScheduled,
              alarmTime: alarmScheduled ? widget.endDateTime : null,
            ),
          );
        }
      },
    );
  }

  Future<void> _confirmarCheckout() async {
    final now = DateTime.now();
    if (_lastActionTime != null && now.difference(_lastActionTime!).inMilliseconds < 1500) {
      debugPrint('[ChecklistBottomSheet] Check-out ignorado para evitar duplo clique.');
      return;
    }
    _lastActionTime = now;

    setState(() => _isActing = true);
    final repo = getIt<ItineraryRepository>();
    final checkoutAt = _selectedDateTime;

    final result = await repo.registrarCheckout(
      widget.eventId,
      _currentGuiaId,
      checkoutAt,
      _presencas,
    );

    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t('Erro ao fazer check-out', 'Error on check-out')}: $e')),
        );
      },
      (status) async {
        // Cancela alarme ao fazer checkout
        await EventAlarmService.instance.cancelarAlarme(widget.eventId);
        if (mounted) {
          setState(() {
            _guiaStatus = status;
            _isActing = false;
          });
        }
      },
    );
  }

  /// Abre diálogo para re-editar o horário do check-in e regrava.
  Future<void> _editarCheckin() async {
    final currentCheckinTime = _guiaStatus?.checkinAt != null
        ? TimeOfDay.fromDateTime(_guiaStatus!.checkinAt!)
        : TimeOfDay.now();

    final currentDt = () {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day,
          currentCheckinTime.hour, currentCheckinTime.minute);
    }();

    final picked = await DateTimePickerSheet.show(context, initial: currentDt);
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(context.t('Editar Check-in', 'Edit Check-in'),
                style: AppTextStyles.h3.copyWith(fontSize: 16)),
          ],
        ),
        content: Text(
          context.t(
            'Confirmar novo horário de check-in: ${DateFormat('HH:mm').format(picked)}?',
            'Confirm new check-in time: ${DateFormat('HH:mm').format(picked)}?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('Cancelar', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('Confirmar', 'Confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActing = true);
    final repo = getIt<ItineraryRepository>();
    final result = await repo.registrarCheckin(
      widget.eventId,
      _currentGuiaId,
      picked,
      _presencas,
    );

    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao editar check-in: $e')),
        );
      },
      (status) {
        setState(() {
          _guiaStatus = status;
          _isActing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Check-in atualizado para ${DateFormat('HH:mm').format(picked)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Abre diálogo de confirmação e descarta o check-in, voltando ao estágio pendente.
  Future<void> _descartarCheckin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.undo_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(context.t('Descartar Check-in', 'Discard Check-in'),
                style: AppTextStyles.h3.copyWith(fontSize: 16)),
          ],
        ),
        content: Text(
          context.t(
            'Tem certeza? O status voltará para pendente.',
            'Are you sure? Status will revert to pending.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('Cancelar', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('Descartar', 'Discard')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActing = true);
    final repo = getIt<ItineraryRepository>();
    final result = await repo.resetarCheckin(widget.eventId, _currentGuiaId);

    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao descartar check-in: $e')),
        );
      },
      (status) {
        // Cancela alarme ao descartar
        EventAlarmService.instance.cancelarAlarme(widget.eventId);
        setState(() {
          _guiaStatus = status;
          _isActing = false;
          _selectedTime = TimeOfDay.now();
        });
      },
    );
  }

  /// Abre diálogo para re-editar o horário do check-out e regrava.
  Future<void> _editarCheckout() async {
    final currentCheckoutTime = _guiaStatus?.checkoutAt != null
        ? TimeOfDay.fromDateTime(_guiaStatus!.checkoutAt!)
        : TimeOfDay.now();

    final currentDt = () {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day,
          currentCheckoutTime.hour, currentCheckoutTime.minute);
    }();

    final picked = await DateTimePickerSheet.show(context, initial: currentDt);
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_outlined, color: AppColors.secondary, size: 20),
            const SizedBox(width: 8),
            Text(context.t('Editar Check-out', 'Edit Check-out'),
                style: AppTextStyles.h3.copyWith(fontSize: 16)),
          ],
        ),
        content: Text(
          context.t(
            'Confirmar novo horário de check-out: ${DateFormat('HH:mm').format(picked)}?',
            'Confirm new check-out time: ${DateFormat('HH:mm').format(picked)}?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('Cancelar', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('Confirmar', 'Confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActing = true);
    final repo = getIt<ItineraryRepository>();
    final result = await repo.registrarCheckout(
      widget.eventId,
      _currentGuiaId,
      picked,
      _presencas,
    );

    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao editar check-out: $e')),
        );
      },
      (status) {
        setState(() {
          _guiaStatus = status;
          _isActing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondary,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Check-out atualizado para ${DateFormat('HH:mm').format(picked)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleSelectAll() {
    final allChecked = _allTravelers.every((t) => t['isChecked'] == true);
    setState(() {
      for (final t in _allTravelers) {
        t['isChecked'] = !allChecked;
      }
      _filterTravelers();
    });
  }

  bool get _allSelected =>
      _allTravelers.isNotEmpty &&
      _allTravelers.every((t) => t['isChecked'] == true);

  int get _checkedCount =>
      _allTravelers.where((t) => t['isChecked'] == true).length;

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _buildEventInfo(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Text('${context.t('Erro', 'Error')}: $_error'),
                  ),
                )
              else
                Expanded(child: _buildStageContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checklist',
                style: AppTextStyles.h2.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                context.t(
                  'Gerencie a presença de viajantes na atividade',
                  'Manage traveler attendance for the activity',
                ),
                style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEventInfo() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.eventIcon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.eventName,
                style: AppTextStyles.h3.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.eventLocation != null)
                Text(
                  widget.eventLocation!,
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final status = _guiaStatus;

    if (status == null || status.isPendente) {
      return _badge(
        color: Colors.grey,
        icon: Icons.radio_button_unchecked,
        label: context.t('Pendente', 'Pending'),
      );
    }
    if (status.isCheckinFeito) {
      final time = status.checkinAt != null
          ? DateFormat('HH:mm').format(status.checkinAt!)
          : '--:--';
      return _badge(
        color: _checkinColor,
        icon: Icons.login_rounded,
        label: 'Check-in · $time',
      );
    }
    final time = status.checkoutAt != null
        ? DateFormat('HH:mm').format(status.checkoutAt!)
        : '--:--';
    return _badge(
      color: _doneColor,
      icon: Icons.task_alt_rounded,
      label: 'Concluído · $time',
    );
  }

  Widget _badge({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Roteamento de estágio ────────────────────────────────────────────────

  Widget _buildStageContent() {
    final status = _guiaStatus;
    if (status == null || status.isPendente) return _buildStagePendente();
    if (status.isCheckinFeito) return _buildStageCheckin();
    return _buildStageConcluido();
  }

  // ─── Estágio 1 — Pendente (fazer check-in) ────────────────────────────────

  Widget _buildStagePendente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimePicker(
          label: context.t('Horário do Check-in', 'Check-in Time'),
          accentColor: _checkinColor,
        ),
        const SizedBox(height: 12),
        _buildSelectAllBar(),
        const SizedBox(height: 8),
        AppTextField(
          controller: _searchController,
          hint: context.t('Buscar por nome', 'Search by name'),
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildGrid(interactive: true)),
        _buildActionButton(
          label: context.t('Confirmar Check-in', 'Confirm Check-in'),
          icon: Icons.login_rounded,
          color: _checkinColor,
          onPressed: _confirmarCheckin,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Estágio 2 — Check-in feito (fazer check-out) ─────────────────────────

  Widget _buildStageCheckin() {
    final checkinStr = _guiaStatus?.checkinAt != null
        ? DateFormat('HH:mm').format(_guiaStatus!.checkinAt!)
        : '--:--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Faixa contextual laranja
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _checkoutColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _checkoutColor.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: _checkoutColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t(
                    'Check-in registrado às $checkinStr — registre a saída quando terminar.',
                    'Check-in at $checkinStr — register departure when done.',
                  ),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _checkoutColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Ações de edição do check-in
        Row(
          children: [
            TextButton.icon(
              onPressed: _isActing ? null : _editarCheckin,
              icon: Icon(Icons.edit_outlined, size: 14, color: _checkoutColor.withOpacity(0.8)),
              label: Text(
                context.t('Editar check-in', 'Edit check-in'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: _checkoutColor.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: _isActing ? null : _descartarCheckin,
              icon: const Icon(Icons.undo_rounded, size: 14, color: Colors.red),
              label: Text(
                context.t('Descartar', 'Discard'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildTimePicker(
          label: context.t('Horário do Check-out', 'Check-out Time'),
          accentColor: _checkoutColor,
        ),
        const SizedBox(height: 12),
        _buildSelectAllBar(),
        const SizedBox(height: 8),
        AppTextField(
          controller: _searchController,
          hint: context.t('Buscar por nome', 'Search by name'),
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildGrid(interactive: true)),
        _buildActionButton(
          label: context.t('Confirmar Check-out', 'Confirm Check-out'),
          icon: Icons.logout_rounded,
          color: _checkoutColor,
          onPressed: _confirmarCheckout,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Estágio 3 — Concluído ────────────────────────────────────────────────

  Widget _buildStageConcluido() {
    final total = _allTravelers.length;
    final present = _checkedCount;

    return Column(
      children: [
        // Resumo de horários
        _buildConclusionSummary(),
        const SizedBox(height: 8),
        // Botão de editar check-out
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isActing ? null : _editarCheckout,
            icon: Icon(Icons.edit_outlined, size: 14, color: _doneColor.withOpacity(0.7)),
            label: Text(
              context.t('Editar check-out', 'Edit check-out'),
              style: AppTextStyles.bodySmall.copyWith(
                color: _doneColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _doneColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _doneColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.task_alt_rounded, color: _doneColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t(
                    '$present de $total passageiros presentes',
                    '$present of $total travelers present',
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _doneColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Opacity(
            opacity: 0.75,
            child: _buildGrid(interactive: false),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(context.t('Fechar', 'Close')),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildConclusionSummary() {
    final status = _guiaStatus;
    if (status == null) return const SizedBox.shrink();

    final checkinStr = status.checkinAt != null
        ? DateFormat('HH:mm').format(status.checkinAt!)
        : '--:--';
    final checkoutStr = status.checkoutAt != null
        ? DateFormat('HH:mm').format(status.checkoutAt!)
        : '--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _doneColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _doneColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _timeInfo(Icons.login_rounded, _checkinColor, context.t('Check-in', 'Check-in'), checkinStr),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1, color: Colors.grey.withOpacity(0.2)),
          ),
          const SizedBox(width: 8),
          _timeInfo(Icons.logout_rounded, _checkoutColor, context.t('Check-out', 'Check-out'), checkoutStr),
        ],
      ),
    );
  }

  Widget _timeInfo(IconData icon, Color color, String label, String time) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey, fontSize: 10)),
        Text(time, style: AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  // ─── Componentes reutilizáveis ────────────────────────────────────────────

  /// Campo de horário editável. Mostra o horário selecionado e abre o time picker ao tocar.
  Widget _buildTimePicker({required String label, required Color accentColor}) {
    final timeStr = _selectedTime.format(context);
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, color: accentColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    timeStr,
                    style: AppTextStyles.h3.copyWith(color: accentColor, fontSize: 22),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: accentColor.withOpacity(0.6), size: 18),
            const SizedBox(width: 4),
            Text(
              context.t('Editar', 'Edit'),
              style: AppTextStyles.bodySmall.copyWith(color: accentColor.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectAllBar() {
    final label = _allSelected
        ? context.t('Limpar seleção', 'Clear selection')
        : context.t('Selecionar todos', 'Select all');
    final icon = _allSelected ? Icons.check_box_outlined : Icons.check_box_outline_blank;

    return Row(
      children: [
        GestureDetector(
          onTap: _toggleSelectAll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          '${_checkedCount}/${_allTravelers.length} ${context.t('presentes', 'present')}',
          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isActing ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          icon: _isActing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 20),
          label: Text(label),
        ),
      ),
    );
  }

  // ─── Grid de passageiros ─────────────────────────────────────────────────

  Widget _buildGrid({required bool interactive}) {
    if (_filteredTravelers.isEmpty) {
      return Center(
        child: Text(context.t('Nenhum viajante encontrado.', 'No travelers found.')),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.7,
      ),
      itemCount: _filteredTravelers.length,
      itemBuilder: (context, index) {
        final traveler = _filteredTravelers[index];
        return _buildTravelerItem(traveler, interactive: interactive);
      },
    );
  }

  Widget _buildTravelerItem(
    Map<String, dynamic> traveler, {
    required bool interactive,
  }) {
    final isChecked = traveler['isChecked'] == true;
    final avatarUrl = traveler['avatar'];
    final name = traveler['name'] ?? context.t('Viajante', 'Traveler');
    final role = traveler['role'] ?? context.t('Participante', 'Participant');

    return GestureDetector(
      onTap: interactive
          ? () {
              setState(() {
                traveler['isChecked'] = !isChecked;
                final idx = _allTravelers.indexWhere(
                    (t) => t['userId'] == traveler['userId']);
                if (idx != -1) {
                  _allTravelers[idx]['isChecked'] = traveler['isChecked'];
                }
              });
            }
          : null,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).dividerColor.withOpacity(0.03),
                  border: Border.all(
                    color: isChecked ? AppColors.primary : Colors.transparent,
                    width: isChecked ? 3 : 0,
                  ),
                  image: avatarUrl != null && avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                    : null,
              ),
              if (isChecked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            role,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.grey,
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
