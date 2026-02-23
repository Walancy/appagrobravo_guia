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
    String? photoUrl,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado.'));

      await _supabaseClient.from('incidentes').insert({
        'grupo_id': groupId,
        'guia_id': userId,
        'tipo': type,
        'local': location,
        'data_ocorrencia': date.toIso8601String().split('T')[0],
        'hora_ocorrencia': '$time:00',
        'descricao': description,
        'acao_tomada': actionTaken,
        'foto_url': photoUrl,
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
}
