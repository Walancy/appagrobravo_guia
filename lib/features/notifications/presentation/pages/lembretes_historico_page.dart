import 'package:flutter/material.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/widgets/date_time_picker_sheet.dart';
import 'package:agrobravo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:agrobravo/features/notifications/domain/entities/lembrete_entity.dart';
import 'package:agrobravo/features/notifications/domain/entities/participante_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LembretesHistoricoPage extends StatefulWidget {
  final String groupId;
  const LembretesHistoricoPage({super.key, required this.groupId});

  @override
  State<LembretesHistoricoPage> createState() => _LembretesHistoricoPageState();
}

class _LembretesHistoricoPageState extends State<LembretesHistoricoPage>
    with SingleTickerProviderStateMixin {
  List<LembreteEntity> _lembretes = [];
  bool _isLoading = true;
  String? _error;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final repo = getIt<NotificationsRepository>();
    final result = await repo.getLembretesHistorico(widget.groupId);
    if (!mounted) return;
    result.fold(
      (e) => setState(() {
        _error = e.toString();
        _isLoading = false;
      }),
      (list) => setState(() {
        _lembretes = list;
        _isLoading = false;
      }),
    );
  }

  List<LembreteEntity> get _agendados =>
      _lembretes.where((l) => l.isAgendado).toList();
  List<LembreteEntity> get _enviados =>
      _lembretes.where((l) => l.isEnviado).toList();

  Future<void> _cancelar(LembreteEntity lembrete) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('Cancelar lembrete', 'Cancel reminder')),
        content: Text(context.t(
          'Tem certeza que deseja cancelar este lembrete agendado?',
          'Are you sure you want to cancel this scheduled reminder?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('Não', 'No')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.t('Cancelar lembrete', 'Cancel reminder'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final repo = getIt<NotificationsRepository>();
    final result = await repo.cancelarLembrete(lembrete.id);
    if (!mounted) return;
    result.fold(
      (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      ),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('Lembrete cancelado.', 'Reminder cancelled.'))),
        );
        _load();
      },
    );
  }

  Future<void> _enviarAgora(LembreteEntity lembrete) async {
    final fmt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');
    final agendadoStr = lembrete.agendadoPara != null
        ? fmt.format(lembrete.agendadoPara!.toLocal())
        : '—';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF00B289).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF00B289)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.t('Enviar agora?', 'Send now?'),
                style: AppTextStyles.h3.copyWith(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'Este lembrete estava agendado para:',
                'This reminder was scheduled for:',
              ),
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              agendadoStr,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B6EF5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.t(
                'Deseja enviar imediatamente sem aguardar o horário?',
                'Do you want to send immediately without waiting?',
              ),
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.t('Não, aguardar', 'No, wait'),
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
            label: Text(
              context.t('Enviar agora', 'Send now'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B289),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final repo = getIt<NotificationsRepository>();
    final result = await repo.enviarLembreteAgora(lembrete.id);
    if (!mounted) return;
    result.fold(
      (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      ),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Lembrete enviado!', 'Reminder sent!')),
            backgroundColor: const Color(0xFF00B289),
          ),
        );
        _load();
      },
    );
  }

  Future<void> _editarLembrete(LembreteEntity lembrete) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = getIt<NotificationsRepository>();

    // Busca participantes para pré-preencher o seletor
    final participantesResult =
        await repo.getGrupoParticipantes(widget.groupId);
    if (!mounted) return;

    final participantes = participantesResult.fold((_) => <ParticipanteEntity>[], (l) => l);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditarLembreteSheet(
        lembrete: lembrete,
        participantes: participantes,
        isDark: isDark,
        onSalvar: (mensagem, destinatarios, agendadoPara) async {
          final totalDest =
              destinatarios == null ? participantes.length : destinatarios.length;
          final result = await repo.editarLembrete(
            lembreteId: lembrete.id,
            mensagem: mensagem,
            agendadoPara: agendadoPara,
            destinatarios: destinatarios,
            totalDestinatarios: totalDest,
          );
          if (!mounted) return;
          result.fold(
            (e) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro: ${e.toString()}')),
            ),
            (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      context.t('Lembrete atualizado!', 'Reminder updated!')),
                ),
              );
              _load();
            },
          );
        },
      ),
    );
  }


  Future<void> _showDestinatariosSheet(LembreteEntity lembrete) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final supabase = getIt<SupabaseClient>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DestinatariosSheet(
        lembrete: lembrete,
        groupId: widget.groupId,
        supabase: supabase,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t('Lembretes', 'Reminders'),
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.t('Atualizar', 'Refresh'),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(context.t('Agendados', 'Scheduled')),
                  if (_agendados.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B6EF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_agendados.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(context.t('Enviados', 'Sent')),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAgendadosList(isDark),
                    _buildEnviadosList(isDark),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.grey[400], size: 48),
          const SizedBox(height: 12),
          Text(
            context.t('Erro ao carregar.', 'Error loading.'),
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendadosList(bool isDark) {
    if (_agendados.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    context.t('Nenhum lembrete agendado.', 'No scheduled reminders.'),
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'Crie um lembrete com data e hora para vê-lo aqui.',
                      'Create a reminder with a date and time to see it here.',
                    ),
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _agendados.length,
        separatorBuilder: (_, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final l = _agendados[index];
          return _AgendadoCard(
            lembrete: l,
            isDark: isDark,
            onTapDestinatarios: () => _showDestinatariosSheet(l),
            onCancelar: () => _cancelar(l),
            onEditar: () => _editarLembrete(l),
            onEnviarAgora: () => _enviarAgora(l),
          );
        },
      ),
    );
  }

  Widget _buildEnviadosList(bool isDark) {
    if (_enviados.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    context.t('Nenhum lembrete enviado ainda.', 'No reminders sent yet.'),
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _enviados.length,
        separatorBuilder: (_, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final l = _enviados[index];
          return _LembreteCard(
            lembrete: l,
            isDark: isDark,
            onTap: () => _showDestinatariosSheet(l),
          );
        },
      ),
    );
  }
}

// ─── Card de Agendado ─────────────────────────────────────────────────────────

class _AgendadoCard extends StatelessWidget {
  final LembreteEntity lembrete;
  final bool isDark;
  final VoidCallback onTapDestinatarios;
  final VoidCallback onCancelar;
  final VoidCallback onEditar;
  final VoidCallback onEnviarAgora;

  const _AgendadoCard({
    required this.lembrete,
    required this.isDark,
    required this.onTapDestinatarios,
    required this.onCancelar,
    required this.onEditar,
    required this.onEnviarAgora,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');
    final agendadoStr = lembrete.agendadoPara != null
        ? fmt.format(lembrete.agendadoPara!.toLocal())
        : '—';

    final isParaTodos = lembrete.destinatarios == null;
    final totalStr = isParaTodos
        ? context.t('Todos do grupo', 'Entire group')
        : context.t(
            '${lembrete.totalDestinatarios} pessoa(s)',
            '${lembrete.totalDestinatarios} person(s)',
          );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5B6EF5).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header roxo
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF5B6EF5).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: Color(0xFF5B6EF5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.t('Envio em', 'Sends at')} $agendadoStr',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF5B6EF5),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B6EF5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.t('Agendado', 'Scheduled'),
                    style: const TextStyle(
                      color: Color(0xFF5B6EF5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mensagem
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lembrete.mensagem,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                // Destinatários
                GestureDetector(
                  onTap: onTapDestinatarios,
                  child: Row(
                    children: [
                      Icon(
                        isParaTodos
                            ? Icons.group_outlined
                            : Icons.person_outline_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        totalStr,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Ações: linha 1 — Editar | Cancelar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEditar,
                        icon: const Icon(Icons.edit_rounded, size: 15),
                        label: Text(context.t('Editar', 'Edit')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5B6EF5),
                          side: const BorderSide(color: Color(0xFF5B6EF5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCancelar,
                        icon: const Icon(Icons.cancel_outlined, size: 15),
                        label: Text(context.t('Cancelar', 'Cancel')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Ação: linha 2 — Enviar agora
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onEnviarAgora,
                    icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                    label: Text(
                      context.t('Enviar agora', 'Send now'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B289),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
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

// ─── Bottom Sheet de Destinatários ───────────────────────────────────────────

class _DestinatariosSheet extends StatefulWidget {
  final LembreteEntity lembrete;
  final String groupId;
  final SupabaseClient supabase;
  final bool isDark;

  const _DestinatariosSheet({
    required this.lembrete,
    required this.groupId,
    required this.supabase,
    required this.isDark,
  });

  @override
  State<_DestinatariosSheet> createState() => _DestinatariosSheetState();
}

class _DestinatariosSheetState extends State<_DestinatariosSheet> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      List<String> ids;

      if (widget.lembrete.destinatarios != null) {
        ids = widget.lembrete.destinatarios!;
      } else {
        final participantsRes = await widget.supabase
            .from('gruposParticipantes')
            .select('user_id')
            .eq('grupo_id', widget.groupId);
        final leaderRes = await widget.supabase
            .from('lideresGrupo')
            .select('lider_id')
            .eq('grupo_id', widget.groupId);

        final currentUserId = widget.supabase.auth.currentUser?.id;
        final participantIds =
            (participantsRes as List).map((e) => e['user_id'] as String).toSet();
        final leaderIds =
            (leaderRes as List).map((e) => e['lider_id'] as String).toSet();
        final allIds = {...participantIds, ...leaderIds}..remove(currentUserId);
        ids = allIds.toList();
      }

      if (ids.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final usersRes = await widget.supabase
          .from('users')
          .select('id, nome, foto')
          .inFilter('id', ids);

      if (mounted) {
        setState(() {
          _usuarios = (usersRes as List).cast<Map<String, dynamic>>()
            ..sort((a, b) =>
                (a['nome'] as String? ?? '').compareTo(b['nome'] as String? ?? ''));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParaTodos = widget.lembrete.destinatarios == null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isParaTodos ? Icons.group_rounded : Icons.people_alt_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('Destinatários', 'Recipients'),
                      style: AppTextStyles.h3.copyWith(fontSize: 17),
                    ),
                    Text(
                      isParaTodos
                          ? context.t('Enviado para todos do grupo', 'Sent to entire group')
                          : context.t(
                              '${widget.lembrete.totalDestinatarios} pessoa(s) selecionada(s)',
                              '${widget.lembrete.totalDestinatarios} selected person(s)',
                            ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            )
          else if (_usuarios.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                context.t('Nenhum destinatário encontrado.', 'No recipients found.'),
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _usuarios.length,
                separatorBuilder: (_, i) => Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                ),
                itemBuilder: (context, index) {
                  final u = _usuarios[index];
                  final nome = u['nome'] as String? ?? 'Sem nome';
                  final foto = u['foto'] as String?;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          backgroundImage: foto != null
                              ? CachedNetworkImageProvider(foto)
                              : null,
                          child: foto == null
                              ? Text(
                                  nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            nome,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Card de Enviado ─────────────────────────────────────────────────────────

class _LembreteCard extends StatelessWidget {
  final LembreteEntity lembrete;
  final bool isDark;
  final VoidCallback onTap;

  const _LembreteCard({
    required this.lembrete,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');
    final dateStr = fmt.format(lembrete.createdAt.toLocal());
    final isParaTodos = lembrete.destinatarios == null;
    final totalStr = isParaTodos
        ? context.t('Todos do grupo', 'Entire group')
        : context.t(
            '${lembrete.totalDestinatarios} pessoa(s)',
            '${lembrete.totalDestinatarios} person(s)',
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lembrete.titulo,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B289).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.t('Enviado', 'Sent'),
                    style: const TextStyle(
                      color: Color(0xFF00B289),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                lembrete.mensagem,
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  isParaTodos ? Icons.group_outlined : Icons.person_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  totalStr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sheet de edição completa do lembrete ─────────────────────────────────────

class _EditarLembreteSheet extends StatefulWidget {
  final LembreteEntity lembrete;
  final List<ParticipanteEntity> participantes;
  final bool isDark;
  final Future<void> Function(
    String mensagem,
    List<String>? destinatarios,
    DateTime agendadoPara,
  ) onSalvar;

  const _EditarLembreteSheet({
    required this.lembrete,
    required this.participantes,
    required this.isDark,
    required this.onSalvar,
  });

  @override
  State<_EditarLembreteSheet> createState() => _EditarLembreteSheetState();
}

class _EditarLembreteSheetState extends State<_EditarLembreteSheet> {
  late final TextEditingController _msgController;
  late bool _paraaTodos;
  late final Set<String> _selectedIds;
  late DateTime _agendadoPara;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _msgController = TextEditingController(text: widget.lembrete.mensagem);
    _paraaTodos = widget.lembrete.destinatarios == null;
    _selectedIds = (widget.lembrete.destinatarios?.toSet()) ??
        widget.participantes.map((p) => p.id).toSet();
    _agendadoPara = widget.lembrete.agendadoPara ??
        DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final result = await DateTimePickerSheet.show(
      context,
      initial: _agendadoPara,
    );
    if (result != null && mounted) {
      setState(() => _agendadoPara = result);
    }
  }

  Future<void> _salvar() async {
    final msg = _msgController.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('Digite uma mensagem.', 'Type a message.'))),
      );
      return;
    }
    if (!_paraaTodos && _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(
          'Selecione ao menos um destinatário.',
          'Select at least one recipient.',
        ))),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSalvar(
        msg,
        _paraaTodos ? null : _selectedIds.toList(),
        _agendadoPara,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final fmt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B6EF5).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF5B6EF5)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.t('Editar lembrete', 'Edit reminder'),
                          style: AppTextStyles.h3.copyWith(fontSize: 17),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.t('Mensagem', 'Message'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _msgController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: context.t('Escreva o lembrete...', 'Write the reminder...'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Toggle todos
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.group_outlined, size: 20, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(child: Text(context.t('Enviar para todos', 'Send to everyone'),
                                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500))),
                              Switch(
                                value: _paraaTodos,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    _paraaTodos = val;
                                    if (val) {
                                      _selectedIds
                                        ..clear()
                                        ..addAll(widget.participantes.map((p) => p.id));
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        if (!_paraaTodos && widget.participantes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.separated(
                              shrinkWrap: true, padding: EdgeInsets.zero,
                              itemCount: widget.participantes.length,
                              separatorBuilder: (_, i) => Divider(height: 1, color: Theme.of(context).dividerColor),
                              itemBuilder: (context, i) {
                                final p = widget.participantes[i];
                                final sel = _selectedIds.contains(p.id);
                                return InkWell(
                                  onTap: () => setState(() {
                                    if (sel) _selectedIds.remove(p.id); else _selectedIds.add(p.id);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                          backgroundImage: p.foto != null ? CachedNetworkImageProvider(p.foto!) : null,
                                          child: p.foto == null
                                              ? Text(p.nome.isNotEmpty ? p.nome[0].toUpperCase() : '?',
                                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(p.nome,
                                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        Checkbox(
                                          value: sel,
                                          activeColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) => setState(() {
                                            if (val == true) _selectedIds.add(p.id); else _selectedIds.remove(p.id);
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              context.t(
                                '${_selectedIds.length} de ${widget.participantes.length} selecionado(s)',
                                '${_selectedIds.length} of ${widget.participantes.length} selected',
                              ),
                              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Data/hora
                        Text(context.t('Data e hora do envio', 'Send date and time'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickDateTime,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF5B6EF5)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF5B6EF5)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(fmt.format(_agendadoPara.toLocal()),
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500))),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF5B6EF5), size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Botões
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: Theme.of(context).dividerColor),
                                ),
                                child: Text(context.t('Cancelar', 'Cancel'),
                                  style: AppTextStyles.button.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _salvar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B6EF5),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(height: 20, width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(context.t('Salvar', 'Save'),
                                        style: AppTextStyles.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
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
}
