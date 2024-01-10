import 'dynamic_compute_cell.dart';
import '../mutable_cell/mutable_dependent_cell.dart';

/// A mutable computational cell which determines is dependencies at runtime
///
/// Usage:
///
/// Create a [DynamicMutableComputeCell] by passing the value computation function,
/// and reverse computation function to the default constructor:
///
/// ```dart
/// final sum = DynamicMutableComputeCell(() => a() + b(), (sum) {
///   final half = sum / 2;
///   a.value = half;
///   b.value = half;
/// });
/// ```
class DynamicMutableComputeCell<T> extends MutableDependentCell<T> {
  DynamicMutableComputeCell({
    required T Function() compute,
    required void Function(T) reverseCompute
  }) : _compute = compute, _reverseCompute = reverseCompute, super({});

  @override
  T compute() {
    return ComputeArgumentsTracker.computeWithTracker(_compute, (cell) {
      if (!arguments.contains(cell)) {
        arguments.add(cell);

        if (isInitialized) {
          cell.addObserver(this);
        }
      }
    });
  }

  @override
  void reverseCompute(T value) {
    _reverseCompute(value);
  }

  /// Private

  final T Function() _compute;
  final void Function(T) _reverseCompute;
}