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
    String? photoUrl,
  });

  Future<Either<Exception, void>> requestReport({
    required String groupId,
    required bool includeActivities,
    required bool includeIncidents,
    required bool includeExpenses,
  });
}
