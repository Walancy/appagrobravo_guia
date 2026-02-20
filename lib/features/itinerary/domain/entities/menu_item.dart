import 'package:freezed_annotation/freezed_annotation.dart';

part 'menu_item.freezed.dart';

@freezed
abstract class MenuItemEntity with _$MenuItemEntity {
  const factory MenuItemEntity({
    required String id,
    required String namePt,
    String? nameEn,
    required String type,
    String? descriptionPt,
    String? descriptionEn,
    @Default(false) bool isAlcoholic,
    @Default(false) bool isVegan,
    @Default(false) bool isVegetarian,
  }) = _MenuItemEntity;
}
