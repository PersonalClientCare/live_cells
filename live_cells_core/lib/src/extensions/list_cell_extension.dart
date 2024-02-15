import 'dart:collection';

import '../base/keys.dart';
import '../mutable_cell/mutable_cell.dart';
import 'compute_extension.dart';
import '../value_cell.dart';

/// Provides [List] methods directly on cells holding [List]s.
extension ListCellExtension<T> on ValueCell<List<T>> {
  /// Returns a cell which evaluates to [List.reversed] applied on the [value] in this cell.
  ValueCell<Iterable<T>> get reversed => apply((value) => value.reversed,
    key: _ListPropKey(this, #reversed)
  );

  /// Returns a cell with a value equal the element at [index] in the [List] held in this cell.
  ValueCell<T> operator[](int index) => apply((value) => value[index],
    willChange: (_, v) => value[index] != v[index],
    key: _ListIndexKey(this, index)
  );
}

/// Provides variants which return [MutableCell] of the methods provided by [ListCellExtension].
extension MutableListCellExtension<T> on MutableCell<List<T>> {
  /// Returns a cell which evaluates to [List.first] applied on the [value] in this cell.
  ///
  /// Changing the value of the returned cell updates the value of the first
  /// element of the [List] held in this cell.
  ///
  /// **NOTE**: The actual list is not modified but a new list is created.
  MutableCell<T> get first => mutableApply((value) => value.first,
      (v) => value = _updatedList(value, 0, v),
      willChange: (_, v) => value.first != v.first,
      key: _MutableListPropKey(this, #first)
  );

  /// Returns a cell which evaluates to [List.last] applied on the [value] in this cell.
  ///
  /// Changing the value of the returned cell updates the value of the last
  /// element of the [List] held in this cell.
  ///
  /// **NOTE**: The actual list is not modified but a new list is created.
  MutableCell<T> get last => mutableApply((value) => value.last,
      (v) => value = _updateListLast(value, v),
      willChange: (_, v) => value.last != v.last,
      key: _MutableListPropKey(this, #last)
  );

  /// Returns a cell which evaluates to [List.length] applied on the [value] in this cell.
  ///
  /// Changing the value of the returned cell changes the length of the [List]
  /// held in this cell.
  ///
  /// **NOTE**: The actual list is not modified but a new list is created.
  MutableCell<int> get length => mutableApply((value) => value.length,
      (v) => value = _updateListLength(value, v),
      willChange: (_, v) => value.length != v.length,
      key: _MutableListPropKey(this, #length)
  );

  /// Returns a cell with a value equal the element at [index] in the [List] held in this cell.
  ///
  /// Changing the value of the returned cell, changes the value of the element
  /// at [index] in the [List] held in this cell.
  ///
  /// **NOTE**: The actual list is not modified but a new list is created.
  MutableCell<T> operator[](int index) => mutableApply((value) => value[index],
      (v) => value = _updatedList(value, index, v),
      willChange: (_, v) => value[index] != v[index],
      key: _MutableListIndexKey(this, index)
  );

  /// Set the value of element [index] to [elem] in the [List] held in this cell.
  ///
  /// **NOTE**: The actual list is not modified but a new list is created.
  void operator[]=(int index, T elem) {
    value = _updatedList(value, index, elem);
  }
}

/// Key identifying a [ValueCell], which accesses a [List] property.
class _ListPropKey extends ValueKey2<ValueCell, Symbol> {
  /// Create the key.
  ///
  /// [value1] is a [ValueCell] holding a list and [value2] is the property
  /// being accessed.
  _ListPropKey(super.value1, super.value2);
}

/// Key identifying a [MutableCell], which accesses a [List] property.
class _MutableListPropKey extends ValueKey2<MutableCell, Symbol> {
  /// Create the key.
  ///
  /// [value1] is a [MutableCell] holding a list and [value2] is the property
  /// being accessed.
  _MutableListPropKey(super.value1, super.value2);
}

/// Key identifying a [ValueCell] which access an element with a [List]
class _ListIndexKey extends ValueKey2<ValueCell, int> {
  /// Create the key.
  ///
  /// [value1] is a [ValueCell] holding a list and [value2] is the index of the
  /// element being accessed.
  _ListIndexKey(super.value1, super.value2);
}

/// Key identifying a [MutableCell] which access an element with a [List]
class _MutableListIndexKey extends ValueKey2<MutableCell, int> {
  /// Create the key.
  ///
  /// [value1] is a [MutableCell] holding a list and [value2] is the index of the
  /// element being accessed.
  _MutableListIndexKey(super.value1, super.value2);
}

/// Return a copy of [list] with element [index] set to [newValue].
///
/// This is not the most efficient way of doing this. Eventually the underlying
/// array should be replaced by a different data structure.
List<T> _updatedList<T>(List<T> list, int index, T newValue) {
  final newList = List<T>.from(list, growable: false);
  newList[index] = newValue;

  return UnmodifiableListView(newList);
}

/// Return a copy of [list] with the last element set to [value].
///
/// This is not the most efficient way of doing this. Eventually the underlying
/// array should be replaced by a different data structure.
List<T> _updateListLast<T>(List<T> list, T value) {
  final newList = List<T>.from(list, growable: false);
  newList.last = value;

  return UnmodifiableListView(newList);
}

/// Return a copy of [list] with [length] elements.
///
/// This is not the most efficient way of doing this. Eventually the underlying
/// array should be replaced by a different data structure.
List<T> _updateListLength<T>(List<T> list, int length) {
  if (length >= 0 && length <= list.length) {
    return list.sublist(0, length);
  }

  List<T> newList = List<T>.from(list);
  newList.length = length;

  return UnmodifiableListView(newList);
}