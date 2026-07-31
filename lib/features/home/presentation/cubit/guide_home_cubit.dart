import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:agrobravo/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:agrobravo/features/itinerary/domain/entities/guide_mission.dart';

part 'guide_home_state.dart';
part 'guide_home_cubit.freezed.dart';

@injectable
class GuideHomeCubit extends Cubit<GuideHomeState> {
  final ItineraryRepository _repository;
  List<GuideMission> _allMissions = [];

  GuideHomeCubit(this._repository) : super(const GuideHomeState.initial());

  Future<void> loadMissions() async {
    emit(const GuideHomeState.loading());
    final result = await _repository.getGuideMissions();

    result.fold(
      (failure) {
        if (!isClosed) emit(GuideHomeState.error(failure.toString()));
      },
      (missions) {
        _allMissions = missions;
        if (!isClosed) emit(GuideHomeState.loaded(_allMissions));
      },
    );
  }

  void setStatusFilter(String? status) {
    final filtered = status == null
        ? _allMissions
        : _allMissions
            .where((gm) =>
                gm.mission.status?.toUpperCase() == status.toUpperCase())
            .toList();
    if (!isClosed) emit(GuideHomeState.loaded(filtered, activeFilter: status));
  }
}
