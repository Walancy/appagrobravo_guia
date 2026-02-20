// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_item_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MenuItemDto {

 String get id;@JsonKey(name: 'nome_pt') String? get namePt;@JsonKey(name: 'nome_en') String? get nameEn;@JsonKey(name: 'tipo') String? get type;@JsonKey(name: 'descricao_pt') String? get descriptionPt;@JsonKey(name: 'descricao_en') String? get descriptionEn;@JsonKey(name: 'is_alcoholic', defaultValue: false) bool? get isAlcoholic;@JsonKey(name: 'is_vegan', defaultValue: false) bool? get isVegan;@JsonKey(name: 'is_vegetarian', defaultValue: false) bool? get isVegetarian;
/// Create a copy of MenuItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuItemDtoCopyWith<MenuItemDto> get copyWith => _$MenuItemDtoCopyWithImpl<MenuItemDto>(this as MenuItemDto, _$identity);

  /// Serializes this MenuItemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.namePt, namePt) || other.namePt == namePt)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.type, type) || other.type == type)&&(identical(other.descriptionPt, descriptionPt) || other.descriptionPt == descriptionPt)&&(identical(other.descriptionEn, descriptionEn) || other.descriptionEn == descriptionEn)&&(identical(other.isAlcoholic, isAlcoholic) || other.isAlcoholic == isAlcoholic)&&(identical(other.isVegan, isVegan) || other.isVegan == isVegan)&&(identical(other.isVegetarian, isVegetarian) || other.isVegetarian == isVegetarian));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,namePt,nameEn,type,descriptionPt,descriptionEn,isAlcoholic,isVegan,isVegetarian);

@override
String toString() {
  return 'MenuItemDto(id: $id, namePt: $namePt, nameEn: $nameEn, type: $type, descriptionPt: $descriptionPt, descriptionEn: $descriptionEn, isAlcoholic: $isAlcoholic, isVegan: $isVegan, isVegetarian: $isVegetarian)';
}


}

/// @nodoc
abstract mixin class $MenuItemDtoCopyWith<$Res>  {
  factory $MenuItemDtoCopyWith(MenuItemDto value, $Res Function(MenuItemDto) _then) = _$MenuItemDtoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'nome_pt') String? namePt,@JsonKey(name: 'nome_en') String? nameEn,@JsonKey(name: 'tipo') String? type,@JsonKey(name: 'descricao_pt') String? descriptionPt,@JsonKey(name: 'descricao_en') String? descriptionEn,@JsonKey(name: 'is_alcoholic', defaultValue: false) bool? isAlcoholic,@JsonKey(name: 'is_vegan', defaultValue: false) bool? isVegan,@JsonKey(name: 'is_vegetarian', defaultValue: false) bool? isVegetarian
});




}
/// @nodoc
class _$MenuItemDtoCopyWithImpl<$Res>
    implements $MenuItemDtoCopyWith<$Res> {
  _$MenuItemDtoCopyWithImpl(this._self, this._then);

  final MenuItemDto _self;
  final $Res Function(MenuItemDto) _then;

/// Create a copy of MenuItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? namePt = freezed,Object? nameEn = freezed,Object? type = freezed,Object? descriptionPt = freezed,Object? descriptionEn = freezed,Object? isAlcoholic = freezed,Object? isVegan = freezed,Object? isVegetarian = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,namePt: freezed == namePt ? _self.namePt : namePt // ignore: cast_nullable_to_non_nullable
as String?,nameEn: freezed == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,descriptionPt: freezed == descriptionPt ? _self.descriptionPt : descriptionPt // ignore: cast_nullable_to_non_nullable
as String?,descriptionEn: freezed == descriptionEn ? _self.descriptionEn : descriptionEn // ignore: cast_nullable_to_non_nullable
as String?,isAlcoholic: freezed == isAlcoholic ? _self.isAlcoholic : isAlcoholic // ignore: cast_nullable_to_non_nullable
as bool?,isVegan: freezed == isVegan ? _self.isVegan : isVegan // ignore: cast_nullable_to_non_nullable
as bool?,isVegetarian: freezed == isVegetarian ? _self.isVegetarian : isVegetarian // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuItemDto].
extension MenuItemDtoPatterns on MenuItemDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuItemDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuItemDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuItemDto value)  $default,){
final _that = this;
switch (_that) {
case _MenuItemDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuItemDto value)?  $default,){
final _that = this;
switch (_that) {
case _MenuItemDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'nome_pt')  String? namePt, @JsonKey(name: 'nome_en')  String? nameEn, @JsonKey(name: 'tipo')  String? type, @JsonKey(name: 'descricao_pt')  String? descriptionPt, @JsonKey(name: 'descricao_en')  String? descriptionEn, @JsonKey(name: 'is_alcoholic', defaultValue: false)  bool? isAlcoholic, @JsonKey(name: 'is_vegan', defaultValue: false)  bool? isVegan, @JsonKey(name: 'is_vegetarian', defaultValue: false)  bool? isVegetarian)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuItemDto() when $default != null:
return $default(_that.id,_that.namePt,_that.nameEn,_that.type,_that.descriptionPt,_that.descriptionEn,_that.isAlcoholic,_that.isVegan,_that.isVegetarian);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'nome_pt')  String? namePt, @JsonKey(name: 'nome_en')  String? nameEn, @JsonKey(name: 'tipo')  String? type, @JsonKey(name: 'descricao_pt')  String? descriptionPt, @JsonKey(name: 'descricao_en')  String? descriptionEn, @JsonKey(name: 'is_alcoholic', defaultValue: false)  bool? isAlcoholic, @JsonKey(name: 'is_vegan', defaultValue: false)  bool? isVegan, @JsonKey(name: 'is_vegetarian', defaultValue: false)  bool? isVegetarian)  $default,) {final _that = this;
switch (_that) {
case _MenuItemDto():
return $default(_that.id,_that.namePt,_that.nameEn,_that.type,_that.descriptionPt,_that.descriptionEn,_that.isAlcoholic,_that.isVegan,_that.isVegetarian);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'nome_pt')  String? namePt, @JsonKey(name: 'nome_en')  String? nameEn, @JsonKey(name: 'tipo')  String? type, @JsonKey(name: 'descricao_pt')  String? descriptionPt, @JsonKey(name: 'descricao_en')  String? descriptionEn, @JsonKey(name: 'is_alcoholic', defaultValue: false)  bool? isAlcoholic, @JsonKey(name: 'is_vegan', defaultValue: false)  bool? isVegan, @JsonKey(name: 'is_vegetarian', defaultValue: false)  bool? isVegetarian)?  $default,) {final _that = this;
switch (_that) {
case _MenuItemDto() when $default != null:
return $default(_that.id,_that.namePt,_that.nameEn,_that.type,_that.descriptionPt,_that.descriptionEn,_that.isAlcoholic,_that.isVegan,_that.isVegetarian);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MenuItemDto extends MenuItemDto {
  const _MenuItemDto({required this.id, @JsonKey(name: 'nome_pt') this.namePt, @JsonKey(name: 'nome_en') this.nameEn, @JsonKey(name: 'tipo') this.type, @JsonKey(name: 'descricao_pt') this.descriptionPt, @JsonKey(name: 'descricao_en') this.descriptionEn, @JsonKey(name: 'is_alcoholic', defaultValue: false) this.isAlcoholic, @JsonKey(name: 'is_vegan', defaultValue: false) this.isVegan, @JsonKey(name: 'is_vegetarian', defaultValue: false) this.isVegetarian}): super._();
  factory _MenuItemDto.fromJson(Map<String, dynamic> json) => _$MenuItemDtoFromJson(json);

@override final  String id;
@override@JsonKey(name: 'nome_pt') final  String? namePt;
@override@JsonKey(name: 'nome_en') final  String? nameEn;
@override@JsonKey(name: 'tipo') final  String? type;
@override@JsonKey(name: 'descricao_pt') final  String? descriptionPt;
@override@JsonKey(name: 'descricao_en') final  String? descriptionEn;
@override@JsonKey(name: 'is_alcoholic', defaultValue: false) final  bool? isAlcoholic;
@override@JsonKey(name: 'is_vegan', defaultValue: false) final  bool? isVegan;
@override@JsonKey(name: 'is_vegetarian', defaultValue: false) final  bool? isVegetarian;

/// Create a copy of MenuItemDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuItemDtoCopyWith<_MenuItemDto> get copyWith => __$MenuItemDtoCopyWithImpl<_MenuItemDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MenuItemDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.namePt, namePt) || other.namePt == namePt)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.type, type) || other.type == type)&&(identical(other.descriptionPt, descriptionPt) || other.descriptionPt == descriptionPt)&&(identical(other.descriptionEn, descriptionEn) || other.descriptionEn == descriptionEn)&&(identical(other.isAlcoholic, isAlcoholic) || other.isAlcoholic == isAlcoholic)&&(identical(other.isVegan, isVegan) || other.isVegan == isVegan)&&(identical(other.isVegetarian, isVegetarian) || other.isVegetarian == isVegetarian));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,namePt,nameEn,type,descriptionPt,descriptionEn,isAlcoholic,isVegan,isVegetarian);

@override
String toString() {
  return 'MenuItemDto(id: $id, namePt: $namePt, nameEn: $nameEn, type: $type, descriptionPt: $descriptionPt, descriptionEn: $descriptionEn, isAlcoholic: $isAlcoholic, isVegan: $isVegan, isVegetarian: $isVegetarian)';
}


}

/// @nodoc
abstract mixin class _$MenuItemDtoCopyWith<$Res> implements $MenuItemDtoCopyWith<$Res> {
  factory _$MenuItemDtoCopyWith(_MenuItemDto value, $Res Function(_MenuItemDto) _then) = __$MenuItemDtoCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'nome_pt') String? namePt,@JsonKey(name: 'nome_en') String? nameEn,@JsonKey(name: 'tipo') String? type,@JsonKey(name: 'descricao_pt') String? descriptionPt,@JsonKey(name: 'descricao_en') String? descriptionEn,@JsonKey(name: 'is_alcoholic', defaultValue: false) bool? isAlcoholic,@JsonKey(name: 'is_vegan', defaultValue: false) bool? isVegan,@JsonKey(name: 'is_vegetarian', defaultValue: false) bool? isVegetarian
});




}
/// @nodoc
class __$MenuItemDtoCopyWithImpl<$Res>
    implements _$MenuItemDtoCopyWith<$Res> {
  __$MenuItemDtoCopyWithImpl(this._self, this._then);

  final _MenuItemDto _self;
  final $Res Function(_MenuItemDto) _then;

/// Create a copy of MenuItemDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? namePt = freezed,Object? nameEn = freezed,Object? type = freezed,Object? descriptionPt = freezed,Object? descriptionEn = freezed,Object? isAlcoholic = freezed,Object? isVegan = freezed,Object? isVegetarian = freezed,}) {
  return _then(_MenuItemDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,namePt: freezed == namePt ? _self.namePt : namePt // ignore: cast_nullable_to_non_nullable
as String?,nameEn: freezed == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,descriptionPt: freezed == descriptionPt ? _self.descriptionPt : descriptionPt // ignore: cast_nullable_to_non_nullable
as String?,descriptionEn: freezed == descriptionEn ? _self.descriptionEn : descriptionEn // ignore: cast_nullable_to_non_nullable
as String?,isAlcoholic: freezed == isAlcoholic ? _self.isAlcoholic : isAlcoholic // ignore: cast_nullable_to_non_nullable
as bool?,isVegan: freezed == isVegan ? _self.isVegan : isVegan // ignore: cast_nullable_to_non_nullable
as bool?,isVegetarian: freezed == isVegetarian ? _self.isVegetarian : isVegetarian // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
