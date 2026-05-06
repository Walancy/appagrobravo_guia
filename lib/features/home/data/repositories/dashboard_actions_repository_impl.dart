import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/dashboard_actions_repository.dart';

@LazySingleton(as: DashboardActionsRepository)
class DashboardActionsRepositoryImpl implements DashboardActionsRepository {
  final SupabaseClient _supabaseClient;

  DashboardActionsRepositoryImpl(this._supabaseClient);

  @override
  Future<Either<Exception, void>> registerIncident({
    required String groupId,
    required String type,
    required String location,
    required DateTime date,
    required String time,
    required String description,
    required String actionTaken,
    List<String> photoPaths = const [],
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado.'));

      List<String> photoUrls = [];
      for (final path in photoPaths) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
        final storagePath = 'incidentes/$groupId/$userId/$fileName';
        await _supabaseClient.storage
            .from('files')
            .upload(storagePath, File(path));
        photoUrls.add(
          _supabaseClient.storage.from('files').getPublicUrl(storagePath),
        );
      }

      await _supabaseClient.from('incidentes').insert({
        'grupo_id': groupId,
        'guia_id': userId,
        'tipo': type,
        'local': location,
        'data_ocorrencia': date.toIso8601String().split('T')[0],
        'hora_ocorrencia': '$time:00',
        'descricao': description,
        'acao_tomada': actionTaken,
        'foto_url': photoUrls.isNotEmpty ? photoUrls.first : null,
      });

      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao registrar incidente: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> requestReport({
    required String groupId,
    required bool includeActivities,
    required bool includeIncidents,
    required bool includeExpenses,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado.'));

      await _supabaseClient.from('relatorios_solicitados').insert({
        'grupo_id': groupId,
        'guia_id': userId,
        'incluir_atividades': includeActivities,
        'incluir_incidentes': includeIncidents,
        'incluir_despesas': includeExpenses,
      });

      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao solicitar relatório: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> registerExpense({
    required String groupId,
    required double amount,
    required String category,
    required String description,
    required List<String> receiptPaths,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado.'));

      List<String> receiptUrls = [];

      // Upload files
      for (final path in receiptPaths) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
        final storagePath = 'comprovantes/$groupId/$userId/$fileName';
        
        final file = File(path);
        
        await _supabaseClient.storage
            .from('files')
            .upload(storagePath, file);
            
        final publicUrl = _supabaseClient.storage
            .from('files')
            .getPublicUrl(storagePath);
            
        receiptUrls.add(publicUrl);
      }

      // Insert transaction
      await _supabaseClient.from('transacoes_financeiras').insert({
        'grupo_id': groupId,
        'user_id': userId,
        'valor_gasto': amount,
        'categoria': category,
        'local': description,
        'comprovantes_urls': receiptUrls,
        'data_transacao': DateTime.now().toUtc().toIso8601String(),
        'status': 'Pendente', // Fixed capitalization to match DB constraint
      });

      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao registrar gasto: $e'));
    }
  }
}
