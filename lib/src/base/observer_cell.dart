import 'package:flutter/cupertino.dart';
import 'package:live_cells/live_cells.dart';

import '../value_cell.dart';
import 'cell_observer.dart';

/// Implements the [CellObserver] interface for cells of which the value depends on other cells.
///
/// This cell provides an implementation of [CellObserver.willUpdate] and
/// [CellObserver.update] which keep track of whether the cells value should
/// be recomputed.
///
/// Classes which make use of this mixin, should check the [stale] property
/// within [value]. If [stale] is true, the cell's value should be recomputed.
mixin ObserverCell<T> on CellListeners<T> implements CellObserver {
  /// Should the cell's value be recomputed
  @protected
  var stale = false;

  /// Is a cell value update currently in progress
  @protected
  var updating = false;

  @override
  void willUpdate(ValueCell cell) {
    if (!updating) {
      updating = true;
      _oldValue = value;

      notifyWillUpdate();
      stale = true;
    }
  }

  @override
  void update(ValueCell cell) {
    if (updating) {
      if (value != _oldValue) {
        notifyUpdate();
      }

      stale = false;
      updating = false;
      _oldValue = null;
    }
  }

  /// Private

  /// The cell's value at the start of the current update cycle
  T? _oldValue;
}