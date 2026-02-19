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

  GuideHomeCubit(this._repository) : super(const GuideHomeState.initial());

  Future<void> loadMissions() async {
    emit(const GuideHomeState.loading());
    final result = await _repository.getGuideMissions();

    result.fold(
      (failure) => emit(GuideHomeState.error(failure.toString())),
      (missions) => emit(GuideHomeState.loaded(missions)),
    );
  }
}
