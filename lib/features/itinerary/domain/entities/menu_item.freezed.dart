// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MenuItemEntity {

 String get id; String get namePt; String? get nameEn; String get type; String? get descriptionPt; String? get descriptionEn; bool get isAlcoholic; bool get isVegan; bool get isVegetarian;
/// Create a copy of MenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuItemEntityCopyWith<MenuItemEntity> get copyWith => _$MenuItemEntityCopyWithImpl<MenuItemEntity>(this as MenuItemEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuItemEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.namePt, namePt) || other.namePt == namePt)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.type, type) || other.type == type)&&(identical(other.descriptionPt, descriptionPt) || other.descriptionPt == descriptionPt)&&(identical(other.descriptionEn, descriptionEn) || other.descriptionEn == descriptionEn)&&(identical(other.isAlcoholic, isAlcoholic) || other.isAlcoholic == isAlcoholic)&&(identical(other.isVegan, isVegan) || other.isVegan == isVegan)&&(identical(other.isVegetarian, isVegetarian) || other.isVegetarian == isVegetarian));
}


@override
int get hashCode => Object.hash(runtimeType,id,namePt,nameEn,type,descriptionPt,descriptionEn,isAlcoholic,isVegan,isVegetarian);

@override
String toString() {
  return 'MenuItemEntity(id: $id, namePt: $namePt, nameEn: $nameEn, type: $type, descriptionPt: $descriptionPt, descriptionEn: $descriptionEn, isAlcoholic: $isAlcoholic, isVegan: $isVegan, isVegetarian: $isVegetarian)';
}


}

/// @nodoc
abstract mixin class $MenuItemEntityCopyWith<$Res>  {
  factory $MenuItemEntityCopyWith(MenuItemEntity value, $Res Function(MenuItemEntity) _then) = _$MenuItemEntityCopyWithImpl;
@useResult
$Res call({
 String id, String namePt, String? nameEn, String type, String? descriptionPt, String? descriptionEn, bool isAlcoholic, bool isVegan, bool isVegetarian
});




}
/// @nodoc
class _$MenuItemEntityCopyWithImpl<$Res>
    implements $MenuItemEntityCopyWith<$Res> {
  _$MenuItemEntityCopyWithImpl(this._self, this._then);

  final MenuItemEntity _self;
  final $Res Function(MenuItemEntity) _then;

/// Create a copy of MenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? namePt = null,Object? nameEn = freezed,Object? type = null,Object? descriptionPt = freezed,Object? descriptionEn = freezed,Object? isAlcoholic = null,Object? isVegan = null,Object? isVegetarian = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,namePt: null == namePt ? _self.namePt : namePt // ignore: cast_nullable_to_non_nullable
as String,nameEn: freezed == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,descriptionPt: freezed == descriptionPt ? _self.descriptionPt : descriptionPt // ignore: cast_nullable_to_non_nullable
as String?,descriptionEn: freezed == descriptionEn ? _self.descriptionEn : descriptionEn // ignore: cast_nullable_to_non_nullable
as String?,isAlcoholic: null == isAlcoholic ? _self.isAlcoholic : isAlcoholic // ignore: cast_nullable_to_non_nullable
as bool,isVegan: null == isVegan ? _self.isVegan : isVegan // ignore: cast_nullable_to_non_nullable
as bool,isVegetarian: null == isVegetarian ? _self.isVegetarian : isVegetarian // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuItemEntity].
extension MenuItemEntityPatterns on MenuItemEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuItemEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuItemEntity value)  $default,){
final _that = this;
switch (_that) {
case _MenuItemEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuItemEntity value)?  $default,){
final _that = this;
switch (_that) {
case _MenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String namePt,  String? nameEn,  String type,  String? descriptionPt,  String? descriptionEn,  bool isAlcoholic,  bool isVegan,  bool isVegetarian)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String namePt,  String? nameEn,  String type,  String? descriptionPt,  String? descriptionEn,  bool isAlcoholic,  bool isVegan,  bool isVegetarian)  $default,) {final _that = this;
switch (_that) {
case _MenuItemEntity():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String namePt,  String? nameEn,  String type,  String? descriptionPt,  String? descriptionEn,  bool isAlcoholic,  bool isVegan,  bool isVegetarian)?  $default,) {final _that = this;
switch (_that) {
case _MenuItemEntity() when $default != null:
return $default(_that.id,_that.namePt,_that.nameEn,_that.type,_that.descriptionPt,_that.descriptionEn,_that.isAlcoholic,_that.isVegan,_that.isVegetarian);case _:
  return null;

}
}

}

/// @nodoc


class _MenuItemEntity implements MenuItemEntity {
  const _MenuItemEntity({required this.id, required this.namePt, this.nameEn, required this.type, this.descriptionPt, this.descriptionEn, this.isAlcoholic = false, this.isVegan = false, this.isVegetarian = false});
  

@override final  String id;
@override final  String namePt;
@override final  String? nameEn;
@override final  String type;
@override final  String? descriptionPt;
@override final  String? descriptionEn;
@override@JsonKey() final  bool isAlcoholic;
@override@JsonKey() final  bool isVegan;
@override@JsonKey() final  bool isVegetarian;

/// Create a copy of MenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuItemEntityCopyWith<_MenuItemEntity> get copyWith => __$MenuItemEntityCopyWithImpl<_MenuItemEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuItemEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.namePt, namePt) || other.namePt == namePt)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.type, type) || other.type == type)&&(identical(other.descriptionPt, descriptionPt) || other.descriptionPt == descriptionPt)&&(identical(other.descriptionEn, descriptionEn) || other.descriptionEn == descriptionEn)&&(identical(other.isAlcoholic, isAlcoholic) || other.isAlcoholic == isAlcoholic)&&(identical(other.isVegan, isVegan) || other.isVegan == isVegan)&&(identical(other.isVegetarian, isVegetarian) || other.isVegetarian == isVegetarian));
}


@override
int get hashCode => Object.hash(runtimeType,id,namePt,nameEn,type,descriptionPt,descriptionEn,isAlcoholic,isVegan,isVegetarian);

@override
String toString() {
  return 'MenuItemEntity(id: $id, namePt: $namePt, nameEn: $nameEn, type: $type, descriptionPt: $descriptionPt, descriptionEn: $descriptionEn, isAlcoholic: $isAlcoholic, isVegan: $isVegan, isVegetarian: $isVegetarian)';
}


}

/// @nodoc
abstract mixin class _$MenuItemEntityCopyWith<$Res> implements $MenuItemEntityCopyWith<$Res> {
  factory _$MenuItemEntityCopyWith(_MenuItemEntity value, $Res Function(_MenuItemEntity) _then) = __$MenuItemEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String namePt, String? nameEn, String type, String? descriptionPt, String? descriptionEn, bool isAlcoholic, bool isVegan, bool isVegetarian
});




}
/// @nodoc
class __$MenuItemEntityCopyWithImpl<$Res>
    implements _$MenuItemEntityCopyWith<$Res> {
  __$MenuItemEntityCopyWithImpl(this._self, this._then);

  final _MenuItemEntity _self;
  final $Res Function(_MenuItemEntity) _then;

/// Create a copy of MenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? namePt = null,Object? nameEn = freezed,Object? type = null,Object? descriptionPt = freezed,Object? descriptionEn = freezed,Object? isAlcoholic = null,Object? isVegan = null,Object? isVegetarian = null,}) {
  return _then(_MenuItemEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,namePt: null == namePt ? _self.namePt : namePt // ignore: cast_nullable_to_non_nullable
as String,nameEn: freezed == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,descriptionPt: freezed == descriptionPt ? _self.descriptionPt : descriptionPt // ignore: cast_nullable_to_non_nullable
as String?,descriptionEn: freezed == descriptionEn ? _self.descriptionEn : descriptionEn // ignore: cast_nullable_to_non_nullable
as String?,isAlcoholic: null == isAlcoholic ? _self.isAlcoholic : isAlcoholic // ignore: cast_nullable_to_non_nullable
as bool,isVegan: null == isVegan ? _self.isVegan : isVegan // ignore: cast_nullable_to_non_nullable
as bool,isVegetarian: null == isVegetarian ? _self.isVegetarian : isVegetarian // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
