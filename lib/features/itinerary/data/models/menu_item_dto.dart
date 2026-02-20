import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/menu_item.dart';

part 'menu_item_dto.freezed.dart';
part 'menu_item_dto.g.dart';

@freezed
abstract class MenuItemDto with _$MenuItemDto {
  const MenuItemDto._();

  const factory MenuItemDto({
    required String id,
    @JsonKey(name: 'nome_pt') String? namePt,
    @JsonKey(name: 'nome_en') String? nameEn,
    @JsonKey(name: 'tipo') String? type,
    @JsonKey(name: 'descricao_pt') String? descriptionPt,
    @JsonKey(name: 'descricao_en') String? descriptionEn,
    @JsonKey(name: 'is_alcoholic', defaultValue: false) bool? isAlcoholic,
    @JsonKey(name: 'is_vegan', defaultValue: false) bool? isVegan,
    @JsonKey(name: 'is_vegetarian', defaultValue: false) bool? isVegetarian,
  }) = _MenuItemDto;

  factory MenuItemDto.fromJson(Map<String, dynamic> json) =>
      _$MenuItemDtoFromJson(json);

  MenuItemEntity toEntity() {
    return MenuItemEntity(
      id: id,
      namePt: namePt ?? '',
      nameEn: nameEn,
      type: type ?? 'other',
      descriptionPt: descriptionPt,
      descriptionEn: descriptionEn,
      isAlcoholic: isAlcoholic ?? false,
      isVegan: isVegan ?? false,
      isVegetarian: isVegetarian ?? false,
    );
  }
}
