import 'package:dartz/dartz.dart';

abstract class DashboardActionsRepository {
  Future<Either<Exception, void>> registerIncident({
    required String groupId,
    required String type,
    required String location,
    required DateTime date,
    required String time,
    required String description,
    required String actionTaken,
    List<String> photoPaths = const [],
  });

  Future<Either<Exception, void>> registerExpense({
    required String groupId,
    required double amount,
    required String category,
    required String description,
    required List<String> receiptPaths,
  });

  Future<Either<Exception, List<Map<String, dynamic>>>> getIncidents(String groupId);
  Future<Either<Exception, List<Map<String, dynamic>>>> getExpenses(String groupId);

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
  });

  Future<Either<Exception, void>> deleteIncident(String id);

  Future<Either<Exception, void>> updateExpense({
    required String id,
    required String groupId,
    required double amount,
    required String category,
    required String description,
    required List<String> existingReceiptUrls,
    required List<String> newLocalReceiptPaths,
  });

  Future<Either<Exception, void>> deleteExpense(String id);
}
