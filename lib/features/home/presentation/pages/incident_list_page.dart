import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/features/home/domain/repositories/dashboard_actions_repository.dart';
import 'package:agrobravo/features/home/presentation/widgets/incident_modal.dart';
import 'package:agrobravo/core/components/custom_confirm_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncidentListPage extends StatefulWidget {
  final String groupId;
  const IncidentListPage({super.key, required this.groupId});

  @override
  State<IncidentListPage> createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _incidents = [];

  @override
  void initState() {
    super.initState();
    _loadIncidents();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRegisterIncidentModal();
    });
  }

  Future<void> _loadIncidents() async {
    setState(() => _isLoading = true);
    final repo = getIt<DashboardActionsRepository>();
    final result = await repo.getIncidents(widget.groupId);
    result.fold(
      (failure) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar incidentes: ${failure.toString().replaceAll("Exception: ", "")}')),
          );
        }
      },
      (list) {
        if (mounted) {
          setState(() {
            _incidents = list;
            _isLoading = false;
          });
        }
      },
    );
  }

  void _showRegisterIncidentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IncidentModal(groupId: widget.groupId),
    ).then((_) {
      _loadIncidents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Incidentes',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
            color: AppColors.primary,
            onPressed: _showRegisterIncidentModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incidents.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadIncidents,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _incidents.length,
                    itemBuilder: (context, index) {
                      final incident = _incidents[index];
                      return _buildIncidentCard(incident);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum incidente registrado',
              style: AppTextStyles.h3.copyWith(color: Colors.grey[600], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque no botão + no topo para relatar um incidente.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final type = incident['tipo'] ?? 'Outros';
    final location = incident['local'] ?? 'Não informado';
    final dateStr = incident['data_ocorrencia'] ?? '';
    final timeStr = incident['hora_ocorrencia'] ?? '';
    final description = incident['descricao'] ?? '';
    final actionTaken = incident['acao_tomada'] ?? '';
    final photoUrl = incident['foto_url'] as String?;
    final guide = incident['guia'] as Map<String, dynamic>?;
    final guideName = guide?['nome'] ?? 'Guia';

    String formattedDate = dateStr;
    try {
      if (dateStr.isNotEmpty) {
        final parsed = DateTime.parse(dateStr);
        formattedDate = DateFormat('dd/MM/yyyy').format(parsed);
      }
    } catch (_) {}

    final formattedTime = timeStr.length > 5 ? timeStr.substring(0, 5) : timeStr;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            type,
                            style: AppTextStyles.h3.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$formattedDate às $formattedTime',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (Supabase.instance.client.auth.currentUser?.id == incident['guia_id']) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 120),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editIncident(incident);
                      } else if (value == 'delete') {
                        _confirmDeleteIncident(incident['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descrição:',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ação Tomada:',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  actionTaken,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                  ),
                ),
                if (photoUrl != null && photoUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showPhotoViewer(photoUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photoUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'Relatado por $guideName',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoViewer(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              url,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editIncident(Map<String, dynamic> incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IncidentModal(
        groupId: widget.groupId,
        incidentToEdit: incident,
      ),
    ).then((_) {
      _loadIncidents();
    });
  }

  void _confirmDeleteIncident(String incidentId) {
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const CustomConfirmBottomSheet(
        title: 'Excluir incidente',
        message: 'Deseja realmente excluir este incidente? Esta ação não pode ser desfeita.',
        confirmLabel: 'Excluir',
        cancelLabel: 'Cancelar',
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        setState(() => _isLoading = true);
        final repo = getIt<DashboardActionsRepository>();
        final result = await repo.deleteIncident(incidentId);
        result.fold(
          (failure) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erro ao excluir incidente: ${failure.toString().replaceAll("Exception: ", "")}',
                ),
              ),
            );
          },
          (_) {
            _loadIncidents();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Incidente excluído com sucesso!'),
              ),
            );
          },
        );
      }
    });
  }
}
