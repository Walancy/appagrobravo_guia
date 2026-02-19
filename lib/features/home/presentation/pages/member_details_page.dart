import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';

class MemberDetailsPage extends StatelessWidget {
  final Map<String, dynamic> memberData;

  const MemberDetailsPage({super.key, required this.memberData});

  @override
  Widget build(BuildContext context) {
    final user = memberData['user'];
    final name = user?['nome'] ?? 'Sem nome';
    final email = user?['email'] ?? 'Não informado';
    final phone = user?['telefone'] ?? 'Não informado';
    final avatar = user?['foto'] ?? user?['avatar_url'];
    final company = user?['empresa'] ?? 'Independente';
    final groupName = memberData['groupName'] as String?;
    final foodPrefs = user?['preferencias_alimentares'] as List?;
    final medicalRest = user?['restricoes_medicas'] as List?;
    final documents = memberData['documentos'] as List?;

    final hasAlertDocs =
        documents?.any((d) {
          final s = d['status']?.toString().toUpperCase();
          return s == 'PENDENTE' || s == 'EXPIRADO';
        }) ??
        false;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppHeader(
        mode: HeaderMode.back,
        title: 'Viajante',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              color: const Color(0xFFF2F4F7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            (avatar != null && avatar.isNotEmpty)
                                ? NetworkImage(avatar)
                                : null,
                        backgroundColor: Colors.grey[200],
                        child:
                            (avatar == null || avatar.isEmpty)
                                ? const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 50,
                                )
                                : null,
                        onBackgroundImageError:
                            (avatar != null && avatar.isNotEmpty)
                                ? (_, __) {}
                                : null,
                      ),
                      // Optional: Camera icon if needed, positioned bottom right
                      // Positioned(bottom: 0, right: 0, child: Icon(Icons.camera_alt, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.h2.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$company${groupName != null && groupName.isNotEmpty ? ' - $groupName' : ''}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          phone,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.folder_outlined,
                      label: 'Documentos do viajante',
                      hasAlert: hasAlertDocs,
                      onTap: () => _showDocumentsSheet(context, documents),
                      isFirst: true,
                    ),
                    const Divider(height: 1, indent: 72),
                    _buildMenuItem(
                      context,
                      icon: Icons.restaurant_menu,
                      label: 'Preferências alimentares',
                      onTap:
                          () => _showTagsSheet(
                            context,
                            'Preferências Alimentares',
                            foodPrefs,
                          ),
                    ),
                    const Divider(height: 1, indent: 72),
                    _buildMenuItem(
                      context,
                      icon: Icons.medical_services_outlined,
                      label: 'Restrições médicas',
                      onTap:
                          () => _showTagsSheet(
                            context,
                            'Restrições Médicas',
                            medicalRest,
                          ),
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool hasAlert = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              if (hasAlert)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentsSheet(BuildContext context, List? documents) {
    // Sort documents: EXPIRADO/PENDENTE first, then others
    final sortedDocs = List<Map<String, dynamic>>.from(documents ?? []);
    sortedDocs.sort((a, b) {
      final statusA = a['status']?.toString().toUpperCase() ?? '';
      final statusB = b['status']?.toString().toUpperCase() ?? '';
      final isAlertA = statusA == 'PENDENTE' || statusA == 'EXPIRADO';
      final isAlertB = statusB == 'PENDENTE' || statusB == 'EXPIRADO';

      if (isAlertA && !isAlertB) return -1;
      if (!isAlertA && isAlertB) return 1;
      return 0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Documentos',
                    style: AppTextStyles.h3.copyWith(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child:
                      sortedDocs.isEmpty
                          ? Center(
                            child: Text(
                              'Nenhum documento registrado',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: sortedDocs.length,
                            itemBuilder: (context, index) {
                              final doc = sortedDocs[index];
                              final status =
                                  doc['status']?.toString().toUpperCase() ??
                                  'PENDENTE';
                              final type =
                                  doc['tipo'] ??
                                  doc['nome_documento'] ??
                                  'Documento';
                              Color statusColor;
                              if (status == 'APROVADO' ||
                                  status == 'VALIDADO') {
                                statusColor = const Color(0xFF00B289);
                              } else if (status == 'PENDENTE') {
                                statusColor = Colors.amber;
                              } else if (status == 'EXPIRADO') {
                                statusColor = Colors.redAccent;
                              } else {
                                statusColor = Colors.grey;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        type,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  void _showTagsSheet(BuildContext context, String title, List? tags) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (tags == null || tags.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nenhuma informação registrada',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag.toString(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }
}
