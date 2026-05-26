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
}
