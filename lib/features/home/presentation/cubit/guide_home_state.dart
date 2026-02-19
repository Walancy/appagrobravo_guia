part of 'guide_home_cubit.dart';

@freezed
class GuideHomeState with _$GuideHomeState {
  const factory GuideHomeState.initial() = _Initial;
  const factory GuideHomeState.loading() = _Loading;
  const factory GuideHomeState.loaded(List<GuideMission> missions) = _Loaded;
  const factory GuideHomeState.error(String message) = _Error;
}
