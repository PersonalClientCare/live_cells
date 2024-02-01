import 'package:flutter/foundation.dart';

import '../base/cell_state.dart';
import '../base/exceptions.dart';
import '../compute_cell/mutable_computed_cell_state.dart';
import '../restoration/restoration.dart';
import '../stateful_cell/stateful_cell.dart';
import '../value_cell.dart';
import 'mutable_cell.dart';

/// Base class for a computational cell which can have its value set.
///
/// The use of this class is similar to [DependentCell] however the [compute]
/// method, rather than the [value] property setter, has to be overriden with
/// the implementation of the cell computation function.
///
/// Constructors of this class must call the [MutableDependentCell] constructor
/// with the list of argument cells which are referenced in the [compute]
/// function. The value of the cell will be recomputed whenever the value of
/// one of the argument cells changes.
///
/// Additionally, subclasses must also implement the [reverseCompute] method,
/// which is called whenever the value of the cell is set. This method should
/// update the values of the argument cells.
abstract class MutableDependentCell<T> extends StatefulCell<T>
    implements MutableCell<T>, RestorableCell<T> {

  /// List of argument cells.
  @protected
  final Set<ValueCell> arguments;

  /// Construct a [MutableDependentCell] which depends on the cells in [arguments]
  ///
  /// Every cell of which the value is referenced in [compute] must be
  /// included in [arguments].
  MutableDependentCell(this.arguments, {super.key});

  /// Compute the value of the cell.
  ///
  /// Implementations of this method may reference the values of cells included
  /// in [arguments].
  ///
  /// The new cell value should be returned.
  T compute();

  /// Set the value of the argument cells in response to the value of the cell being set.
  ///
  /// Implementations of this method should be update the values of the cells in
  /// [arguments] based on [value], which is the new value of the cell.
  ///
  /// This method is executed in a [MutableCell.batch] call.
  void reverseCompute(T value);

  @override
  T get value {
    final state = _state;

    if (state == null) {
      try {
        return compute();
      }
      on StopComputeException catch (e) {
        return e.defaultValue;
      }
    }

    return state.value;
  }

  @override
  set value(T value) {
    final state = _state;

    if (state == null) {
      MutableCell.batch(() {
        try {
          reverseCompute(value);
        }
        catch (e, st) {
          if (kDebugMode) {
            print('Exception in MutableDependentCell reverse computation function: $e - $st');
          }
        }
      });
    }
    else {
      state.value = value;
    }
  }

  // Private

  CellState? _restoredState;

  MutableComputedCellState<T, MutableDependentCell>? get _state =>
      currentState<MutableComputedCellState<T, MutableDependentCell>>();

  @override
  CellState<StatefulCell> createState() {
    if (_restoredState != null) {
      final state = _restoredState;
      _restoredState = null;

      return state!;
    }

    return MutableComputedCellState(
        cell: this,
        key: key,
        arguments: arguments
    );
  }

  @override
  Object? dumpState(CellValueCoder coder) => _state?.dumpState(coder);

  @override
  void restoreState(Object? state, CellValueCoder coder) {
    if (state != null) {
      final restoredState = _state ?? createState() as MutableComputedCellState;
      restoredState.restoreState(state, coder);

      _restoredState = restoredState;
    }
  }
}
