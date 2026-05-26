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

  @override
  Future<Either<Exception, List<Map<String, dynamic>>>> getIncidents(String groupId) async {
    try {
      final response = await _supabaseClient
          .from('incidentes')
          .select('*, guia:users!guia_id(nome, foto)')
          .eq('grupo_id', groupId)
          .order('data_ocorrencia', ascending: false)
          .order('hora_ocorrencia', ascending: false);
      
      return Right(List<Map<String, dynamic>>.from(response as List));
    } catch (e) {
      return Left(Exception('Erro ao buscar incidentes: $e'));
    }
  }

  @override
  Future<Either<Exception, List<Map<String, dynamic>>>> getExpenses(String groupId) async {
    try {
      final response = await _supabaseClient
          .from('transacoes_financeiras')
          .select('*, user:users!user_id(nome, foto)')
          .eq('grupo_id', groupId)
          .order('data_transacao', ascending: false);
      
      return Right(List<Map<String, dynamic>>.from(response as List));
    } catch (e) {
      return Left(Exception('Erro ao buscar gastos: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> updateIncident({
    required String id,
    required String groupId,
    required String type,
    required String location,
    required DateTime date,
    required String time,
    required String description,
    required String actionTaken,
    String? existingPhotoUrl,
    List<String> newLocalPhotoPaths = const [],
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado.'));

      String? finalPhotoUrl = existingPhotoUrl;

      if (newLocalPhotoPaths.isNotEmpty) {
        final path = newLocalPhotoPaths.first;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
        final storagePath = 'incidentes/$groupId/$userId/$fileName';
        await _supabaseClient.storage
            .from('files')
            .upload(storagePath, File(path));
        finalPhotoUrl =
            _supabaseClient.storage.from('files').getPublicUrl(storagePath);
      }

      await _supabaseClient.from('incidentes').update({
        'tipo': type,
        'local': location,
        'data_ocorrencia': date.toIso8601String().split('T')[0],
        'hora_ocorrencia': time.contains(':') && time.split(':').length == 2 ? '$time:00' : time,
        'descricao': description,
        'acao_tomada': actionTaken,
        'foto_url': finalPhotoUrl,
      }).eq('id', id);

      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao atualizar incidente: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> deleteIncident(String id) async {
    try {
      await _supabaseClient.from('incidentes').delete().eq('id', id);
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao excluir incidente: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> updateExpense({
    required String id,
    required String groupId,
    required double amount,
    required String category,
    required String description,
    required List<String> existingReceiptUrls,
    required List<String> newLocalReceiptPaths,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado.'));

      List<String> receiptUrls = List<String>.from(existingReceiptUrls);

      for (final path in newLocalReceiptPaths) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
        final storagePath = 'comprovantes/$groupId/$userId/$fileName';
        final file = File(path);

        await _supabaseClient.storage.from('files').upload(storagePath, file);

        final publicUrl =
            _supabaseClient.storage.from('files').getPublicUrl(storagePath);

        receiptUrls.add(publicUrl);
      }

      await _supabaseClient.from('transacoes_financeiras').update({
        'valor_gasto': amount,
        'categoria': category,
        'local': description,
        'comprovantes_urls': receiptUrls,
      }).eq('id', id);

      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao atualizar gasto: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> deleteExpense(String id) async {
    try {
      await _supabaseClient.from('transacoes_financeiras').delete().eq('id', id);
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao excluir gasto: $e'));
    }
  }
}
