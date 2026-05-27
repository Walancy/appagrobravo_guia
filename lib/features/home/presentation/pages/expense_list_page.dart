import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/features/home/domain/repositories/dashboard_actions_repository.dart';
import 'package:agrobravo/features/home/presentation/pages/guide_dashboard_page.dart';
import 'package:agrobravo/core/components/custom_confirm_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agrobravo/core/constants/translations.dart';

class ExpenseListPage extends StatefulWidget {
  final String groupId;
  const ExpenseListPage({super.key, required this.groupId});

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRegisterExpenseModal();
    });
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final repo = getIt<DashboardActionsRepository>();
    final result = await repo.getExpenses(widget.groupId);
    result.fold(
      (failure) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t(
              'Erro ao carregar gastos: ${failure.toString().replaceAll("Exception: ", "")}',
              'Error loading expenses: ${failure.toString().replaceAll("Exception: ", "")}',
            ))),
          );
        }
      },
      (list) {
        if (mounted) {
          setState(() {
            _expenses = list;
            _isLoading = false;
          });
        }
      },
    );
  }

  void _showRegisterExpenseModal() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegisterExpenseDialog(
        groupId: widget.groupId,
        repository: getIt<DashboardActionsRepository>(),
      ),
    ).then((value) {
      if (value == true) {
        _loadExpenses();
      }
    });
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Refeição':
        return Icons.restaurant;
      case 'Transporte':
        return Icons.directions_car;
      case 'Hospedagem':
        return Icons.hotel;
      case 'Passeio':
        return Icons.camera_alt;
      case 'Imprevisto':
        return Icons.warning_amber;
      case 'Outros':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          context.t('Gastos do Grupo', 'Group Expenses'),
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
            onPressed: _showRegisterExpenseModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadExpenses,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final expense = _expenses[index];
                      return _buildExpenseCard(expense);
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
              Icons.output_rounded,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              context.t('Nenhum gasto registrado', 'No expenses registered'),
              style: AppTextStyles.h3.copyWith(color: Colors.grey[600], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('Toque no botão + no topo para registrar um gasto.', 'Tap the + button at the top to register an expense.'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final amount = double.tryParse(expense['valor_gasto']?.toString() ?? '0') ?? 0.0;
    final category = expense['categoria'] ?? 'Outros';
    final rawDescription = expense['local'] ?? '';
    final isUsd = rawDescription.endsWith(' (USD)');
    final displayDescription = isUsd
        ? rawDescription.substring(0, rawDescription.length - 6)
        : rawDescription;
    final dateStr = expense['data_transacao'] ?? '';
    final receiptUrls = expense['comprovantes_urls'] as List?;
    final user = expense['user'] as Map<String, dynamic>?;
    final userName = user?['nome'] ?? 'Guia';

    String formattedDate = dateStr;
    try {
      if (dateStr.isNotEmpty) {
        final parsed = DateTime.parse(dateStr).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
      }
    } catch (_) {}

    final status = expense['status'] ?? 'Pendente';

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
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category == 'Refeição'
                            ? context.t('Refeição', 'Meal')
                            : category == 'Transporte'
                                ? context.t('Transporte', 'Transportation')
                                : category == 'Hospedagem'
                                    ? context.t('Hospedagem', 'Accommodation')
                                    : category == 'Passeio'
                                        ? context.t('Passeio', 'Tour')
                                        : category == 'Imprevisto'
                                            ? context.t('Imprevisto', 'Unexpected')
                                            : context.t('Outros', 'Others'),
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayDescription,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  isUsd
                      ? NumberFormat.simpleCurrency(locale: 'en_US').format(amount)
                      : NumberFormat.simpleCurrency(locale: 'pt_BR').format(amount),
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (Supabase.instance.client.auth.currentUser?.id == expense['user_id'] &&
                    status == 'Pendente') ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 120),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editExpense(expense);
                      } else if (value == 'delete') {
                        _confirmDeleteExpense(expense['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(context.t('Editar', 'Edit')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(context.t('Excluir', 'Delete'), style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (receiptUrls != null && receiptUrls.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      context.t('Comprovante(s):', 'Receipt(s):'),
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: receiptUrls.map((url) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => _showPhotoViewer(url.toString()),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url.toString(),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  context.t('Registrado por $userName', 'Registered by $userName'),
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(status),
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

  Widget _buildStatusBadge(String status) {
    Color color;
    Color textColor;
    switch (status) {
      case 'Reembolsado':
        color = Colors.green.withOpacity(0.1);
        textColor = Colors.green[700]!;
        break;
      case 'Recusado':
        color = Colors.red.withOpacity(0.1);
        textColor = Colors.red[700]!;
        break;
      case 'Pendente':
      default:
        color = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange[700]!;
        break;
    }

    final statusTranslated = status == 'Reembolsado'
        ? context.t('Reembolsado', 'Reimbursed')
        : status == 'Recusado'
            ? context.t('Recusado', 'Rejected')
            : context.t('Pendente', 'Pending');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusTranslated,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegisterExpenseDialog(
        groupId: widget.groupId,
        repository: getIt<DashboardActionsRepository>(),
        expenseToEdit: expense,
      ),
    ).then((value) {
      if (value == true) {
        _loadExpenses();
      }
    });
  }

  void _confirmDeleteExpense(String expenseId) {
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomConfirmBottomSheet(
        title: context.t('Excluir gasto', 'Delete expense'),
        message: context.t('Deseja realmente excluir este lançamento de gasto? Esta ação não pode ser desfeita.', 'Do you really want to delete this expense entry? This action cannot be undone.'),
        confirmLabel: context.t('Excluir', 'Delete'),
        cancelLabel: context.t('Cancelar', 'Cancel'),
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        setState(() => _isLoading = true);
        final repo = getIt<DashboardActionsRepository>();
        final result = await repo.deleteExpense(expenseId);
        result.fold(
          (failure) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t(
                  'Erro ao excluir gasto: ${failure.toString().replaceAll("Exception: ", "")}',
                  'Error deleting expense: ${failure.toString().replaceAll("Exception: ", "")}',
                )),
              ),
            );
          },
          (_) {
            _loadExpenses();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t(
                  'Lançamento de gasto excluído com sucesso!',
                  'Expense entry successfully deleted!',
                )),
              ),
            );
          },
        );
      }
    });
  }
}
