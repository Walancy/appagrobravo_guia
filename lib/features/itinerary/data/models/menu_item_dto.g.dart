// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_item_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MenuItemDto _$MenuItemDtoFromJson(Map<String, dynamic> json) => _MenuItemDto(
  id: json['id'] as String,
  namePt: json['nome_pt'] as String?,
  nameEn: json['nome_en'] as String?,
  type: json['tipo'] as String?,
  descriptionPt: json['descricao_pt'] as String?,
  descriptionEn: json['descricao_en'] as String?,
  isAlcoholic: json['is_alcoholic'] as bool? ?? false,
  isVegan: json['is_vegan'] as bool? ?? false,
  isVegetarian: json['is_vegetarian'] as bool? ?? false,
);

Map<String, dynamic> _$MenuItemDtoToJson(_MenuItemDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome_pt': instance.namePt,
      'nome_en': instance.nameEn,
      'tipo': instance.type,
      'descricao_pt': instance.descriptionPt,
      'descricao_en': instance.descriptionEn,
      'is_alcoholic': instance.isAlcoholic,
      'is_vegan': instance.isVegan,
      'is_vegetarian': instance.isVegetarian,
    };
