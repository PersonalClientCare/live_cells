import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:live_cells_core/live_cells_core.dart';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<CellObserver>(as: #MockSimpleObserver)])
import 'live_cells_test.mocks.dart';

/// Mock class interface for recording the value of a cell at the time an observer was called
abstract class ValueObserver {
  /// Mock method called by listener to record cell value
  void gotValue(value);
}

/// Mock class implementing [ValueObserver]
///
/// Usage:
///
///   - Add instance as a listener of a cell
///   - verify(instance.gotValue(expected))
class MockValueObserver extends MockSimpleObserver implements ValueObserver {
  /// List of values obtained (duplicates are removed)
  final values = [];

  @override
  void update(covariant ValueCell cell, covariant bool didChange) {
    final value = cell.value;

    if (values.lastOrNull != value) {
      values.add(value);
    }

    gotValue(value);
  }
}

/// Mock class interface for recording whether a listener was called
abstract class SimpleListener {
  /// Method added as listener function
  void call();
}

/// Mock class implementing [SimpleListener]
///
/// Usage:
///
///   - Add instance as a listener of a cell
///   - verify(instance())
class MockSimpleListener extends Mock implements SimpleListener {}

abstract class TestResource {
  void init();
  void dispose();
}

class MockResource extends Mock implements TestResource {
  @override
  void init();
  @override
  void dispose();
}

class ManagedCellState extends CellState {
  final TestResource resource;

  ManagedCellState({
    required super.cell,
    required super.key,
    required this.resource
  });

  @override
  void init() {
    super.init();
    resource.init();
  }

  @override
  void dispose() {
    resource.dispose();
    super.dispose();
  }
}

class TestManagedCell<T> extends StatefulCell<T> {
  final TestResource _resource;

  @override
  final T value;

  TestManagedCell(this._resource, this.value);

  @override
  CellState<StatefulCell> createState() => ManagedCellState(
      cell: this,
      key: key,
      resource: _resource
  );
}

enum TestEnum {
  value1,
  value2,
  value3
}

void main() {
  group('ConstantCell', () {
    test('Integer ConstantCell.value equals value given in constructor', () {
      final cell = 10.cell;
      expect(cell.value, equals(10));
    });

    test('String ConstantCell.value equals value given in constructor', () {
      final cell = 'Hello World'.cell;
      expect(cell.value, equals('Hello World'));
    });

    test('Boolean ConstantCell.value equals value given in constructor', () {
      final cell1 = true.cell;
      final cell2 = false.cell;

      expect(cell1.value, isTrue);
      expect(cell2.value, isFalse);
    });

    test('Null ConstantCell.value equals value given in constructor', () {
      final cell = null.cell;

      expect(cell.value, isNull);
    });

    test('Enum ConstantCell.value equals value given in constructor', () {
      final cell1 = TestEnum.value1.cell;
      final cell2 = TestEnum.value2.cell;
      final cell3 = TestEnum.value3.cell;

      expect(cell1.value, equals(TestEnum.value1));
      expect(cell2.value, equals(TestEnum.value2));
      expect(cell3.value, equals(TestEnum.value3));
    });

    test('Constant cells compare == if they hold the same value', () {
      final a = 1.cell;
      const b = ValueCell.value(1);

      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
    });

    test('Constant cells compare != if they hold the different values', () {
      final a = 1.cell;
      final b = 2.cell;

      expect(a != b, isTrue);
    });  });

  group('MutableCell', () {
    test('MutableCell.value equals initial value when not changed', () {
      final cell = MutableCell(15);
      expect(cell.value, equals(15));
    });

    test('Setting MutableCell.value changes cell value', () {
      final cell = MutableCell(15);
      cell.value = 23;

      expect(cell.value, equals(23));
    });

    test('MutableCell.value keeps latest value that was set', () {
      final cell = MutableCell(15);
      cell.value = 23;
      cell.value = 101;

      expect(cell.value, equals(101));
    });

    test('Setting MutableCell.value calls cell listeners', () {
      final cell = MutableCell(15);
      final observer = MockSimpleObserver();

      cell.addObserver(observer);
      cell.value = 23;

      verify(observer.update(cell, any)).called(1);
    });

    test('Setting MutableCell.value twice calls cell listeners twice', () {
      final cell = MutableCell(15);
      final observer = MockSimpleObserver();

      cell.addObserver(observer);

      cell.value = 23;
      cell.value = 101;

      verify(observer.update(cell, any)).called(2);
    });

    test('MutableCell observer not called after it is removed', () {
      final cell = MutableCell(15);
      final observer = MockSimpleObserver();

      cell.addObserver(observer);
      cell.value = 23;

      cell.removeObserver(observer);
      cell.value = 101;

      verify(observer.update(cell, any)).called(1);
    });

    test('MutableCell observer not called if new value is equal to old value', () {
      final cell = MutableCell(56);
      final observer = MockSimpleObserver();

      cell.addObserver(observer);
      cell.value = 56;

      verifyNever(observer.update(cell, any));
    });

    test('All MutableCell observers called when value changes', () {
      final cell = MutableCell(3);

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      cell.addObserver(observer1);
      cell.value = 5;

      cell.addObserver(observer2);
      cell.value = 8;
      cell.value = 12;

      verify(observer1.update(cell, any)).called(3);
      verify(observer2.update(cell, any)).called(2);
    });

    test('MutableCell.value updated when observer called', () {
      final cell = MutableCell('hello');
      final observer = MockValueObserver();

      cell.addObserver(observer);

      cell.value = 'bye';
      verify(observer.gotValue('bye'));
    });

    test('All cell values updates using MutableCell.batch', () {
      final a = MutableCell(0);
      final b = MutableCell(0);
      final op = MutableCell('');

      final sum = a + b;
      final msg = (a, b, op, sum)
          .apply((a, b, op, sum) => '$a $op $b = $sum');

      final observer = MockSimpleObserver();
      msg.addObserver(observer);

      MutableCell.batch(() {
        a.value = 1;
        b.value = 2;
        op.value = '+';
      });

      expect(msg.value, '1 + 2 = 3');
    });
  });

  group('Equality Comparisons', () {
    test('ConstantCell\'s are eq if they have equal values', () {
      const a = ConstantCell(1);
      const b = ConstantCell(1);

      expect(a.eq(b).value, equals(true));
    });

    test('ConstantCell\'s are not eq if they have unequal values', () {
      const a = ConstantCell(1);
      const b = ConstantCell(2);

      expect(a.eq(b).value, equals(false));
    });

    test('ConstantCell\'s are neq if they have unequal values', () {
      const a = ConstantCell(3);
      const b = ConstantCell(4);

      expect(a.neq(b).value, equals(true));
    });

    test('ConstantCell\'s are not neq if they have equal values', () {
      const a = ConstantCell(3);
      const b = ConstantCell(3);

      expect(a.neq(b).value, equals(false));
    });

    test('EqCell is reevaluated when 1st argument cell value changes', () {
      final a = MutableCell(3);
      final b = MutableCell(4);

      a.value = 4;

      expect(a.eq(b).value, equals(true));
    });

    test('EqCell is reevaluated when 2nd argument cell values changes', () {
      final a = MutableCell(3);
      final b = MutableCell(4);

      b.value = 3;

      expect(a.eq(b).value, equals(true));
    });

    test('EqCell observers notified when 1st argument cell values changes', () {
      final a = MutableCell(3);
      final b = MutableCell(4);

      final eq = a.eq(b);
      final observer = MockSimpleObserver();

      eq.addObserver(observer);
      a.value = 4;

      verify(observer.update(eq, any)).called(1);
    });

    test('EqCell observers notified when 2nd argument cell values changes', () {
      final a = MutableCell(3);
      final b = MutableCell(4);

      final eq = a.eq(b);
      final observer = MockSimpleObserver();

      eq.addObserver(observer);
      b.value = 3;

      verify(observer.update(eq, any)).called(1);
    });

    test('NeqCell is reevaluated when 1st argument cell value changes', () {
      final a = MutableCell(3);
      final b = MutableCell(4);

      a.value = 4;

      expect(a.neq(b).value, equals(false));
    });

    test('NeqCell is reevaluated when 2nd argument cell values changes', () {
      final a = MutableCell(3);
      final b = MutableCell(4);

      b.value = 3;

      expect(a.neq(b).value, equals(false));
    });

    test('NeqCell observers notified when 1st argument cell values changes', () {
      final a = MutableCell(3);
      final b = MutableCell(4);

      final neq = a.neq(b);
      final observer = MockSimpleObserver();

      neq.addObserver(observer);
      a.value = 4;

      verify(observer.update(neq, any)).called(1);
    });

    test('NeqCell observers notified when 2nd argument cell values changes', () {
      final a = MutableCell(3);
      final b = MutableCell(4);

      final neq = a.eq(b);
      final observer = MockSimpleObserver();

      neq.addObserver(observer);
      b.value = 3;

      verify(observer.update(neq, any)).called(1);
    });

    test("EqCell's compare == if they compare the same cells", () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final eq1 = a.eq(b);
      final eq2 = a.eq(b);

      expect(eq1 == eq2, isTrue);
      expect(eq1.hashCode == eq2.hashCode, isTrue);
    });

    test("EqCell's compare != if they compare different cells", () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final eq1 = a.eq(b);
      final eq2 = a.eq(2.cell);
      final eq3 = 2.cell.eq(b);

      expect(eq1 != eq2, isTrue);
      expect(eq1 != eq3, isTrue);
    });

    test("NeqCell's compare == if they compare the same cells", () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final neq1 = a.neq(b);
      final neq2 = a.neq(b);

      expect(neq1 == neq2, isTrue);
      expect(neq1.hashCode == neq2.hashCode, isTrue);
    });

    test("NeqCell's compare != if they compare different cells", () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final neq1 = a.neq(b);
      final neq2 = a.neq(2.cell);
      final neq3 = 2.cell.neq(b);

      expect(neq1 != neq2, isTrue);
      expect(neq1 != neq3, isTrue);
    });
  });

  group('ComputeCell', () {
    test('ComputeCell function applied on ConstantCell value', () {
      const a = ConstantCell(1);
      final b = a.apply((value) => value + 1);

      expect(b.value, equals(2));
    });

    test('ComputeCell reevaluated when value of argument cell changes', () {
      final a = MutableCell(1);
      final b = a.apply((value) => value + 1);

      a.value = 5;

      expect(b.value, equals(6));
    });

    test('N-ary ComputeCell reevaluated when value of 1st argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = (a,b).apply((a, b) => a + b);

      a.value = 5;

      expect(c.value, equals(7));
    });

    test('N-ary ComputeCell reevaluated when value of 2nd argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = (a,b).apply((a, b) => a + b);

      b.value = 8;

      expect(c.value, equals(9));
    });

    test('ComputeCell observers notified when value of 1st argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = (a,b).apply((a, b) => a + b);

      final observer = MockSimpleObserver();
      c.addObserver(observer);

      a.value = 8;

      verify(observer.update(c, any)).called(1);
    });

    test('ComputeCell observers notified when value of 2nd argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = (a,b).apply((a, b) => a + b);

      final observer = MockSimpleObserver();
      c.addObserver(observer);

      b.value = 8;

      verify(observer.update(c, any)).called(1);
    });

    test('ComputeCell observers notified for each change of value of argument cell', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = (a,b).apply((a, b) => a + b);

      final observer = MockSimpleObserver();
      c.addObserver(observer);

      b.value = 8;
      a.value = 10;
      b.value = 100;

      verify(observer.update(c, any)).called(3);
    });

    test('ComputeCell observer not called after it is removed', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = (a,b).apply((a, b) => a + b);

      final observer = MockSimpleObserver();

      c.addObserver(observer);
      a.value = 8;

      c.removeObserver(observer);
      b.value = 10;
      a.value = 100;

      verify(observer.update(c, any)).called(1);
    });

    test('All ComputeCell observers called when value changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = (a,b).apply((a, b) => a + b);

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      c.addObserver(observer1);
      a.value = 8;

      c.addObserver(observer2);
      b.value = 10;
      a.value = 100;

      verify(observer1.update(c, any)).called(3);
      verify(observer2.update(c, any)).called(2);
    });

    test("ComputeCell's compare == if they have the same key", () {
      final a = MutableCell(0);
      final b = MutableCell(1);

      final c1 = (a, b).apply((a, b) => a + b, key: 'theKey');
      final c2 = (a, b).apply((a, b) => a + b, key: 'theKey');

      expect(c1 == c2, isTrue);
      expect(c1.hashCode == c2.hashCode, isTrue);
    });

    test("ComputeCell's compare != if they have different keys", () {
      final a = MutableCell(0);
      final b = MutableCell(1);

      final c1 = (a, b).apply((a, b) => a + b, key: 'theKey1');
      final c2 = (a, b).apply((a, b) => a + b, key: 'theKey2');

      expect(c1 != c2, isTrue);
    });

    test("ComputeCell's compare != if they have null keys", () {
      final a = MutableCell(0);
      final b = MutableCell(1);

      final c1 = (a, b).apply((a, b) => a + b);
      final c2 = (a, b).apply((a, b) => a + b);

      expect(c1 != c2, isTrue);
      expect(c1 == c1, isTrue);
    });
  });

  group('DynamicComputeCell', () {
    test('DynamicComputeCell function applied on ConstantCell value', () {
      final a = 1.cell;
      final b = ValueCell.computed(() => a() + 1);

      expect(b.value, equals(2));
    });

    test('DynamicComputeCell reevaluated when value of argument cell changes', () {
      final a = MutableCell(1);
      final b = ValueCell.computed(() => a() + 1);

      final observer = MockSimpleObserver();
      b.addObserver(observer);

      a.value = 5;

      expect(b.value, equals(6));
    });

    test('N-ary DynamicComputeCell reevaluated when value of 1st argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = ValueCell.computed(() => a() + b());

      final observer = MockSimpleObserver();
      c.addObserver(observer);

      a.value = 5;

      expect(c.value, equals(7));
    });

    test('N-ary DynamicComputeCell reevaluated when value of 2nd argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = ValueCell.computed(() => a() + b());

      final observer = MockSimpleObserver();
      c.addObserver(observer);

      b.value = 8;

      expect(c.value, equals(9));
    });

    test('DynamicComputeCell observers notified when value of 1st argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = ValueCell.computed(() => a() + b());

      final observer = MockSimpleObserver();
      c.addObserver(observer);

      a.value = 8;

      verify(observer.update(c, any)).called(1);
    });

    test('DynamicComputeCell observers notified when value of 2nd argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = ValueCell.computed(() => a() + b());

      final observer = MockSimpleObserver();
      c.addObserver(observer);

      b.value = 8;

      verify(observer.update(c, any)).called(1);
    });

    test('DynamicComputeCell observers notified for each change of value of argument cell', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = ValueCell.computed(() => a() + b());

      final observer = MockSimpleObserver();
      c.addObserver(observer);

      b.value = 8;
      a.value = 10;
      b.value = 100;

      verify(observer.update(c, any)).called(3);
    });

    test('DynamicComputeCell observer not called after it is removed', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = ValueCell.computed(() => a() + b());

      final observer = MockSimpleObserver();

      c.addObserver(observer);
      a.value = 8;

      c.removeObserver(observer);
      b.value = 10;
      a.value = 100;

      verify(observer.update(c, any)).called(1);
    });

    test('All DynamicComputeCell observers called when value changes', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final c = ValueCell.computed(() => a() + b());

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      c.addObserver(observer1);
      a.value = 8;

      c.addObserver(observer2);
      b.value = 10;
      a.value = 100;

      verify(observer1.update(c, any)).called(3);
      verify(observer2.update(c, any)).called(2);
    });

    test('DynamicComputeCell arguments tracked correctly when using conditionals', () {
      final a = MutableCell(true);
      final b = MutableCell(2);
      final c = MutableCell(3);

      final d = ValueCell.computed(() => a() ? b() : c());

      final observer = MockValueObserver();
      d.addObserver(observer);

      b.value = 1;
      a.value = false;
      c.value = 10;

      expect(observer.values, equals([1, 3, 10]));
    });

    test('DynamicComputeCell arguments tracked correctly when argument is a DynamicComputeCell', () {
      final a = MutableCell(true);
      final b = MutableCell(2);
      final c = MutableCell(3);

      final d = ValueCell.computed(() => a() ? b() : c());

      final e = MutableCell(0);

      final f = ValueCell.computed(() => d() + e());

      final observer = MockValueObserver();
      f.addObserver(observer);

      b.value = 1;
      e.value = 10;
      a.value = false;
      c.value = 10;

      expect(observer.values, equals([1, 11, 13, 20]));
    });

    test('Previous DynamicComputeCell.value preserved if ValueCell.none is used', () {
      final a = MutableCell(0);
      final evens = ValueCell.computed(() => a().isEven ? a() : ValueCell.none());

      final observer = addObserver(evens, MockValueObserver());

      a.value = 1;
      a.value = 2;
      a.value = 3;
      a.value = 4;
      a.value = 5;

      expect(observer.values, equals([0, 2, 4]));
    });

    test('DynamicComputeCell.value initialized to defaultValue if ValueCell.none is used', () {
      final a = MutableCell(1);
      final evens = ValueCell.computed(() => a().isEven ? a() : ValueCell.none(0));

      final observer = addObserver(evens, MockValueObserver());

      a.value = 3;
      a.value = 4;
      a.value = 5;
      a.value = 6;

      expect(observer.values, equals([0, 4, 6]));
    });

    test('Exception on initialization of value reproduced on value access', () {
      final cell = ValueCell.computed(() => throw Exception());

      expect(() => cell.value, throwsException);
    });

    test('Exception on initialization of value reproduced on value access while observed', () {
      final cell = ValueCell.computed(() => throw Exception());
      observeCell(cell);

      expect(() => cell.value, throwsException);
    });

    test("DynamicComputeCell's compare == if they have the same keys", () {
      final a = MutableCell(0);
      final b = MutableCell(0);

      final c1 = ValueCell.computed(() => a() + b(), key: 'theKey');
      final c2 = ValueCell.computed(() => a() + b(), key: 'theKey');

      expect(c1 == c2, isTrue);
      expect(c1.hashCode == c2.hashCode, isTrue);
    });

    test("DynamicComputeCell's compare != if they have different keys", () {
      final a = MutableCell(0);
      final b = MutableCell(0);

      final c1 = ValueCell.computed(() => a() + b(), key: 'theKey1');
      final c2 = ValueCell.computed(() => a() + b(), key: 'theKey2');

      expect(c1 != c2, isTrue);
    });

    test("DynamicComputeCell's compare != if they have null keys", () {
      final a = MutableCell(0);
      final b = MutableCell(0);

      final c1 = ValueCell.computed(() => a() + b());
      final c2 = ValueCell.computed(() => a() + b());

      expect(c1 != c2, isTrue);
      expect(c1 == c1, isTrue);
    });

    test("Keyed DynamicComputeCell's manage the same set of observers", () {
      final resource = MockResource();
      final a = TestManagedCell(resource, 0);
      f() => ValueCell.computed(() => a() + 1, key: 'theKey');

      verifyNever(resource.init());

      final observer = addObserver(f(), MockSimpleObserver());
      f().removeObserver(observer);

      verify(resource.init()).called(1);
      verify(resource.dispose()).called(1);
    });

    test('DynamicComputeCell state recreated on adding observer after dispose', () {
      final resource = MockResource();
      final a = TestManagedCell(resource, 0);
      f() => ValueCell.computed(() => a() + 1, key: 'theKey');

      verifyNever(resource.init());

      final observer = addObserver(f(), MockSimpleObserver());
      f().removeObserver(observer);

      observeCell(f());

      verify(resource.init()).called(2);
      verify(resource.dispose()).called(1);
    });
  });

  group('StoreCell', () {
    test('StoreCell takes value of argument cell', () {
      final a = MutableCell('hello');
      final store = a.store();

      expect(store.value, equals('hello'));
    });

    test('StoreCell takes latest value of argument cell', () {
      final a = MutableCell('hello');
      final store = a.store();

      final observer = MockSimpleObserver();

      a.value = 'bye';
      store.addObserver(observer);

      expect(store.value, equals('bye'));
    });

    test('StoreCell observers notified when argument cell value changes', () {
      final a = MutableCell('hello');
      final store = a.store();

      final observer = MockSimpleObserver();

      store.addObserver(observer);
      a.value = 'bye';
      a.value = 'goodbye';

      verify(observer.update(store, any)).called(2);
    });

    test('All StoreCell observers notified when argument cell value changes', () {
      final a = MutableCell('hello');
      final store = a.store();

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      store.addObserver(observer1);
      a.value = 'bye';

      store.addObserver(observer2);
      a.value = 'goodbye';

      verify(observer1.update(store, any)).called(2);
      verify(observer2.update(store, any)).called(1);
    });

    test('StoreCell observer not called after it is removed', () {
      final a = MutableCell('hello');
      final store = a.store();

      final observer = MockSimpleObserver();

      store.addObserver(observer);
      a.value = 'bye';

      store.removeObserver(observer);
      a.value = 'goodbye';

      verify(observer.update(store, any)).called(1);
    });

    test('StoreCell.value updated when observer called', () {
      final cell = MutableCell('hello');
      final store = cell.store();

      final observer = MockValueObserver();

      store.addObserver(observer);

      cell.value = 'bye';
      verify(observer.gotValue('bye'));
    });

    test('Previous StoreCell.value preserved if ValueCell.none is used', () {
      final a = MutableCell(0);
      final evens = a.apply((a) => a.isEven ? a : ValueCell.none()).store();

      final observer = addObserver(evens, MockValueObserver());

      a.value = 1;
      a.value = 2;
      a.value = 3;
      a.value = 4;
      a.value = 5;

      expect(observer.values, equals([0, 2, 4]));
    });

    test('StoreCell.value initialized to defaultValue if ValueCell.none is used', () {
      final a = MutableCell(1);
      final evens = a.apply((a) => a.isEven ? a : ValueCell.none(10)).store();

      final observer = addObserver(evens, MockValueObserver());

      a.value = 3;
      a.value = 4;
      a.value = 5;
      a.value = 6;

      expect(observer.values, equals([10, 4, 6]));
    });

    test('Exception on initialization of value reproduced on value access', () {
      final a = MutableCell(0);
      final cell = (a).apply((a) => a == 0 ? throw Exception() : a);
      final store = cell.store();

      expect(() => store.value, throwsException);
    });

    test('Exception on initialization of value reproduced on value access while observed', () {
      final a = MutableCell(0);
      final cell = a.apply((a) => a == 0 ? throw Exception() : a);
      final store = cell.store();

      observeCell(store);

      expect(() => store.value, throwsException);
    });

    test("StoreCell's compare == if they have the same argument cell", () {
      final a = MutableCell(0);
      final b = a * a;

      final c1 = b.store();
      final c2 = b.store();

      expect(c1 == c2, isTrue);
      expect(c1.hashCode == c2.hashCode, isTrue);
    });

    test("StoreCell's compare != if they have different argument cell", () {
      final a = MutableCell(0);
      final b1 = a * a;
      final b2 = a + a;

      final c1 = b1.store();
      final c2 = b2.store();

      expect(c1 != c2, isTrue);
      expect(c1 == c1, isTrue);
    });

    test("StoreCell's manage the same set of observers", () {
      final resource = MockResource();
      final a = TestManagedCell(resource, 1);
      final b = MutableCell(0);
      final c = a + b;

      f() => c.store();

      verifyNever(resource.init());

      final observer = addObserver(f(), MockSimpleObserver());
      f().removeObserver(observer);

      verify(resource.init()).called(1);
      verify(resource.dispose()).called(1);
    });

    test('StoreCell state recreated on adding observer after dispose', () {
      final resource = MockResource();
      final a = TestManagedCell(resource, 1);
      final b = MutableCell(0);
      final c = a + b;

      f() => c.store();

      verifyNever(resource.init());

      final observer = addObserver(f(), MockSimpleObserver());
      f().removeObserver(observer);

      observeCell(f());

      verify(resource.init()).called(2);
      verify(resource.dispose()).called(1);
    });
  });

  group('NumericExtension', () {
    test('a + b creates ValueCell which is equal to the sum of a and b', () {
      final a = 5.cell;
      final b = 6.cell;

      final c = a + b;

      expect(c.value, equals(11));
    });

    test('a - b creates ValueCell which is equal to the difference of a and b', () {
      final a = 13.cell;
      final b = 20.cell;

      final c = a - b;

      expect(c.value, equals(-7));
    });

    test('a * b creates ValueCell which is equal to the product of a and b', () {
      final a = 10.cell;
      final b = 8.cell;

      final c = a * b;

      expect(c.value, equals(80));
    });

    test('a / b creates ValueCell which is equal to the quotient of a and b', () {
      final a = 7.cell;
      final b = 2.cell;

      final c = a / b;

      expect(c.value, equals(3.5));
    });

    test('a ~/ b creates ValueCell which is equal to the truncated quotient of a and b', () {
      final a = 7.cell;
      final b = 2.cell;

      final c = a ~/ b;

      expect(c.value, equals(3));
    });

    test('a % b creates ValueCell which is equal to the modulo of a / b', () {
      final a = 17.cell;
      final b = 3.cell;

      final c = a % b;

      expect(c.value, equals(2));
    });


    test('a.remainder(b) creates ValueCell which is equal to the remainder of a / b', () {
      final a = 7.cell;
      final b = 2.cell;

      final c = a.remainder(b);

      expect(c.value, equals(1));
    });

    test('a < b creates ValueCell which equals true if a is less than b', () {
      final a = 3.cell;
      final b = 8.cell;

      final lt = a < b;
      final gt = b < a;

      expect(lt.value, isTrue);
      expect(gt.value, isFalse);
    });

    test('a <= b creates ValueCell which equals true if a is less than b', () {
      final a = 3.cell;
      final b = 8.cell;

      final lt = a <= b;
      final gt = b <= a;

      expect(lt.value, isTrue);
      expect(gt.value, isFalse);
    });

    test('a <= b creates ValueCell which equals true if a is equal to b', () {
      final a = 5.cell;
      final b = 5.cell;

      final lt = a <= b;
      final gt = b <= a;

      expect(lt.value, isTrue);
      expect(gt.value, isTrue);
    });

    test('a > b creates ValueCell which equals true if a is greater than b', () {
      final a = 3.cell;
      final b = 8.cell;

      final lt = a > b;
      final gt = b > a;

      expect(lt.value, isFalse);
      expect(gt.value, isTrue);
    });

    test('a >= b creates ValueCell which equals true if a is greater than b', () {
      final a = 3.cell;
      final b = 8.cell;

      final lt = a >= b;
      final gt = b >= a;

      expect(lt.value, isFalse);
      expect(gt.value, isTrue);
    });

    test('a >= b creates ValueCell which equals true if a is equal to b', () {
      final a = 5.cell;
      final b = 5.cell;

      final lt = a <= b;
      final gt = b <= a;

      expect(lt.value, isTrue);
      expect(gt.value, isTrue);
    });

    test('a.isNaN creates ValueCell which equals true if a is NaN', () {
      final a = 0.cell;
      final c = a / a;
      final d = c.isNaN;

      expect(d.value, isTrue);
    });

    test('a.isNaN creates ValueCell which equals false if a is not NaN', () {
      final a = 2.cell;
      final c = a / a;
      final d = c.isNaN;

      expect(d.value, isFalse);
    });

    test('a.isFinite creates ValueCell which equals true if a is finite', () {
      final a = 3.cell;
      final c = a / a;
      final d = c.isFinite;

      expect(d.value, isTrue);
    });

    test('a.isFinite creates ValueCell which equals false if a is not finite', () {
      final a = 3.cell;
      final b = 0.cell;
      final c = a / b;
      final d = c.isFinite;

      expect(d.value, isFalse);
    });

    test('a.isInfinite creates ValueCell which equals false if a is finite', () {
      final a = 3.cell;
      final c = a / a;
      final d = c.isInfinite;

      expect(d.value, isFalse);
    });

    test('a.isInfinite creates ValueCell which equals true if a is not finite', () {
      final a = 3.cell;
      final b = 0.cell;
      final c = a / b;
      final d = c.isInfinite;

      expect(d.value, isTrue);
    });

    test('a.abs() creates ValueCell which is equal to absolute value of a', () {
      final a = -3.cell;

      expect(a.abs().value, equals(3));
    });

    test('a.sign creates ValueCell which is equal to 1 if a > 0', () {
      final a = 3.cell;

      expect(a.sign.value, equals(1));
    });

    test('a.sign creates ValueCell which is equal to -1 if a < 0', () {
      final a = -3.cell;

      expect(a.sign.value, equals(-1));
    });

    test('a.sign creates ValueCell which is equal to 0 if a == 0', () {
      final a = 0.cell;

      expect(a.sign.value, equals(0));
    });
  });

  group('BoolCellExtension', () {
    test('BoolCellExtension.and produces cell which is the logical and of its arguments', () {
      final a = MutableCell(true);
      final b = MutableCell(true);
      final and = a.and(b);

      expect(and.value, isTrue);

      a.value = false;
      expect(and.value, isFalse);

      b.value = false;
      expect(and.value, isFalse);

      a.value = true;
      expect(and.value, isFalse);

      b.value = true;
      expect(and.value, isTrue);
    });

    test('BoolCellExtension.or produces cell which is the logical or of its arguments', () {
      final a = MutableCell(true);
      final b = MutableCell(true);
      final or = a.or(b);

      expect(or.value, isTrue);

      a.value = false;
      expect(or.value, isTrue);

      b.value = false;
      expect(or.value, isFalse);

      a.value = true;
      expect(or.value, isTrue);

      b.value = true;
      expect(or.value, isTrue);
    });

    test('BoolCellExtension.not produces cell which is the logical not of itself', () {
      final a = MutableCell(true);
      final not = a.not();

      expect(not.value, isFalse);

      a.value = false;
      expect(not.value, isTrue);
    });

    test('BoolCellExtension.select with ifFalse selects correct value', () {
      final a = 'true'.cell;
      final b = MutableCell('false');
      final cond = MutableCell(true);

      final select = cond.select(a, b);
      final observer = addObserver(select, MockValueObserver());

      expect(select.value, equals('true'));

      cond.value = false;
      b.value = 'else';
      cond.value = true;

      expect(observer.values, equals(['false', 'else', 'true']));
    });

    test('BoolCellExtension.select with ifFalse does not update value when false', () {
      final a = MutableCell('true');
      final cond = MutableCell(true);

      final select = cond.select(a);

      observeCell(select);
      expect(select.value, equals('true'));

      cond.value = false;
      expect(select.value, equals('true'));

      a.value = 'then';
      expect(select.value, equals('true'));

      cond.value = true;
      expect(select.value, equals('then'));

      a.value = 'when';
      expect(select.value, equals('when'));
    });
  });

  group('ErrorCellExtension', () {
    test('ErrorCellExtension.on handles all exceptions without type argument', () {
      final a = MutableCell(1);
      final b = ValueCell.computed(() {
        if (a() <= 0) {
          throw 'A generic exception';
        }

        return a();
      });

      final c = MutableCell(2);
      final result = b.onError(c);

      final observer = addObserver(result, MockValueObserver());
      expect(result.value, equals(1));

      a.value = 0;
      c.value = 4;
      a.value = 10;
      c.value = 100;

      expect(observer.values, equals([2, 4, 10]));
    });

    test('ErrorCellExtension.on handles only given exception with type argument', () {
      final a = MutableCell(1);
      final b = ValueCell.computed(() {
        if (a() < 0) {
          throw Exception('A generic exception');
        }
        else if (a() == 0) {
          throw ArgumentError('A cannot be 0');
        }

        return a();
      });

      final c = MutableCell(2);
      final result = b.onError<ArgumentError>(c);

      final observer = addObserver(result, MockValueObserver());
      expect(result.value, equals(1));

      a.value = 0;
      c.value = 4;
      a.value = 10;
      c.value = 100;

      expect(observer.values, equals([2, 4, 10]));

      result.removeObserver(observer);

      a.value = -1;
      expect(() => result.value, throwsException);
    });

    test('ErrorCellExtension.error captures exceptions thrown during computation', () {
      final a = MutableCell(1);
      final b = ValueCell.computed(() {
        if (a() < 0) {
          throw 'A generic exception';
        }

        return a();
      });

      final error = b.error();
      final observer = addObserver(error, MockValueObserver());

      expect(error.value, isNull);

      a.value = 2;
      a.value = -1;
      a.value = 3;

      expect(observer.values, equals(['A generic exception']));
    });

    test('ErrorCellExtension.error always updates when all = true', () {
      final a = MutableCell(1);
      final b = ValueCell.computed(() {
        if (a() < 0) {
          throw 'A generic exception';
        }

        return a();
      });

      final error = b.error(all: true);

      observeCell(error);
      expect(error.value, isNull);

      a.value = 2;
      expect(error.value, isNull);

      a.value = -1;
      expect(error.value, equals('A generic exception'));

      a.value = 3;
      expect(error.value, isNull);
    });

    test('ErrorCellExtension.error captures exception of given type thrown during computation', () {
      final a = MutableCell(1);
      final b = ValueCell.computed(() {
        if (a() < 0) {
          throw 'A generic exception';
        }
        else if (a() == 0) {
          throw ArgumentError('Cannot be zero');
        }

        return a();
      });

      final error = b.error<ArgumentError>();

      observeCell(error);
      expect(error.value, isNull);

      a.value = 2;
      expect(error.value, isNull);

      a.value = 0;
      expect(error.value, isA<ArgumentError>());

      a.value = 3;
      expect(error.value, isA<ArgumentError>());

      a.value = -1;
      expect(error.value, isA<ArgumentError>());
    });

    test('ErrorCellExtension.error always updates when all = true and type argument given', () {
      final a = MutableCell(1);
      final b = ValueCell.computed(() {
        if (a() < 0) {
          throw 'A generic exception';
        }
        else if (a() == 0) {
          throw ArgumentError('Cannot be zero');
        }

        return a();
      });

      final error = b.error<ArgumentError>(all: true);

      observeCell(error);
      expect(error.value, isNull);

      a.value = 2;
      expect(error.value, isNull);

      a.value = 0;
      expect(error.value, isA<ArgumentError>());

      a.value = -1;
      expect(error.value, isNull);
    });
  });

  group('Cell update consistency', () {
    test('All observer methods called in correct order', () {
      final cell = MutableCell(10);
      final observer = MockSimpleObserver();

      cell.addObserver(observer);
      cell.value = 15;

      verifyInOrder([
        observer.willUpdate(cell),
        observer.update(cell, any)
      ]);

      verifyNoMoreInteractions(observer);
    });

    test('No intermediate values are recorded when using multi argument cells', () {
      final a = MutableCell(0);
      final sum = a + 1.cell;
      final prod = a * 8.cell;
      final result = sum + prod;

      final observer = MockValueObserver();
      result.addObserver(observer);

      a.value = 2;
      a.value = 6;

      expect(observer.values, equals([(2 + 1) + (2 * 8), (6 + 1) + (6 * 8)]));
    });

    test('No intermediate values are produced when using StoreCells', () {
      final a = MutableCell(0);
      final sum = (a + 1.cell).store();
      final prod = (a * 8.cell).store();
      final result = sum + prod;

      final observer = MockValueObserver();
      result.addObserver(observer);

      a.value = 2;
      a.value = 6;

      expect(observer.values, equals([(2 + 1) + (2 * 8), (6 + 1) + (6 * 8)]));
    });

    test('No intermediate values are produced when using StoreCells and branches are unequal', () {
      final a = MutableCell(0);
      final sum = ((a + 1.cell).store() + 10.cell).store();
      final prod = (a * 8.cell).store();
      final result = (sum + prod).store();

      final observer = MockValueObserver();
      result.addObserver(observer);

      a.value = 2;
      a.value = 6;

      expect(observer.values, equals([(2 + 1 + 10) + (2 * 8), (6 + 1 + 10) + (6 * 8)]));
    });

    test('No intermediate values are produced when using DynamicComputeCell', () {
      final a = MutableCell(0);
      final sum = ValueCell.computed(() => a() + 1);
      final prod = ValueCell.computed(() => a() * 8);
      final result = ValueCell.computed(() => sum() + prod());

      final observer = MockValueObserver();
      result.addObserver(observer);

      a.value = 2;
      a.value = 6;

      expect(observer.values, equals([(2 + 1) + (2 * 8), (6 + 1) + (6 * 8)]));
    });

    test('No intermediate values are produced when using DynamicComputeCell and branches are unequal', () {
      final a = MutableCell(0);

      final sum1 = ValueCell.computed(() => a() + 1);
      final sum = ValueCell.computed(() => sum1() + 10);

      final prod = ValueCell.computed(() => a() * 8);
      final result = ValueCell.computed(() => sum() + prod());

      final observer = MockValueObserver();
      result.addObserver(observer);

      a.value = 2;
      a.value = 6;

      expect(observer.values, equals([(2 + 1 + 10) + (2 * 8), (6 + 1 + 10) + (6 * 8)]));
    });

    test('No intermediate values are produced when using MutableCell.batch', () {
      final a = MutableCell(0);
      final b = MutableCell(0);
      final op = MutableCell('');

      final sum = a + b;
      final msg = (a, b, op, sum)
          .apply((a, b, op, sum) => '$a $op $b = $sum');

      final observer = MockValueObserver();
      msg.addObserver(observer);

      MutableCell.batch(() {
        a.value = 1;
        b.value = 2;
        op.value = '+';
      });

      MutableCell.batch(() {
        a.value = 5;
        b.value = 6;
        op.value = 'plus';
      });

      expect(observer.values, equals([
        '1 + 2 = 3',
        '5 plus 6 = 11'
      ]));
    });

    test('No intermediate values are produced when using MutableCell.batch and StoreCells', () {
      final a = MutableCell(0);
      final b = MutableCell(0);
      final op = MutableCell('');

      final sum = (a + b).store();
      final msg = (a, b, op, sum)
          .apply((a, b, op, sum) => '$a $op $b = $sum');

      final observer = MockValueObserver();
      msg.addObserver(observer);

      MutableCell.batch(() {
        a.value = 1;
        b.value = 2;
        op.value = '+';
      });

      MutableCell.batch(() {
        a.value = 5;
        b.value = 6;
        op.value = 'plus';
      });

      expect(observer.values, equals([
        '1 + 2 = 3',
        '5 plus 6 = 11'
      ]));
    });

    test('No intermediate values are produced when using MutableCell.batch and DynamicComputeCell', () {
      final a = MutableCell(1);
      final b = MutableCell(2);
      final c = MutableCell(3);
      final select = MutableCell(true);

      final sum = ValueCell.computed(() => a() + b());
      final result = ValueCell.computed(() => select() ? c() : sum());

      final observer = MockValueObserver();
      result.addObserver(observer);

      MutableCell.batch(() {
        select.value = true;
        c.value = 10;
        a.value = 5;
      });

      MutableCell.batch(() {
        b.value = 20;
        select.value = false;
      });

      expect(observer.values, equals([10, 25]));
    });

    test('All StoreCell observers called correct number of times', () {
      final a = MutableCell(1);
      final b = MutableCell(2);
      final sum = (a + b).store();

      final c = (a + sum).store();
      final d = sum + 2.cell;

      final observerC = MockSimpleObserver();
      final observerD = MockSimpleObserver();

      c.addObserver(observerC);
      d.addObserver(observerD);

      MutableCell.batch(() {
        a.value = 2;
        b.value = 3;
      });

      MutableCell.batch(() {
        a.value = 3;
        b.value = 2;
      });

      MutableCell.batch(() {
        a.value = 10;
        b.value = 20;
      });

      verify(observerC.update(c, any)).called(3);
      verify(observerD.update(d, any)).called(3);
    });

    test('Correct values produced with StoreCell across all observer cells', () {
      final a = MutableCell(1);
      final b = MutableCell(2);
      final sum = (a + b).store();

      final c = a + sum;
      final d = sum + 2.cell;

      final observerC = MockValueObserver();
      final observerD = MockValueObserver();

      c.addObserver(observerC);
      d.addObserver(observerD);

      MutableCell.batch(() {
        a.value = 2;
        b.value = 3;
      });

      MutableCell.batch(() {
        a.value = 3;
        b.value = 2;
      });

      MutableCell.batch(() {
        a.value = 10;
        b.value = 20;
      });

      expect(observerC.values, equals([7, 8, 40]));
      expect(observerD.values, equals([7, 32]));
    });
  });

  group('Peek cell values', () {
    test('ValueCell.peek.value == ValueCell.value', () {
      final cell = MutableCell(0);
      final peek = cell.peek;

      expect(peek.value, equals(0));

      cell.value = 2;
      expect(peek.value, equals(2));
    });

    test('ValueCell.peek does not notify observers when cell value changed', () {
      final a = MutableCell(0);
      final b = MutableCell(1);

      final sum = ValueCell.computed(() => a.peek() + b());
      final observer = addObserver(sum, MockValueObserver());

      a.value = 1;
      a.value = 2;
      a.value = 3;
      b.value = 5;
      b.value = 10;
      a.value = 2;
      b.value = 13;

      expect(observer.values, equals([8, 13, 15]));
    });

    test("PeekCell's compare == if they have the same argument cell", () {
      final a = MutableCell(0);

      final p1 = a.peek;
      final p2 = a.peek;

      expect(p1 == p2, isTrue);
      expect(p1.hashCode == p2.hashCode, isTrue);
    });

    test("PeekCell's compare != if they different same argument cells", () {
      final a = MutableCell(0);
      final b = MutableCell(1);

      final p1 = a.peek;
      final p2 = b.peek;

      expect(p1 != p2, isTrue);
      expect(p1 == p1, isTrue);
    });

    test("PeekCell's manage the same set of observers", () {
      final resource = MockResource();
      final a = TestManagedCell(resource, 1);

      p() => a.peek;

      verifyNever(resource.init());

      final observer = addObserver(p(), MockSimpleObserver());
      p().removeObserver(observer);

      verify(resource.init()).called(1);
      verify(resource.dispose()).called(1);
    });

    test("Removing PeekCell observer removes correct observer", () {
      final resource = MockResource();
      final a = TestManagedCell(resource, 1);

      p() => a.peek;

      verifyNever(resource.init());

      addObserver(p(), MockSimpleObserver());
      final observer2 = MockSimpleObserver();

      p().removeObserver(observer2);

      verify(resource.init()).called(1);
      verifyNever(resource.dispose());
    });
  });

  group('Cell initialization and cleanup', () {
    test('init() not called if no observers added', () {
      final resource = MockResource();
      final cell = TestManagedCell(resource, 1);

      verifyNever(resource.init());
    });

    test('init() called once when adding first observer', () {
      final resource = MockResource();
      final cell = TestManagedCell(resource, 1);

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      cell.addObserver(observer1);
      cell.addObserver(observer2);

      verify(resource.init()).called(1);
    });

    test('dispose() not called when not all observers removed', () {
      final resource = MockResource();
      final cell = TestManagedCell(resource, 1);

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      cell.addObserver(observer1);
      cell.addObserver(observer2);

      cell.removeObserver(observer1);

      verifyNever(resource.dispose());
    });

    test('dispose() called when all observers removed', () {
      final resource = MockResource();
      final cell = TestManagedCell(resource, 1);

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      cell.addObserver(observer1);
      cell.addObserver(observer2);

      cell.removeObserver(observer1);
      cell.removeObserver(observer2);

      verify(resource.dispose()).called(1);
    });

    test('init() called again when adding new observer after all observers removed', () {
      final resource = MockResource();
      final cell = TestManagedCell(resource, 1);

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      cell.addObserver(observer1);
      cell.addObserver(observer2);

      cell.removeObserver(observer1);
      cell.removeObserver(observer2);

      cell.addObserver(observer1);

      verify(resource.init()).called(2);
    });
  });

  group('MutableComputeCell', () {
    test('MutableComputeCell.value computed on construction', () {
      final a = MutableCell(1);
      final b = MutableComputeCell(
        arguments: {a},
        compute: () => a.value + 1,
        reverseCompute: (b) {
          a.value = b - 1;
        }
      );

      expect(b.value, equals(2));
    });

    test('MutableComputeCell.value recomputed when value of argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableComputeCell(
          arguments: {a},
          compute: () => a.value + 1,
          reverseCompute: (b) {
            a.value = b - 1;
          }
      );

      final observer = MockSimpleObserver();

      b.addObserver(observer);
      a.value = 5;

      expect(b.value, equals(6));
    });

    test('MutableComputeCell.value recomputed when value of 1st argument cell changes', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a, b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      final observer = MockSimpleObserver();

      c.addObserver(observer);
      a.value = 5;

      expect(c.value, equals(8));
    });

    test('MutableComputeCell.value recomputed when value of 2nd argument cell changes', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a, b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      final observer = MockSimpleObserver();

      c.addObserver(observer);
      b.value = 9;

      expect(c.value, equals(10));
    });

    test('MutableComputeCell observers notified when value is recomputed', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a, b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      final observer = MockSimpleObserver();

      c.addObserver(observer);
      b.value = 9;
      a.value = 10;

      verify(observer.update(c, any)).called(2);
    });

    test('MutableComputeCell observer not called after it is removed', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a,b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      c.addObserver(observer1);
      c.addObserver(observer2);
      b.value = 9;

      c.removeObserver(observer1);
      a.value = 10;

      verify(observer1.update(c, any)).called(1);
      verify(observer2.update(c, any)).called(2);
    });

    test('Setting MutableComputeCell.value updates values of argument cells', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a, b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      c.value = 10;

      expect(a.value, equals(5));
      expect(b.value, equals(5));
      expect(c.value, equals(10));
    });

    test('Setting MutableComputeCell.value calls observers of MutableCell and argument cells', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a, b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      final observerA = MockSimpleObserver();
      final observerB = MockSimpleObserver();
      final observerC = MockSimpleObserver();

      a.addObserver(observerA);
      b.addObserver(observerB);
      c.addObserver(observerC);

      c.value = 10;

      verify(observerA.update(a, any)).called(1);
      verify(observerB.update(b, any)).called(1);
      verify(observerC.update(c, any)).called(1);
    });

    test('Observers of MutableComputeCell and argument cells called every time value is set', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a, b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      final observerA = MockSimpleObserver();
      final observerB = MockSimpleObserver();
      final observerC = MockSimpleObserver();

      a.addObserver(observerA);
      b.addObserver(observerB);
      c.addObserver(observerC);

      c.value = 10;
      c.value = 12;

      verify(observerA.update(a, any)).called(2);
      verify(observerB.update(b, any)).called(2);
      verify(observerC.update(c, any)).called(2);
    });

    test('Consistency of values maintained when setting MutableComputeCell.value in batch update', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a, b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      final d = MutableCell(50);
      final e = (c + d).store();

      final observerA = MockValueObserver();
      final observerB = MockValueObserver();
      final observerC = MockValueObserver();
      final observerE = MockValueObserver();

      a.addObserver(observerA);
      b.addObserver(observerB);
      c.addObserver(observerC);
      e.addObserver(observerE);

      MutableCell.batch(() {
        c.value = 10;
        d.value = 9;
      });

      expect(observerA.values, equals([5]));
      expect(observerB.values, equals([5]));
      expect(observerC.values, equals([10]));
      expect(observerE.values, equals([19]));
    });

    test('Observers notified correct number of times when setting MutableComputeCell.value in batch update', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply(
          (a, b) => a + b,
          (c) {
            final half = c / 2;

            a.value = half;
            b.value = half;
          }
      );

      final d = MutableCell(50);
      final e = (c + d).store();

      final observerA = MockSimpleObserver();
      final observerB = MockSimpleObserver();
      final observerC = MockSimpleObserver();
      final observerE = MockSimpleObserver();

      a.addObserver(observerA);
      b.addObserver(observerB);
      c.addObserver(observerC);
      e.addObserver(observerE);

      MutableCell.batch(() {
        c.value = 10;
        d.value = 9;
      });

      verify(observerA.update(a, any)).called(1);
      verify(observerB.update(b, any)).called(1);
      verify(observerC.update(c, any)).called(1);
      verify(observerE.update(e, any)).called(1);
    });

    test('All MutableComputeCell observers called correct number of times', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final sum = (a, b).mutableApply((a, b) => a + b, (sum) {
        final half = sum ~/ 2;
        a.value = half;
        b.value = half;
      });

      final c = (a + sum).store();
      final d = sum + 2.cell;

      final observerC = MockSimpleObserver();
      final observerD = MockSimpleObserver();

      c.addObserver(observerC);
      d.addObserver(observerD);

      MutableCell.batch(() {
        a.value = 2;
        b.value = 3;
      });

      MutableCell.batch(() {
        a.value = 3;
        b.value = 2;
      });

      MutableCell.batch(() {
        a.value = 10;
        b.value = 20;
      });

      verify(observerC.update(c, any)).called(3);
      verify(observerD.update(d, any)).called(3);
    });

    test('Correct values produced with MutableComputeCell across all observer cells', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final sum = (a, b).mutableApply((a, b) => a + b, (sum) {
        final half = sum ~/ 2;
        a.value = half;
        b.value = half;
      });

      final c = a + sum;
      final d = sum + 2.cell;

      final observerC = MockValueObserver();
      final observerD = MockValueObserver();

      c.addObserver(observerC);
      d.addObserver(observerD);

      MutableCell.batch(() {
        a.value = 2;
        b.value = 3;
      });

      MutableCell.batch(() {
        a.value = 3;
        b.value = 2;
      });

      MutableCell.batch(() {
        a.value = 10;
        b.value = 20;
      });

      expect(observerC.values, equals([7, 8, 40]));
      expect(observerD.values, equals([7, 32]));
    });

    test('Previous MutableComputeCell.value preserved if ValueCell.none is used', () {
      final a = MutableCell(0);
      final evens = MutableComputeCell(arguments: {a}, compute: () => a().isEven ? a() : ValueCell.none(), reverseCompute: (a) {
        a.value = a;
      });

      final observer = addObserver(evens, MockValueObserver());

      a.value = 1;
      a.value = 2;
      a.value = 3;
      a.value = 4;
      a.value = 5;

      expect(observer.values, equals([0, 2, 4]));

    });

    test('MutableComputeCell.value initialized to defaultValue if ValueCell.none is used', () {
      final a = MutableCell(1);
      final evens = MutableComputeCell(arguments: {a}, compute: () => a().isEven ? a() : ValueCell.none(10), reverseCompute: (a) {
        a.value = a;
      });

      final observer = addObserver(evens, MockValueObserver());

      a.value = 3;
      a.value = 4;
      a.value = 5;
      a.value = 6;

      expect(observer.values, equals([10, 4, 6]));
    });

    test('Exception on initialization of value reproduced on value access', () {
      final a = MutableCell(0);
      final cell = MutableComputeCell(arguments: {a}, compute: () => a() == 0 ? throw Exception() : a(), reverseCompute: (val) {
        a.value = val;
      });

      expect(() => cell.value, throwsException);
    });

    test('Exception on initialization of value reproduced on value access while observed', () {
      final a = MutableCell(0);
      final cell = MutableComputeCell(arguments: {a}, compute: () => a() == 0 ? throw Exception() : a(), reverseCompute: (val) {
        a.value = val;
      });

      observeCell(cell);
      expect(() => cell.value, throwsException);
    });
  });

  group('DynamicMutableComputeCell', () {
    test('DynamicMutableComputeCell.value computed on construction', () {
      final a = MutableCell(1);
      final b = MutableCell.computed(() => a() + 1, (b) {
        a.value = b - 1;
      });

      expect(b.value, equals(2));
    });

    test('DynamicMutableComputeCell.value recomputed when value of argument cell changes', () {
      final a = MutableCell(1);
      final b = MutableCell.computed(() => a() + 1, (b) {
        a.value = b - 1;
      });

      final observer = MockSimpleObserver();

      b.addObserver(observer);
      a.value = 5;

      expect(b.value, equals(6));
    });

    test('DynamicMutableComputeCell.value recomputed when value of 1st argument cell changes', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      final observer = MockSimpleObserver();

      c.addObserver(observer);
      a.value = 5;

      expect(c.value, equals(8));
    });

    test('DynamicMutableComputeCell.value recomputed when value of 2nd argument cell changes', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      final observer = MockSimpleObserver();

      c.addObserver(observer);
      b.value = 9;

      expect(c.value, equals(10));
    });

    test('DynamicMutableComputeCell observers notified when value is recomputed', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      final observer = MockSimpleObserver();

      c.addObserver(observer);
      b.value = 9;
      a.value = 10;

      verify(observer.update(c, any)).called(2);
    });

    test('DynamicMutableComputeCell observer not called after it is removed', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      final observer1 = MockSimpleObserver();
      final observer2 = MockSimpleObserver();

      c.addObserver(observer1);
      c.addObserver(observer2);
      b.value = 9;

      c.removeObserver(observer1);
      a.value = 10;

      verify(observer1.update(c, any)).called(1);
      verify(observer2.update(c, any)).called(2);
    });

    test('Setting DynamicMutableComputeCell.value updates values of argument cells', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      c.value = 10;

      expect(a.value, equals(5));
      expect(b.value, equals(5));
      expect(c.value, equals(10));
    });

    test('Setting DynamicMutableComputeCell.value calls observers of MutableCell and argument cells', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      final observerA = MockSimpleObserver();
      final observerB = MockSimpleObserver();
      final observerC = MockSimpleObserver();

      a.addObserver(observerA);
      b.addObserver(observerB);
      c.addObserver(observerC);

      c.value = 10;

      verify(observerA.update(a, any)).called(1);
      verify(observerB.update(b, any)).called(1);
      verify(observerC.update(c, any)).called(1);
    });

    test('Observers of DynamicMutableComputeCell and argument cells called every time value is set', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      final observerA = MockSimpleObserver();
      final observerB = MockSimpleObserver();
      final observerC = MockSimpleObserver();

      a.addObserver(observerA);
      b.addObserver(observerB);
      c.addObserver(observerC);

      c.value = 10;
      c.value = 12;

      verify(observerA.update(a, any)).called(2);
      verify(observerB.update(b, any)).called(2);
      verify(observerC.update(c, any)).called(2);
    });

    test('Consistency of values maintained when setting DynamicMutableComputeCell.value in batch update', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      final d = MutableCell(50);
      final e = ValueCell.computed(() => c() + d());

      final observerA = MockValueObserver();
      final observerB = MockValueObserver();
      final observerC = MockValueObserver();
      final observerE = MockValueObserver();

      a.addObserver(observerA);
      b.addObserver(observerB);
      c.addObserver(observerC);
      e.addObserver(observerE);

      MutableCell.batch(() {
        c.value = 10;
        d.value = 9;
      });

      expect(observerA.values, equals([5]));
      expect(observerB.values, equals([5]));
      expect(observerC.values, equals([10]));
      expect(observerE.values, equals([19]));
    });

    test('Observers notified correct number of times when setting DynamicMutableComputeCell.value in batch update', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = MutableCell.computed(() => a() + b(), (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      });

      final d = MutableCell(50);
      final e = ValueCell.computed(() => c() + d());

      final observerA = MockSimpleObserver();
      final observerB = MockSimpleObserver();
      final observerC = MockSimpleObserver();
      final observerE = MockSimpleObserver();

      a.addObserver(observerA);
      b.addObserver(observerB);
      c.addObserver(observerC);
      e.addObserver(observerE);

      MutableCell.batch(() {
        c.value = 10;
        d.value = 9;
      });

      verify(observerA.update(a, any)).called(1);
      verify(observerB.update(b, any)).called(1);
      verify(observerC.update(c, any)).called(1);
      verify(observerE.update(e, any)).called(1);
    });

    test('All DynamicMutableComputeCell observers called correct number of times', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final sum = MutableCell.computed(() => a() + b(), (sum) {
        final half = sum ~/ 2;
        a.value = half;
        b.value = half;
      });

      final c = (a + sum).store();
      final d = sum + 2.cell;

      final observerC = MockSimpleObserver();
      final observerD = MockSimpleObserver();

      c.addObserver(observerC);
      d.addObserver(observerD);

      MutableCell.batch(() {
        a.value = 2;
        b.value = 3;
      });

      MutableCell.batch(() {
        a.value = 3;
        b.value = 2;
      });

      MutableCell.batch(() {
        a.value = 10;
        b.value = 20;
      });

      verify(observerC.update(c, any)).called(3);
      verify(observerD.update(d, any)).called(3);
    });

    test('Correct values produced with DynamicMutableComputeCell across all observer cells', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final sum = MutableCell.computed(() => a() + b(), (sum) {
        final half = sum ~/ 2;
        a.value = half;
        b.value = half;
      });

      final c = ValueCell.computed(() => a() + sum());
      final d = ValueCell.computed(() => sum() + 2);

      final observerC = MockValueObserver();
      final observerD = MockValueObserver();

      c.addObserver(observerC);
      d.addObserver(observerD);

      MutableCell.batch(() {
        a.value = 2;
        b.value = 3;
      });

      MutableCell.batch(() {
        a.value = 3;
        b.value = 2;
      });

      MutableCell.batch(() {
        a.value = 10;
        b.value = 20;
      });

      expect(observerC.values, equals([7, 8, 40]));
      expect(observerD.values, equals([7, 32]));
    });

    test('DynamicMutableComputeCell arguments tracked correctly when using conditionals', () {
      final a = MutableCell(true);
      final b = MutableCell(2);
      final c = MutableCell(3);

      final d = MutableCell.computed(() => a() ? b() : c(), (d) {
        a.value = true;
        b.value = d;
        c.value = d;
      });

      final observer = MockValueObserver();
      d.addObserver(observer);

      b.value = 1;
      a.value = false;
      c.value = 10;

      expect(observer.values, equals([1, 3, 10]));
    });

    test('DynamicMutableComputeCell arguments tracked correctly when argument is a DynamicComputeCell', () {
      final a = MutableCell(true);
      final b = MutableCell(2);
      final c = MutableCell(3);

      final d = MutableCell.computed(() => a() ? b() : c(), (d) {
        a.value = true;
        b.value = d;
        c.value = d;
      });

      final e = MutableCell(0);

      final f = MutableCell.computed(() => d() + e(), (f) {
        final half = f ~/ 2;

        d.value = half;
        e.value = half;
      });

      final observer = MockValueObserver();
      f.addObserver(observer);

      b.value = 1;
      e.value = 10;
      a.value = false;
      c.value = 10;

      expect(observer.values, equals([1, 11, 13, 20]));
    });

    test('No intermediate values are produced when using DynamicMutableComputeCell and branches are unequal', () {
      final a = MutableCell(0);

      final sum1 = MutableCell.computed(() => a() + 1, (v) {
        // Reverse computation not necessary for this test
      });
      final sum = MutableCell.computed(() => sum1() + 10, (v) {
        // Reverse computation not necessary for this test
      });

      final prod = MutableCell.computed(() => a() * 8, (v) {
        // Reverse computation not necessary for this test
      });
      final result = MutableCell.computed(() => sum() + prod(), (v) {
        // Reverse computation not necessary for this test
      });

      final observer = MockValueObserver();
      result.addObserver(observer);

      a.value = 2;
      a.value = 6;

      expect(observer.values, equals([(2 + 1 + 10) + (2 * 8), (6 + 1 + 10) + (6 * 8)]));
    });

    test('No intermediate values are produced when using MutableCell.batch and DynamicMutableComputeCell', () {
      final a = MutableCell(1);
      final b = MutableCell(2);
      final c = MutableCell(3);
      final select = MutableCell(true);

      final sum = MutableCell.computed(() => a() + b(), (v) {
        // Reverse computation not necessary for this test
      });
      final result = MutableCell.computed(() => select() ? c() : sum(), (v) {
        // Reverse computation not necessary for this test
      });

      final observer = MockValueObserver();
      result.addObserver(observer);

      MutableCell.batch(() {
        select.value = true;
        c.value = 10;
        a.value = 5;
      });

      MutableCell.batch(() {
        b.value = 20;
        select.value = false;
      });

      expect(observer.values, equals([10, 25]));
    });

    test('Previous DynamicMutableComputeCell.value preserved if ValueCell.none is used', () {
      final a = MutableCell(0);
      final evens = MutableCell.computed(() => a().isEven ? a() : ValueCell.none(), (a) {
        a.value = a;
      });

      final observer = addObserver(evens, MockValueObserver());

      a.value = 1;
      a.value = 2;
      a.value = 3;
      a.value = 4;
      a.value = 5;

      expect(observer.values, equals([0, 2, 4]));
    });

    test('DynamicMutableComputeCell.value initialized to defaultValue if ValueCell.none is used', () {
      final a = MutableCell(1);
      final evens = MutableCell.computed(() => a().isEven ? a() : ValueCell.none(20), (a) {
        a.value = a;
      });

      final observer = addObserver(evens, MockValueObserver());

      a.value = 3;
      a.value = 4;
      a.value = 5;
      a.value = 6;

      expect(observer.values, equals([20, 4, 6]));
    });

    test('Exception on initialization of value reproduced on value access', () {
      final a = MutableCell(0);
      final cell = MutableCell.computed(() => a() == 0 ? throw Exception() : a(), (val) {
        a.value = val;
      });

      expect(() => cell.value, throwsException);
    });

    test('Exception on initialization of value reproduced on value access while observed', () {
      final a = MutableCell(0);
      final cell = MutableCell.computed(() => a() == 0 ? throw Exception() : a(), (val) {
        a.value = val;
      });

      observeCell(cell);
      expect(() => cell.value, throwsException);
    });
  });

  group('MutableCellView', () {
    test('MutableCellView.value computed on construction', () {
      final a = MutableCell(1);
      final b = a.mutableApply((a) => a + 1, (b) => a.value = b - 1);

      expect(b.value, equals(2));
    });

    test('MutableCellView.value recomputed when value of argument cell changes', () {
      final a = MutableCell(1);
      final b = a.mutableApply((a) => a + 1, (b) => a.value = b - 1);

      observeCell(b);
      a.value = 5;

      expect(b.value, equals(6));
    });

    test('MutableCellView.value recomputed when value of 1st argument cell changes', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      a.value = 5;

      expect(c.value, equals(8));
    });

    test('MutableCellView.value recomputed when value of 2nd argument cell changes', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      b.value = 9;

      expect(c.value, equals(10));
    });

    test('MutableCellView observers notified when value is recomputed', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      final observer = addObserver(c, MockSimpleObserver());

      a.value = 6;
      b.value = 10;

      verify(observer.update(c, any)).called(2);
    });

    test('MutableCellView observer not called after it is removed', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      final observer1 = addObserver(c, MockSimpleObserver());
      final observer2 = addObserver(c, MockSimpleObserver());

      b.value = 9;

      c.removeObserver(observer1);
      a.value = 10;

      verify(observer1.update(c, any)).called(1);
      verify(observer2.update(c, any)).called(2);
    });

    test('Setting MutableCellView.value updates values of argument cell', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      c.value = 10;

      expect(a.value, equals(5));
      expect(b.value, equals(5));
      expect(c.value, equals(10));
    });

    test('Setting MutableCellView.value calls observers of MutableCell and argument cells', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      final observerA = addListener(a, MockSimpleListener());
      final observerB = addListener(b, MockSimpleListener());
      final observerC = addListener(c, MockSimpleListener());

      c.value = 10;

      verify(observerA()).called(1);
      verify(observerB()).called(1);
      verify(observerC()).called(1);
    });

    test('Observers of MutableCellView and argument cells called every time value is set', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      final observerA = addListener(a, MockSimpleListener());
      final observerB = addListener(b, MockSimpleListener());
      final observerC = addListener(c, MockSimpleListener());

      c.value = 10;
      c.value = 12;

      verify(observerA()).called(2);
      verify(observerB()).called(2);
      verify(observerC()).called(2);
    });

    test('Consistency of values maintained when setting MutableCellView.value in batch update', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      final d = MutableCell(50);
      final e = ValueCell.computed(() => c() + d());

      final observerA = addObserver(a, MockValueObserver());
      final observerB = addObserver(b, MockValueObserver());
      final observerC = addObserver(c, MockValueObserver());
      final observerE = addObserver(e, MockValueObserver());

      MutableCell.batch(() {
        c.value = 10;
        d.value = 9;
      });

      expect(observerA.values, equals([5]));
      expect(observerB.values, equals([5]));
      expect(observerC.values, equals([10]));
      expect(observerE.values, equals([19]));
    });

    test('Observers notified correct number of times when setting MutableCellView.value in batch update', () {
      final a = MutableCell(1.0);
      final b = MutableCell(3.0);

      final c = (a, b).mutableApply((a, b) => a + b, (c) {
        final half = c / 2;

        a.value = half;
        b.value = half;
      }, key: 'key'); // A non-null key to create a MutableCellView

      final d = MutableCell(50);
      final e = ValueCell.computed(() => c() + d());

      final observerA = addListener(a, MockSimpleListener());
      final observerB = addListener(b, MockSimpleListener());
      final observerC = addListener(c, MockSimpleListener());
      final observerE = addListener(e, MockSimpleListener());

      MutableCell.batch(() {
        c.value = 10;
        d.value = 9;
      });

      verify(observerA()).called(1);
      verify(observerB()).called(1);
      verify(observerC()).called(1);
      verify(observerE()).called(1);
    });

    test('All MutableCellView observers called correct number of times', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final sum = (a, b).mutableApply((a, b) => a + b, (sum) {
        final half = sum ~/ 2;
        a.value = half;
        b.value = half;
      }, key: 'A key'); // A non-null key to create a MutableCellView

      final c = (a + sum).store();
      final d = sum + 2.cell;

      final observerC = addListener(c, MockSimpleListener());
      final observerD = addListener(d, MockSimpleListener());

      MutableCell.batch(() {
        a.value = 2;
        b.value = 3;
      });

      MutableCell.batch(() {
        a.value = 3;
        b.value = 2;
      });

      MutableCell.batch(() {
        a.value = 10;
        b.value = 20;
      });

      verify(observerC()).called(3);
      verify(observerD()).called(3);
    });

    test('Correct values produced with MutableCellView across all observer cells', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final sum = (a, b).mutableApply((a, b) => a + b, (sum) {
        final half = sum ~/ 2;
        a.value = half;
        b.value = half;
      }, key: 'A key'); // A non-null key to create a MutableCellView

      final c = ValueCell.computed(() => a() + sum());
      final d = ValueCell.computed(() => sum() + 2);

      final observerC = addObserver(c, MockValueObserver());
      final observerD = addObserver(d, MockValueObserver());

      MutableCell.batch(() {
        a.value = 2;
        b.value = 3;
      });

      MutableCell.batch(() {
        a.value = 3;
        b.value = 2;
      });

      MutableCell.batch(() {
        a.value = 10;
        b.value = 20;
      });

      expect(observerC.values, equals([7, 8, 40]));
      expect(observerD.values, equals([7, 32]));
    });

    test('Exception on initialization of value reproduced on value access', () {
      final a = MutableCell(0);
      final cell = a.mutableApply((a) => a == 0 ? throw Exception() : a, (v) => a.value = v);

      expect(() => cell.value, throwsException);
    });

    test('Exception on initialization of value reproduced on value access while observed', () {
      final a = MutableCell(0);
      final cell = a.mutableApply((a) => a == 0 ? throw Exception() : a, (v) => a.value = v);

      observeCell(cell);
      expect(() => cell.value, throwsException);
    });

    test("MutableCellView's compare == if they have the same keys", () {
      final a = MutableCell(0);

      final b1 = a.mutableApply((a) => a + 1, (v) => v - 1, key: 'theKey');
      final b2 = a.mutableApply((a) => a + 1, (v) => v - 1, key: 'theKey');

      expect(b1 == b2, isTrue);
      expect(b1.hashCode == b2.hashCode, isTrue);
    });

    test("MutableCellView's compare != if they have different keys", () {
      final a = MutableCell(0);

      final b1 = a.mutableApply((a) => a + 1, (v) => v - 1, key: 'theKey');
      final b2 = a.mutableApply((a) => a + 1, (v) => v - 1, key: 'theKey1');

      expect(b1 != b2, isTrue);
    });

    test("MutableCellView's compare != if they have null keys", () {
      final a = MutableCell(0);

      final b1 = a.mutableApply((a) => a + 1, (v) => v - 1);
      final b2 = a.mutableApply((a) => a + 1, (v) => v - 1);

      expect(b1 != b2, isTrue);
      expect(b1 == b1, isTrue);
    });
  });

  group('Type Conversions', () {
    test('ParseIntExtension.mutableString() converts argument cell to string', () {
      final a = MutableCell(1);
      final strA = a.mutableString();

      final observer = MockSimpleObserver();
      strA.addObserver(observer);

      a.value = 5;

      expect(strA.value, equals('5'));
    });

    test('ParseIntExtension.mutableString() sets argument cell to parsed integer', () {
      final a = MutableCell(1);
      final strA = a.mutableString();

      final observer = MockSimpleObserver();
      strA.addObserver(observer);

      strA.value = '32';

      expect(a.value, equals(32));
    });

    test('ParseIntExtension.mutableString() sets cell to errorValue on errors during parsing integer', () {
      final a = MutableCell(1);

      final strA = a.mutableString(
          errorValue: 7.cell
      );

      strA.value = '25';
      expect(a.value, equals(25));

      strA.value = '12djdjdjdj';
      expect(a.value, equals(7));

      strA.value = '16';
      expect(a.value, equals(16));
    });

    test('ParseMaybeIntExtension.mutableString() forwards errors to argument cell', () {
      final a = MutableCell(1);
      final maybe = a.maybe();
      final error = maybe.error;

      final strA = maybe.mutableString();

      strA.value = '25';

      expect(a.value, equals(25));
      expect(error.value, isNull);

      strA.value = '12djdjdjdj';

      expect(a.value, equals(25));
      expect(error.value, isNotNull);

      strA.value = '16';

      expect(a.value, equals(16));
      expect(error.value, isNull);
    });

    test('ParseDoubleExtension.mutableString() converts argument cell to string', () {
      final a = MutableCell(1.0);
      final strA = a.mutableString();

      final observer = MockSimpleObserver();
      strA.addObserver(observer);

      a.value = 7.5;

      expect(strA.value, equals('7.5'));
    });

    test('ParseDoubleExtension.mutableString() sets argument cell to parsed double', () {
      final a = MutableCell(1.0);
      final strA = a.mutableString();

      final observer = MockSimpleObserver();
      strA.addObserver(observer);

      strA.value = '3.5';

      expect(a.value, equals(3.5));
    });

    test('ParseDoubleExtension.mutableString() sets cell to errorValue on errors during parsing double', () {
      final a = MutableCell(1.0);

      final strA = a.mutableString(
          errorValue: 2.5.cell
      );

      strA.value = '7.5';
      expect(a.value, equals(7.5));

      strA.value = '3.4djdjdjdj';
      expect(a.value, equals(2.5));

      strA.value = '9.0';
      expect(a.value, equals(9.0));
    });

    test('ParseMaybeDoubleExtension.mutableString() forwards errors to argument cell', () {
      final a = MutableCell(1.0);
      final maybe = a.maybe();
      final error = maybe.error;

      final strA = maybe.mutableString();

      strA.value = '7.5';

      expect(a.value, equals(7.5));
      expect(error.value, isNull);

      strA.value = '3.4djdjdjdj';

      expect(a.value, equals(7.5));
      expect(error.value, isNotNull);

      strA.value = '9.0';

      expect(a.value, equals(9.0));
      expect(error.value, isNull);
    });

    test('ParseNumExtension.mutableString() converts argument cell to string', () {
      final a = MutableCell<num>(1);
      final strA = a.mutableString();

      final observer = MockValueObserver();
      strA.addObserver(observer);

      a.value = 7.5;
      a.value = 3;

      expect(observer.values, equals(['7.5', '3']));
    });

    test('ParseNumExtension.mutableString() sets argument cell to parsed num', () {
      final a = MutableCell<num>(1);
      final strA = a.mutableString();

      final observer = MockValueObserver();
      a.addObserver(observer);

      strA.value = '3.5';
      strA.value = '100';

      expect(observer.values, equals([3.5, 100]));
    });

    test('ParseNumExtension.mutableString() sets cell to errorValue on errors during parsing num', () {
      final a = MutableCell<num>(0);

      final strA = a.mutableString(
          errorValue: 8.cell
      );

      strA.value = '7.5';
      expect(a.value, equals(7.5));

      strA.value = '3.4djdjdjdj';
      expect(a.value, equals(8));

      strA.value = '5';
      expect(a.value, equals(5));

    });

    test('ParseNumExtension.mutableString() forwards errors to argument cell', () {
      final a = MutableCell<num>(0);
      final maybe = a.maybe();
      final error = maybe.error;

      final strA = maybe.mutableString();

      strA.value = '7.5';

      expect(a.value, equals(7.5));
      expect(error.value, isNull);

      strA.value = '3.4djdjdjdj';

      expect(a.value, equals(7.5));
      expect(error.value, isNotNull);

      strA.value = '5';

      expect(a.value, equals(5));
      expect(error.value, isNull);
    });

    test('ConvertStringExtension.mutableString() converts argument cell to string', () {
      final a = MutableCell('');
      final strA = a.mutableString();

      final observer = MockSimpleObserver();
      strA.addObserver(observer);

      a.value = 'hello';

      expect(strA.value, equals('hello'));
    });

    test('ConvertStringExtension.mutableString() simply sets argument cell value', () {
      final a = MutableCell('');
      final strA = a.mutableString();

      final observer = MockSimpleObserver();
      strA.addObserver(observer);

      strA.value = '3.5';

      expect(a.value, equals('3.5'));
    });
  });

  group('Duration extensions', () {
    test('Duration properties are accessed correctly on ValueCell', () {
      const duration = Duration(
          days: 24,
          hours: 10,
          minutes: 23,
          seconds: 47,
          milliseconds: 100,
          microseconds: 500
      );

      final cell = duration.cell;
      final days = cell.inDays;
      final hours = cell.inHours;
      final minutes = cell.inMinutes;
      final seconds = cell.inSeconds;
      final milliseconds = cell.inMilliseconds;
      final microseconds = cell.inMicroseconds;

      expect(cell.value, equals(duration));
      expect(days.value, equals(duration.inDays));
      expect(hours.value, equals(duration.inHours));
      expect(minutes.value, equals(duration.inMinutes));
      expect(seconds.value, equals(duration.inSeconds));
      expect(milliseconds.value, equals(duration.inMilliseconds));
      expect(microseconds.value, equals(duration.inMicroseconds));
    });

    test('Duration properties are accessed correctly on MutableCell', () {
      const duration = Duration(days: 24);
      final cell = MutableCell(Duration.zero);

      cell.value = duration;

      final days = cell.inDays;
      final hours = cell.inHours;
      final minutes = cell.inMinutes;
      final seconds = cell.inSeconds;
      final milliseconds = cell.inMilliseconds;
      final microseconds = cell.inMicroseconds;

      expect(cell.value, equals(duration));
      expect(days.value, equals(duration.inDays));
      expect(hours.value, equals(duration.inHours));
      expect(minutes.value, equals(duration.inMinutes));
      expect(seconds.value, equals(duration.inSeconds));
      expect(milliseconds.value, equals(duration.inMilliseconds));
      expect(microseconds.value, equals(duration.inMicroseconds));
    });

    test('Setting MutableCell Duration properties updates Duration stored in cell', () {
      final cell = MutableCell(Duration.zero);

      final days = cell.inDays;
      final hours = cell.inHours;
      final minutes = cell.inMinutes;
      final seconds = cell.inSeconds;
      final milliseconds = cell.inMilliseconds;
      final microseconds = cell.inMicroseconds;

      days.value = 30;
      expect(cell.value, equals(const Duration(days: 30)));

      hours.value = 45;
      expect(cell.value, equals(const Duration(hours: 45)));

      minutes.value = 23;
      expect(cell.value, equals(const Duration(minutes: 23)));

      seconds.value = 45;
      expect(cell.value, equals(const Duration(seconds: 45)));

      milliseconds.value = 398;
      expect(cell.value, equals(const Duration(milliseconds: 398)));

      microseconds.value = 1204;
      expect(cell.value, equals(const Duration(microseconds: 1204)));
    });

    test('Arithmetic involving Duration cells', () {
      final a = const Duration(hours: 5).cell;
      final delta = const Duration(hours: 10, minutes: 30).cell;

      final sum = a + delta;
      final diff = a - delta;
      final prod = delta * 2.cell;
      final div = delta ~/ 2.cell;
      final neg = -a;

      expect(sum.value, equals(const Duration(hours: 15, minutes: 30)));
      expect(diff.value, equals(const Duration(hours: -5, minutes: -30)));
      expect(prod.value, equals(const Duration(hours: 21)));
      expect(div.value, equals(const Duration(hours: 5, minutes: 15)));
      expect(neg.value, equals(const Duration(hours: -5)));
    });

    test('Comparison of Duration cells', () {
      final a = const Duration(hours: 5).cell;
      final b = const Duration(hours: 10, minutes: 30).cell;

      expect((a < b).value, isTrue);
      expect((b < a).value, isFalse);

      expect((a > b).value, isFalse);
      expect((b > a).value, isTrue);

      expect((a <= b).value, isTrue);
      expect((a <= a).value, isTrue);
      expect((b <= a).value, isFalse);

      expect((a >= b).value, isFalse);
      expect((a >= a).value, isTrue);
      expect((b >= a).value, isTrue);
    });

    test('isNegative property of Duration cells', () {
      final a = const Duration(hours: 1, minutes: 20).cell;

      expect(a.isNegative.value, isFalse);
      expect((-a).isNegative.value, isTrue);
    });

    test('abs() method of Duration cells', () {
      final a = const Duration(hours: 5).cell;
      final b = const Duration(hours: -5).cell;

      expect(a.abs().value, equals(const Duration(hours: 5)));
      expect(b.abs().value, equals(const Duration(hours: 5)));
    });
  });

  group('DelayCell', () {
    test('DelayCell.value equals initial value of cell when not changed', () {
      final cell = MutableCell(2);
      final delay = DelayCell(const Duration(milliseconds: 1), cell);

      expect(delay.value, equals(2));
    });

    test('DelayCell takes latest value of argument cell', () {
      final cell = MutableCell(10);
      final delay = DelayCell(const Duration(milliseconds: 1), cell);

      final observer = MockSimpleObserver();
      cell.value = 20;

      delay.addObserver(observer);

      expect(delay.value, equals(20));
    });

    test('DelayCell.value is updated after setting argument cell value', () async {
      final cell = MutableCell(1);
      final delay = DelayCell(const Duration(milliseconds: 1), cell);

      final observer = MockValueObserver();
      delay.addObserver(observer);

      cell.value = 2;

      await untilCalled(observer.gotValue(2)).timeout(const Duration(seconds: 1), onTimeout: () {
        fail('DelayCell.value not updated');
      });
    });

    test('DelayCell.value observers called for every argument cell value change', () async {
      final cell = MutableCell(1);
      final delay = DelayCell(const Duration(milliseconds: 1), cell);

      final observer = MockValueObserver();
      delay.addObserver(observer);

      cell.value = 2;
      cell.value = 5;

      await untilCalled(observer.gotValue(5)).timeout(const Duration(seconds: 2), onTimeout: () {
        fail('DelayCell.value not updated');
      });

      verify(observer.gotValue(any)).called(2);
    });

    test('DelayCell.value observer not called after it is removed', () async {
      final cell = MutableCell(1);
      final delay = DelayCell(const Duration(milliseconds: 1), cell);

      final observer1 = MockValueObserver();
      final observer2 = MockValueObserver();

      delay.addObserver(observer1);
      delay.addObserver(observer2);

      cell.value = 2;

      await untilCalled(observer1.gotValue(2)).timeout(const Duration(seconds: 2), onTimeout: () {
        fail('DelayCell.value not updated');
      });

      await untilCalled(observer2.gotValue(2)).timeout(const Duration(seconds: 2), onTimeout: () {
        fail('DelayCell.value not updated');
      });

      delay.removeObserver(observer1);
      cell.value = 5;

      await untilCalled(observer2.gotValue(5)).timeout(const Duration(seconds: 2), onTimeout: () {
        fail('DelayCell.value not updated');
      });

      verify(observer1.gotValue(any)).called(1);
      verify(observer2.gotValue(any)).called(2);
    });
  });

  group('Cell watcher', () {
    test('Watch function called once on registration', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final observer = MockValueObserver();

      final watcher = ValueCell.watch(() {
        observer.gotValue(a() + b());
      });

      addTearDown(() => watcher.stop());

      verify(observer.gotValue(any)).called(1);
    });

    test('Watch function called with correct cell values on registration', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final observer = MockValueObserver();

      final watcher = ValueCell.watch(() {
        observer.gotValue(a() + b());
      });

      addTearDown(() => watcher.stop());

      verify(observer.gotValue(3)).called(1);
    });

    test('Watch function called when referenced cell values change', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final observer = MockValueObserver();

      final watcher = ValueCell.watch(() {
        observer.gotValue(a() + b());
      });

      addTearDown(() => watcher.stop());

      a.value = 5;
      b.value = 10;

      verify(observer.gotValue(any)).called(3);
    });

    test('Cell values updated when function is called', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final observer = MockValueObserver();

      final watcher = ValueCell.watch(() {
        observer.gotValue(a() + b());
      });

      addTearDown(() => watcher.stop());

      a.value = 5;
      b.value = 10;

      verifyInOrder([
        observer.gotValue(3),
        observer.gotValue(7),
        observer.gotValue(15)
      ]);
    });

    test('Watch function called when referenced cell values change during batch update', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final observer = MockValueObserver();

      final watcher = ValueCell.watch(() {
        observer.gotValue(a() + b());
      });

      addTearDown(() => watcher.stop());

      MutableCell.batch(() {
        a.value = 5;
        b.value = 10;
      });

      verify(observer.gotValue(any)).called(2);
    });

    test('Cell values updated when function is called during batch update', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final observer = MockValueObserver();

      final watcher = ValueCell.watch(() {
        observer.gotValue(a() + b());
      });

      addTearDown(() => watcher.stop());

      MutableCell.batch(() {
        a.value = 5;
        b.value = 10;
      });

      verifyInOrder([
        observer.gotValue(3),
        observer.gotValue(15)
      ]);
    });

    test('Watch function called when cell value changes in conditional expression', () {
      final a = MutableCell(1);
      final b = MutableCell(2);
      final select = MutableCell(true);

      final observer = MockValueObserver();

      final watcher = ValueCell.watch(() {
        if (select()) {
          observer.gotValue(a());
        }
        else {
          observer.gotValue(b());
        }
      });

      addTearDown(() => watcher.stop());

      a.value = 2;
      select.value = false;
      b.value = 5;

      verify(observer.gotValue(any)).called(4);
    });

    test('Watch function not called after CellWatcher.stop()', () {
      final a = MutableCell(1);
      final b = MutableCell(2);

      final observer = MockValueObserver();

      final watcher = ValueCell.watch(() {
        observer.gotValue(a() + b());
      });

      addTearDown(() => watcher.stop());

      a.value = 5;
      b.value = 10;
      watcher.stop();

      b.value = 100;
      a.value = 30;

      verify(observer.gotValue(any)).called(3);
    });

    test('init() called when cell is watched', () {
      final resource = MockResource();
      final cell = TestManagedCell(resource, 1);

      final watcher = ValueCell.watch(() {
        cell();
      });

      addTearDown(() => watcher.stop());

      verify(resource.init()).called(1);
    });

    test('dispose() called after CellWatcher.stop', () {
      final resource = MockResource();
      final cell = TestManagedCell(resource, 1);

      final watcher = ValueCell.watch(() {
        cell() + cell();
      });

      watcher.stop();
      verify(resource.dispose()).called(1);
    });

    test('dispose() not called when not all watchers are stopped', () {
      final resource = MockResource();
      final cell = TestManagedCell(resource, 1);

      final watcher1 = ValueCell.watch(() {
        cell() + cell();
      });

      final watcher2 = ValueCell.watch(() {
        cell() * cell();
      });

      addTearDown(() {
        watcher1.stop();
        watcher2.stop();
      });

      watcher1.stop();
      verifyNever(resource.dispose());
    });
  });

  group('changesOnly cell option', () {
    test('Observer.update() called with didChange = false, when value unchanged.', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final observer = MockSimpleObserver();
      addObserver(b, observer);

      a.value = [4, 2, 6];
      verify(observer.willUpdate(b)).called(1);
      verify(observer.update(b, false)).called(1);
      verifyNoMoreInteractions(observer);
    });

    test('Observer.update() called with didChange = true, when value changed.', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final observer = MockSimpleObserver();
      addObserver(b, observer);

      a.value = [7, 8, 9];
      verify(observer.willUpdate(b)).called(1);
      verify(observer.update(b, any)).called(1);
    });

    test('Watch function not called when didChange is false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final listener = addListener(b, MockSimpleListener());
      a.value = [4, 2, 6];

      verifyNever(listener());
    });

    test('Watch function not called when didChange is false in MutableCell.batch', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final listener = addListener(b, MockSimpleListener());

      MutableCell.batch(() {
        a.value = [4, 2, 6];
      });

      verifyNever(listener());
    });

    test('Watch function called when didChange is true after returning false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final listener = addListener(b, MockSimpleListener());

      a.value = [4, 2, 6];
      a.value = [7, 8, 9];

      verify(listener()).called(1);
    });

    test('Watch function called when didChange is true for at least one argument', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final c = MutableCell(3);

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        b();
        c();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
        c.value = 5;
      });

      verify(listener()).called(2);
    });

    test('Computed cell not recomputed when didChange is false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = ValueCell.computed(() => b() * 10);

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];

      verify(listener()).called(1);
    });

    test('Computed cell not recomputed when didChange is false in MutableCell.batch', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = ValueCell.computed(() => b() * 10);

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
      });

      verify(listener()).called(1);
    });

    test('Computed cell recomputed when didChange is true after returning false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = ValueCell.computed(() => b() * 10);

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];
      a.value = [7, 8, 9];

      verify(listener()).called(2);
    });

    test('Computed cell recomputed when didChange is true for at least one argument', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final c = MutableCell(3);
      final d = ValueCell.computed(() => b() * c());

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        d();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
        c.value = 5;
      });

      verify(listener()).called(2);
    });

    test('StoreCell not recomputed when didChange is false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = (b * 10.cell).store();

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];

      verify(listener()).called(1);
    });

    test('StoreCell not recomputed when didChange is false in MutableCell.batch', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = (b * 10.cell).store();

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
      });

      verify(listener()).called(1);
    });

    test('StoreCell recomputed when didChange is true after returning false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = (b * 10.cell).store();

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];
      a.value = [7, 8, 9];

      verify(listener()).called(2);
    });

    test('StoreCell recomputed when didChange is true for at least one argument', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final c = MutableCell(3);
      final d = (b * c).store();

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        d();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
        c.value = 5;
      });

      verify(listener()).called(2);
    });

    test('MutableComputeCell not recomputed when didChange is false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = (b, 10.cell).mutableApply((a1, a2) => a1 * a2, (_) {});

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];

      verify(listener()).called(1);
    });

    test('MutableComputeCell not recomputed when didChange is false in MutableCell.batch', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = (b, 10.cell).mutableApply((a1, a2) => a1 * a2, (_) {});

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
      });

      verify(listener()).called(1);
    });

    test('MutableComputeCell recomputed when didChange is true after returning false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = (b, 10.cell).mutableApply((a1, a2) => a1 * a2, (_) {});

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];
      a.value = [7, 8, 9];

      verify(listener()).called(2);
    });

    test('MutableComputeCell recomputed when didChange is true for at least one argument', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final c = MutableCell(3);
      final d = (b, c).mutableApply((b, c) => b * c, (_) {});

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        d();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
        c.value = 5;
      });

      verify(listener()).called(2);
    });

    test('DynamicMutableComputeCell not recomputed when didChange is false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = MutableCell.computed(() => b() * 10, (_) { });

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];

      verify(listener()).called(1);
    });

    test('DynamicMutableComputeCell not recomputed when didChange is false in MutableCell.batch', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = MutableCell.computed(() => b() * 10, (_) { });

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
      });

      verify(listener()).called(1);
    });

    test('DynamicMutableComputeCell recomputed when didChange is true after returning false', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final c = MutableCell.computed(() => b() * 10, (_) { });

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        c();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];
      a.value = [7, 8, 9];

      verify(listener()).called(2);
    });

    test('DynamicMutableComputeCell recomputed when didChange is true for at least one argument', () {
      final a = MutableCell([1, 2, 3]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);

      final c = MutableCell(3);
      final d = MutableCell.computed(() => b() * c(), (_) { });

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        d();
        listener();
      });

      addTearDown(watcher.stop);

      MutableCell.batch(() {
        a.value = [4, 2, 6];
        c.value = 5;
      });

      verify(listener()).called(2);
    });

    test('MutableComputedCell implements shouldNotify correctly', () {
      final a = MutableCell([1, 2, 3]);
      final b = MutableComputeCell(
          compute: () => a.value[1],
          reverseCompute: (_) {},
          arguments: {a},
          changesOnly: true
      );

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        b();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];
      verify(listener()).called(1);

      a.value = [7, 2, 8];
      verifyNever(listener());

      a.value = [9, 10, 11];
      verify(listener()).called(1);
    });

    test('DynamicMutableComputedCell implements shouldNotify correctly', () {
      final a = MutableCell([1, 2, 3]);
      final b = MutableCell.computed(() => a()[1], (_) {}, changesOnly: true);

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        b();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];
      verify(listener()).called(1);

      a.value = [7, 2, 8];
      verifyNever(listener());

      a.value = [9, 10, 11];
      verify(listener()).called(1);
    });

    test('StoreCell implements shouldNotify correctly', () {
      final a = MutableCell([1, 2, 3]);
      final b = a.apply((a) => a[1]).store(changesOnly: true);

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        b();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];
      verify(listener()).called(1);

      a.value = [7, 2, 8];
      verifyNever(listener());

      a.value = [9, 10, 11];
      verify(listener()).called(1);
    });

    test('MutableCellView implements shouldNotify correctly', () {
      final a = MutableCell([1, 2, 3]);
      final b = a.mutableApply((a) => a[1], (_) {}, changesOnly: true);

      final listener = MockSimpleListener();

      final watcher = ValueCell.watch(() {
        b();
        listener();
      });

      addTearDown(watcher.stop);

      a.value = [4, 2, 6];
      verify(listener()).called(1);

      a.value = [7, 2, 8];
      verifyNever(listener());

      a.value = [9, 10, 11];
      verify(listener()).called(1);
    });
  });

  group('PrevValueCell', () {
    test('PrevValueCell.value holds error on initialization', () {
      final a = MutableCell(0);
      final prev = a.previous;

      expect(() => prev.value, throwsA(isA<UninitializedCellError>()));
    });

    test('PrevValueCell.value holds previous value of cell after being set once', () {
      final a = MutableCell(0);
      final prev = a.previous;

      addObserver(prev, MockSimpleObserver());

      a.value = 10;

      expect(prev.value, equals(0));
    });

    test('PrevValueCell.value holds previous value of cell after being set multiple times', () {
      final a = MutableCell(0);
      final prev = a.previous;

      addObserver(prev, MockSimpleObserver());

      a.value = 10;
      a.value = 5;
      a.value = 32;
      a.value = 40;

      expect(prev.value, equals(32));
    });

    test('PrevValueCell.value set to previous value when observer called', () {
      final a = MutableCell(0);
      final prev = a.previous;

      final observer = addObserver(prev, MockValueObserver());

      a.value = 10;
      a.value = 5;
      a.value = 32;
      a.value = 40;

      expect(observer.values, [0, 10, 5, 32]);
    });

    test('Restoration of PrevValueCell restores value', () {
      final a = MutableCell(10);
      final prev = a.previous as RestorableCell<int>;

      final observer = addObserver(prev, MockSimpleObserver());
      a.value = 30;

      final dump = prev.dumpState(const CellValueCoder());
      prev.removeObserver(observer);

      final restored = a.previous as RestorableCell<int>;
      restored.restoreState(dump, const CellValueCoder());

      observeCell(restored);

      expect(restored.value, equals(10));
    });

    test('Restoration of PrevValueCell restores error', () {
      final a = MutableCell(10);
      final prev = a.previous as RestorableCell<int>;

      addObserver(prev, MockSimpleObserver());

      final restored = a.previous as RestorableCell<int>;
      restored.restoreState(prev.dumpState(const CellValueCoder()), const CellValueCoder());

      expect(() => restored.value, throwsA(isA<UninitializedCellError>()));
    });

    test('Restoration of PrevValueCell restores functionality', () {
      final a = MutableCell(10);
      final prev = a.previous as RestorableCell<int>;

      addObserver(prev, MockSimpleObserver());

      final restored = a.previous as RestorableCell<int>;
      restored.restoreState(prev.dumpState(const CellValueCoder()), const CellValueCoder());

      addObserver(restored, MockSimpleObserver());

      a.value = 45;

      expect(restored.value, equals(10));
    });

    test("PrevValueCell's compare == if they have the same argument cell", () {
      final a = MutableCell(0);

      final c1 = a.previous;
      final c2 = a.previous;

      expect(c1 == c2, isTrue);
      expect(c1.hashCode == c2.hashCode, isTrue);
    });

    test("PrevValueCell's compare != if they have different argument cells", () {
      final a = MutableCell(0);
      final b = MutableCell(1);

      final c1 = a.previous;
      final c2 = b.previous;

      expect(c1 != c2, isTrue);
      expect(c1 == c1, isTrue);
    });

    test("PrevValueCell's manage the same set of observers", () {
      final resource = MockResource();
      final a = TestManagedCell(resource, 1);
      final b = MutableCell(0);
      final c = a + b;

      f() => c.previous;

      verifyNever(resource.init());

      final observer = addObserver(f(), MockSimpleObserver());
      f().removeObserver(observer);

      verify(resource.init()).called(1);
      verify(resource.dispose()).called(1);
    });

    test('PrevValueCell state recreated on adding observer after dispose', () {
      final resource = MockResource();
      final a = TestManagedCell(resource, 1);
      final b = MutableCell(0);
      final c = a + b;

      f() => c.previous;

      verifyNever(resource.init());

      final observer = addObserver(f(), MockSimpleObserver());
      f().removeObserver(observer);

      observeCell(f());

      verify(resource.init()).called(2);
      verify(resource.dispose()).called(1);
    });

    test("PrevValueCell does not track value that hasn't changed", () {
      final a = MutableCell([0, 0, 0]);
      final b = ValueCell.computed(() => a()[1], changesOnly: true);
      final prev = b.previous;

      observeCell(prev);

      a.value = [1, 2, 3];
      a.value = [4, 2, 6];
      expect(prev.value, 0);

      a.value = [7, 8, 9];
      expect(prev.value, 2);

      a.value = [10, 8, 11];
      expect(prev.value, 2);

      a.value = [12, 13, 14];
      expect(prev.value, 8);
    });
  });

  group('List Cell Extensions', () {
    group('.first', () {
      test('ValueCell.first retrieves first element', () {
        final l = [1, 2, 3].cell;
        final f = l.first;

        expect(f.value, 1);
      });

      test('MutableCell.first retrieves first element', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.first;

        expect(f.value, 1);
      });

      test('ValueCell.first notifies observers when first element changed', () {
        final l = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = l;
        final observer = addObserver(l2.first, MockValueObserver());

        l.value = [4, 5, 6];
        l.value = [7, 8, 9];
        l.value = [10, 11, 12];

        expect(observer.values, equals([4, 7, 10]));
      });

      test('Mutable.first notifies observers when first element changed', () {
        final l = MutableCell([1, 2, 3]);
        final observer = addObserver(l.first, MockValueObserver());

        l.value = [4, 5, 6];
        l.value = [7, 8, 9];
        l.value = [10, 11, 12];

        expect(observer.values, equals([4, 7, 10]));
      });

      test('ValueCell.first does not notify observers when first element not changed', () {
        final l = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = l;
        final f = l2.first;

        final listener = addListener(f, MockSimpleListener());

        l.value = [1, 4, 5];
        verifyNever(listener());

        l.value = [1, 6, 7];
        verifyNever(listener());

        l.value = [8, 9, 10];
        verify(listener()).called(1);

        l.value = [11, 12, 13];
        verify(listener()).called(1);

        l.value = [11, 14, 15];
        verifyNever(listener());

        l.value = [16, 17, 18];
        verify(listener()).called(1);
      });

      test('MutableCell.first does not notify observers when first element not changed', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.first;

        final listener = addListener(f, MockSimpleListener());

        l.value = [1, 4, 5];
        verifyNever(listener());

        l.value = [1, 6, 7];
        verifyNever(listener());

        l.value = [8, 9, 10];
        verify(listener()).called(1);

        l.value = [11, 12, 13];
        verify(listener()).called(1);

        l.value = [11, 14, 15];
        verifyNever(listener());

        l.value = [16, 17, 18];
        verify(listener()).called(1);
      });

      test('Setting MutableCell.first.value, updates list cell value', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.first;

        f.value = 10;
        expect(l.value, equals([10, 2, 3]));

        f.value = 20;
        expect(l.value, equals([20, 2, 3]));
      });

      test('ValueCell.first compares == when same list cell', () {
        final l = [1, 2, 3].cell;
        final f1 = l.first;
        final f2 = l.first;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.first compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1.first;
        final f2 = l2.first;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });

      test('MutableCell.first compares == when same list cell', () {
        final l = MutableCell([1, 2, 3]);
        final f1 = l.first;
        final f2 = l.first;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('MutableCell.first compares != when different list cells', () {
        final l1 = MutableCell([1, 2, 3]);
        final l2 = MutableCell([1, 2, 3]);

        final f1 = l1.first;
        final f2 = l2.first;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.last', () {
      test('ValueCell.last retrieves last element', () {
        final l = [1, 2, 3].cell;
        final f = l.last;

        expect(f.value, 3);
      });

      test('MutableCell.last retrieves last element', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.last;

        expect(f.value, 3);
      });

      test('ValueCell.last notifies observers when last element changed', () {
        final l = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = l;
        final observer = addObserver(l2.last, MockValueObserver());

        l.value = [4, 5, 6];
        l.value = [7, 8, 9];
        l.value = [10, 11, 12];

        expect(observer.values, equals([6, 9, 12]));
      });

      test('Mutable.last notifies observers when last element changed', () {
        final l = MutableCell([1, 2, 3]);
        final observer = addObserver(l.last, MockValueObserver());

        l.value = [4, 5, 6];
        l.value = [7, 8, 9];
        l.value = [10, 11, 12];

        expect(observer.values, equals([6, 9, 12]));
      });

      test('ValueCell.last does not notify observers when last element not changed', () {
        final l = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = l;
        final f = l2.last;

        final listener = addListener(f, MockSimpleListener());

        l.value = [4, 5, 3];
        verifyNever(listener());

        l.value = [6, 7, 3];
        verifyNever(listener());

        l.value = [8, 9, 10];
        verify(listener()).called(1);

        l.value = [11, 12, 13];
        verify(listener()).called(1);

        l.value = [14, 15, 13];
        verifyNever(listener());

        l.value = [16, 17, 18];
        verify(listener()).called(1);
      });

      test('MutableCell.last does not notify observers when last element not changed', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.last;

        final listener = addListener(f, MockSimpleListener());

        l.value = [4, 5, 3];
        verifyNever(listener());

        l.value = [6, 7, 3];
        verifyNever(listener());

        l.value = [8, 9, 10];
        verify(listener()).called(1);

        l.value = [11, 12, 13];
        verify(listener()).called(1);

        l.value = [14, 15, 13];
        verifyNever(listener());

        l.value = [16, 17, 18];
        verify(listener()).called(1);
      });

      test('Setting MutableCell.last.value, updates list cell value', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.last;

        f.value = 10;
        expect(l.value, equals([1, 2, 10]));

        f.value = 20;
        expect(l.value, equals([1, 2, 20]));
      });

      test('ValueCell.last compares == when same list cell', () {
        final l = [1, 2, 3].cell;
        final f1 = l.last;
        final f2 = l.last;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.last compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1.last;
        final f2 = l2.last;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });

      test('MutableCell.last compares == when same list cell', () {
        final l = MutableCell([1, 2, 3]);
        final f1 = l.last;
        final f2 = l.last;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('MutableCell.last compares != when different list cells', () {
        final l1 = MutableCell([1, 2, 3]);
        final l2 = MutableCell([1, 2, 3]);

        final f1 = l1.last;
        final f2 = l2.last;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.isEmpty', () {
      test('ValueCell.isEmpty is true when list is empty', () {
        final l = [].cell;
        final f = l.isEmpty;

        expect(f.value, isTrue);
      });

      test('ValueCell.isEmpty is false when list is not empty', () {
        final l = [1, 2, 3].cell;
        final f = l.isEmpty;

        expect(f.value, isFalse);
      });

      test('ValueCell.isEmpty notifies observers when list length changes', () {
        final l = MutableCell([1, 2, 3]);
        final observer = addObserver(l.isEmpty, MockValueObserver());

        l.value = [];
        l.value = [4, 5, 6];
        l.value = [7, 8, 9];
        l.value = [];

        expect(observer.values, equals([true, false, true]));
      });

      test('ValueCell.isEmpty does not notify observers when value has not changed', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.isEmpty;

        final listener = addListener(f, MockSimpleListener());

        l.value = [4, 5, 3];
        verifyNever(listener());

        l.value = [6, 7, 3];
        verifyNever(listener());

        l.value = [];
        verify(listener()).called(1);

        l.value = [];
        verifyNever(listener());

        l.value = [];
        verifyNever(listener());

        l.value = [8, 9, 10];
        verify(listener()).called(1);

        l.value = [11, 12, 13];
        verifyNever(listener());

        l.value = [14, 15, 13];
        verifyNever(listener());

        l.value = [16, 17, 18];
        verifyNever(listener());
      });

      test('ValueCell.isEmpty compares == when same list cell', () {
        final l = [1, 2, 3].cell;
        final f1 = l.isEmpty;
        final f2 = l.isEmpty;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.isEmpty compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1.isEmpty;
        final f2 = l2.isEmpty;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.isNotEmpty', () {
      test('ValueCell.isNotEmpty is false when list is empty', () {
        final l = [].cell;
        final f = l.isNotEmpty;

        expect(f.value, isFalse);
      });

      test('ValueCell.isNotEmpty is true when list is not empty', () {
        final l = [1, 2, 3].cell;
        final f = l.isNotEmpty;

        expect(f.value, isTrue);
      });

      test('ValueCell.isNotEmpty notifies observers when list length changes', () {
        final l = MutableCell([1, 2, 3]);
        final observer = addObserver(l.isNotEmpty, MockValueObserver());

        l.value = [];
        l.value = [4, 5, 6];
        l.value = [7, 8, 9];
        l.value = [];

        expect(observer.values, equals([false, true, false]));
      });

      test('ValueCell.isNotEmpty does not notify observers when value has not changed', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.isNotEmpty;

        final listener = addListener(f, MockSimpleListener());

        l.value = [4, 5, 3];
        verifyNever(listener());

        l.value = [6, 7, 3];
        verifyNever(listener());

        l.value = [];
        verify(listener()).called(1);

        l.value = [];
        verifyNever(listener());

        l.value = [];
        verifyNever(listener());

        l.value = [8, 9, 10];
        verify(listener()).called(1);

        l.value = [11, 12, 13];
        verifyNever(listener());

        l.value = [14, 15, 13];
        verifyNever(listener());

        l.value = [16, 17, 18];
        verifyNever(listener());
      });

      test('ValueCell.isNotEmpty compares == when same list cell', () {
        final l = [1, 2, 3].cell;
        final f1 = l.isNotEmpty;
        final f2 = l.isNotEmpty;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.isNotEmpty compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1.isNotEmpty;
        final f2 = l2.isNotEmpty;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.length', () {
      test('ValueCell.length retrieves list length', () {
        final l = [1, 1, 1, 1].cell;
        final f = l.length;

        expect(f.value, 4);
      });

      test('MutableCell.length retrieves list length', () {
        final l = MutableCell([1, 1, 1, 1]);
        final f = l.length;

        expect(f.value, 4);
      });

      test('ValueCell.length notifies observers when list length changed', () {
        final l = MutableCell([1]);
        final ValueCell<List<int>> l2 = l;
        final observer = addObserver(l2.length, MockValueObserver());

        l.value = [1, 2];
        l.value = [1, 2, 1];
        l.value = [2, 2, 2, 2, 2];

        expect(observer.values, equals([2, 3, 5]));
      });

      test('Mutable.length notifies observers when list length changed', () {
        final l = MutableCell([1, 2, 3]);
        final observer = addObserver(l.length, MockValueObserver());

        l.value = [1, 2];
        l.value = [1, 2, 1];
        l.value = [2, 2, 2, 2, 2];

        expect(observer.values, equals([2, 3, 5]));
      });

      test('ValueCell.length does not notify observers when list length not changed', () {
        final l = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = l;
        final f = l2.length;

        final listener = addListener(f, MockSimpleListener());

        l.value = [1, 1, 1];
        verifyNever(listener());

        l.value = [2, 2, 2];
        verifyNever(listener());

        l.value = [1, 1, 1, 1];
        verify(listener()).called(1);

        l.value = [3, 2, 1, 0];
        verifyNever(listener());

        l.value = [4, 5, 6, 7, 8];
        verify(listener()).called(1);
      });

      test('MutableCell.length does not notify observers when list length not changed', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.length;

        final listener = addListener(f, MockSimpleListener());

        l.value = [1, 1, 1];
        verifyNever(listener());

        l.value = [2, 2, 2];
        verifyNever(listener());

        l.value = [1, 1, 1, 1];
        verify(listener()).called(1);

        l.value = [3, 2, 1, 0];
        verifyNever(listener());

        l.value = [4, 5, 6, 7, 8];
        verify(listener()).called(1);
      });

      test('Setting MutableCell.length.value shrinks list', () {
        final l = MutableCell([1, 2, 3, 4, 5 ,6]);
        final f = l.length;

        f.value = 4;
        expect(l.value, equals([1, 2, 3, 4]));

        f.value = 1;
        expect(l.value, equals([1]));
      });

      test('Setting MutableCell.length.value expands list', () {
        final l = MutableCell<List<int?>>([1, 2, 3]);
        final f = l.length;

        f.value = 6;
        expect(l.value, equals([1, 2, 3, null, null, null]));

        f.value = 1;
        expect(l.value, equals([1]));
      });

      test('ValueCell.length compares == when same list cell', () {
        final l = [1, 2, 3].cell;
        final f1 = l.length;
        final f2 = l.length;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.length compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1.length;
        final f2 = l2.length;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });

      test('MutableCell.length compares == when same list cell', () {
        final l = MutableCell([1, 2, 3]);
        final f1 = l.length;
        final f2 = l.length;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('MutableCell.length compares != when different list cells', () {
        final l1 = MutableCell([1, 2, 3]);
        final l2 = MutableCell([1, 2, 3]);

        final f1 = l1.length;
        final f2 = l2.length;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.reversed', () {
      test('ValueCell.reversed returns reversed list', () {
        final l = MutableCell([1, 2, 3, 4]);
        final f = l.reversed;

        expect(f.value.toList(), [4, 3, 2, 1]);
      });

      test('ValueCell.reversed notifies observers when list has changed', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.reversed;

        final listener = addListener(f, MockSimpleListener());

        l.value = [4, 5, 3];
        l.value = [6, 7, 3];
        l.value = [];
        l.value = [8, 9, 10];
        l.value = [16, 17, 18, 19, 20];

        verify(listener()).called(5);
      });

      test('ValueCell.reversed compares == when same list cell', () {
        final l = [1, 2, 3].cell;
        final f1 = l.reversed;
        final f2 = l.reversed;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.reversed compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1.reversed;
        final f2 = l2.reversed;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.single', () {
      test('ValueCell.single returns element when single', () {
        final l = MutableCell([100]);
        final f = l.single;

        expect(f.value, 100);
      });

      test('ValueCell.single throws exception when empty or not single', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.single;

        expect(() => f.value, throwsStateError);

        l.value = [];
        expect(() => f.value, throwsStateError);
      });

      test('ValueCell.single notifies observers when list has changed', () {
        final l = MutableCell([1, 2, 3]);
        final f = l.single;

        final listener = addListener(f, MockSimpleListener());

        l.value = [4];
        l.value = [6, 7, 3];
        l.value = [];
        l.value = [8, 9];

        verify(listener()).called(4);
      });

      test('ValueCell.single compares == when same list cell', () {
        final l = [1, 2, 3].cell;
        final f1 = l.reversed;
        final f2 = l.reversed;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.single compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1.reversed;
        final f2 = l2.reversed;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.operator[]', () {
      test('ValueCell.operator[] retrieves indexed element', () {
        final l = [10, 20, 30, 40].cell;
        final f = l[2.cell];

        expect(f.value, 30);
      });

      test('MutableCell.operator[] retrieves indexed element', () {
        final l = MutableCell([10, 20, 30, 40]);
        final f = l[1.cell];

        expect(f.value, 20);
      });

      test('ValueCell.operator[] notifies observers when indexed element changed', () {
        final l = MutableCell([11, 22, 33, 44, 55]);
        final ValueCell<List<int>> l2 = l;
        final observer = addObserver(l2[3.cell], MockValueObserver());

        l.value = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        l.value = [11, 12, 13, 14];
        l.value = [2, 4, 8, 16, 32];

        expect(observer.values, equals([4, 14, 16]));
      });

      test('Mutable.operator[] notifies observers when indexed element changed', () {
        final l = MutableCell([1, 2, 3]);
        final observer = addObserver(l[3.cell], MockValueObserver());

        l.value = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        l.value = [11, 12, 13, 14];
        l.value = [2, 4, 8, 16, 32];

        expect(observer.values, equals([4, 14, 16]));
      });

      test('ValueCell.operator[] does not notify observers when indexed element not changed', () {
        final l = MutableCell([1, 2, 3, 4, 5, 6, 7]);
        final ValueCell<List<int>> l2 = l;
        final f = l2[3.cell];

        final listener = addListener(f, MockSimpleListener());

        l.value = [10, 20, 30, 4, 50];
        verifyNever(listener());

        l.value = [11, 12, 13, 4, 15, 16, 17, 18];
        verifyNever(listener());

        l.value = [22, 33, 44, 55, 66];
        verify(listener()).called(1);

        l.value = [1, 2, 3, 4];
        verify(listener()).called(1);

        l.value = [5, 6, 7, 4, 8];
        verifyNever(listener());

        l.value = [9, 10, 11, 12];
        verify(listener()).called(1);
      });

      test('MutableCell.operator[] does not notify observers when indexed element not changed', () {
        final l = MutableCell([1, 2, 3, 4, 5, 6, 7]);
        final f = l[3.cell];

        final listener = addListener(f, MockSimpleListener());

        l.value = [10, 20, 30, 4, 50];
        verifyNever(listener());

        l.value = [11, 12, 13, 4, 15, 16, 17, 18];
        verifyNever(listener());

        l.value = [22, 33, 44, 55, 66];
        verify(listener()).called(1);

        l.value = [1, 2, 3, 4];
        verify(listener()).called(1);

        l.value = [5, 6, 7, 4, 8];
        verifyNever(listener());

        l.value = [9, 10, 11, 12];
        verify(listener()).called(1);
      });

      test('Setting MutableCell.operator[].value, updates list cell value', () {
        final l = MutableCell([1, 2, 3]);
        final f = l[1.cell];

        f.value = 10;
        expect(l.value, equals([1, 10, 3]));

        f.value = 20;
        expect(l.value, equals([1, 20, 3]));
      });

      test('ValueCell.operator[] notifies observers when index changed', () {
        final l = [2, 4, 8, 16, 32].cell;
        final i = MutableCell(2);
        final e = l[i];

        final observer = addObserver(e, MockValueObserver());

        i.value = 0;
        i.value = 3;
        i.value = 1;

        expect(observer.values, equals([2, 16, 4]));
      });

      test('Mutable.operator[] notifies observers when index changed', () {
        final l = MutableCell([2, 4, 8, 16, 32]);
        final i = MutableCell(2);
        final e = l[i];

        final observer = addObserver(e, MockValueObserver());

        i.value = 0;
        i.value = 3;
        i.value = 1;

        expect(observer.values, equals([2, 16, 4]));
      });

      test('ValueCell.operator[] does not notify observers when index not changed', () {
        final l = [2, 4, 8, 16, 32].cell;
        final i = MutableCell(2);
        final e = l[i];

        final listener = addListener(e, MockSimpleListener());

        i.value = 2;
        verifyNever(listener());

        i.value = 2;
        verifyNever(listener());

        i.value = 1;
        verify(listener()).called(1);

        i.value = 1;
        verifyNever(listener());

        i.value = 0;
        verify(listener()).called(1);
      });

      test('Mutable.operator[] does not notify observers when index not changed', () {
        final l = MutableCell([2, 4, 8, 16, 32]);
        final i = MutableCell(2);
        final e = l[i];

        final listener = addListener(e, MockSimpleListener());

        i.value = 2;
        verifyNever(listener());

        i.value = 2;
        verifyNever(listener());

        i.value = 1;
        verify(listener()).called(1);

        i.value = 1;
        verifyNever(listener());

        i.value = 0;
        verify(listener()).called(1);
      });

      test('ValueCell.operator[] gets correct value in batch update', () {
        final l1 = MutableCell([2, 4, 8]);
        final ValueCell<List<int>> l2 = l1;
        final i = MutableCell(2);
        final e = l2[i];

        final observer = addObserver(e, MockValueObserver());

        MutableCell.batch(() {
          i.value = 4;
          l1.value = [16, 32, 64, 128, 256, 512];
        });

        expect(observer.values, equals([256]));
      });

      test('MutableCell.operator[] gets correct value in batch update', () {
        final l = MutableCell([2, 4, 8]);
        final i = MutableCell(2);
        final e = l[i];

        final observer = addObserver(e, MockValueObserver());

        MutableCell.batch(() {
          i.value = 4;
          l.value = [16, 32, 64, 128, 256, 512];
        });

        expect(observer.values, equals([256]));
      });

      test('ValueCell.operator[] compares == when same list cell and same index', () {
        final l = [1, 2, 3].cell;
        final f1 = l[2.cell];
        final f2 = l[2.cell];

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.operator[] compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1[1.cell];
        final f2 = l2[1.cell];

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });

      test('ValueCell.operator[] compares != when different indices', () {
        final ValueCell<List<int>> l = MutableCell([1, 2, 3]);

        final f1 = l[0.cell];
        final f2 = l[1.cell];

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });

      test('MutableCell.operator[] compares == when same list cell and same index', () {
        final l = MutableCell([1, 2, 3]);
        final f1 = l[2.cell];
        final f2 = l[2.cell];

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('MutableCell.operator[] compares != when different list cells', () {
        final l1 = MutableCell([1, 2, 3]);
        final l2 = MutableCell([1, 2, 3]);

        final f1 = l1[1.cell];
        final f2 = l2[1.cell];

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });

      test('Mutable.operator[] compares != when different indices', () {
        final l = MutableCell([1, 2, 3]);

        final f1 = l[0.cell];
        final f2 = l[1.cell];

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.operator[]=', () {
      test('MutableCell.operator[]= updates list cell value', () {
        final l = MutableCell([1, 2, 3]);
        final observer = addObserver(l, MockValueObserver());

        l[1] = 10;
        l[2] = 20;

        expect(observer.values, equals([[1, 10, 3], [1, 10, 20]]));
      });
    });

    group('.cellList', () {
      test('ValueCell.cells returns list of cells observing each element', () {
        final list = ['a', 'b', 'c'].cell;
        final cells = list.cellList.value.toList();

        expect(cells[0].value, 'a');
        expect(cells[1].value, 'b');
        expect(cells[2].value, 'c');
      });

      test('ValueCell.cells notifies observer when list length changed', () {
        final list = MutableCell([1, 2, 3, 4]);
        final cells = list.cellList;

        final l = addListener(cells, MockSimpleListener());

        list.value = [5, 6, 7, 8];
        list.value = [1, 2];
        list.value = [0];
        list.value = [100];

        verify(l()).called(2);
      });

      test('ValueCell.cells returns list of cells which notify observer when element changed', () {
        final list = MutableCell([1, 2, 3, 4]);
        final cells = list.cellList.value.toList();

        final o1 = addObserver(cells[0], MockValueObserver());
        final o2 = addObserver(cells[2], MockValueObserver());

        list.value = [5, 6, 7, 8];
        list.value = [5, 10, 15, 20];
        list.value = [100, 101, 102, 103, 104, 105, 106];

        expect(o1.values, equals([5, 100]));
        expect(o2.values, equals([7, 15, 102]));
      });

      test('ValueCell.cells returns list of cells which do not notify observer when element not changed', () {
        final list = MutableCell([1, 2, 3, 4]);
        final cells = list.cellList.value.toList();

        final l1 = addListener(cells[0], MockSimpleListener());
        final l2 = addListener(cells[2], MockSimpleListener());

        list.value = [5, 6, 7, 8];
        list.value = [5, 10, 15, 20];
        list.value = [100, 101, 102, 103, 104, 105, 106];
        list.value = [100, 0, 102];

        verify(l1()).called(2);
        verify(l2()).called(3);
      });

      test('ValueCell.cells compares == when same list cell', () {
        final l = [1, 2, 3].cell;
        final f1 = l.cellList;
        final f2 = l.cellList;

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.cells compares != when different list cells', () {
        final ValueCell<List<int>> l1 = MutableCell([1, 2, 3]);
        final ValueCell<List<int>> l2 = MutableCell([1, 2, 3]);

        final f1 = l1.cellList;
        final f2 = l2.cellList;

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.cast()', () {
      test('Returns correct value', () {
        final ValueCell<List<dynamic>> cell = [1, 2, 3, 4, 5].cell;
        final ValueCell<List<num>> cast = cell.cast<num>();

        expect(cast.value.toList(), equals([1, 2, 3, 4, 5]));
      });

      test('Compares == when same cell and same type', () {
        final ValueCell<List<dynamic>> cell = [0, 1, 2, 3, 4].cell;
        final ValueCell<List<num>> cast1 = cell.cast<num>();
        final ValueCell<List<num>> cast2 = cell.cast<num>();

        expect(cast1 == cast2, isTrue);
        expect(cast1.hashCode == cast2.hashCode, isTrue);
      });

      test('Compares != when different cells', () {
        final cell1 = MutableCell<Iterable<dynamic>>([0, 1, 2, 3, 4]);
        final cell2 = MutableCell<Iterable<dynamic>>([0, 1, 2, 3, 4]);

        final cast1 = cell1.cast<num>();
        final cast2 = cell2.cast<num>();

        expect(cast1 != cast2, isTrue);
        expect(cast1 == cast1, isTrue);
      });

      test('Compares != when different types', () {
        final ValueCell<List<dynamic>> cell = [0, 1, 2, 3, 4].cell;
        final cast1 = cell.cast<num>();
        final cast2 = cell.cast<int>();

        expect(cast1 != cast2, isTrue);
        expect(cast1 == cast1, isTrue);
      });
    });

    group('.mapCell()', () {
      test('Returns correct value', () {
        final it = [1, 2, 3].cell;
        final map = it.mapCells((e) => e * 2);

        expect(map.value.map((e) => e.value).toList(), equals([2, 4, 6]));
      });

      test('Reacts to changes in list length only', () {
        final it = MutableCell([1, 2, 3]);
        final map = it.mapCells((e) => e * 2);

        final listener = addListener(map, MockSimpleListener());

        expect(map.value.map((e) => e.value).toList(), equals([2, 4, 6]));

        it.value = [4, 5, 6];
        expect(map.value.map((e) => e.value).toList(), equals([8, 10, 12]));

        verifyNever(listener());

        it.value = [7, 8];
        expect(map.value.map((e) => e.value).toList(), equals([14, 16]));

        verify(listener()).called(1);
      });

      test('Element cells react to element changes only', () {
        final it = MutableCell([1, 2, 3, 4]);
        final map = it.mapCells((e) => e * 2);

        final listener1 = addListener(map.value.first, MockSimpleListener());
        final listener2 = addListener(map.value.elementAt(1), MockSimpleListener());
        final listener3 = addListener(map.value.elementAt(2), MockSimpleListener());

        it.value = [1, 10, 3, 20];
        verifyNever(listener1());
        verifyNever(listener3());
        verify(listener2()).called(1);

        it.value = [5, 6, 7];
        verify(listener1()).called(1);
        verify(listener2()).called(1);
        verify(listener3()).called(1);
      });

      test('Compares == when same cell and same function', () {
        f(a) => a * 2;

        final l = MutableCell([1, 2, 3, 4]);
        final map1 = l.mapCells(f);
        final map2 = l.mapCells(f);

        expect(map1 == map2, isTrue);
        expect(map1.hashCode == map2.hashCode, isTrue);
      });

      test('Compares != when same cell and different function', () {
        final l = MutableCell([1, 2, 3, 4]);
        final map1 = l.mapCells((e) => e * 2);
        final map2 = l.mapCells((e) => e + 1);

        expect(map1 != map2, isTrue);
        expect(map1 == map1, isTrue);
      });

      test('Compares != when different cells', () {
        f(a) => a * 2;

        final l1 = MutableCell([1, 2, 3, 4]);
        final l2 = MutableCell([1, 2, 3, 4]);
        final map1 = l1.mapCells(f);
        final map2 = l2.mapCells(f);

        expect(map1 != map2, isTrue);
        expect(map1 == map1, isTrue);
      });

      test('Element cells compare == when same cell and function', () {
        f(a) => a * 2;

        final l = MutableCell([1, 2, 3, 4]);
        final map1 = l.mapCells(f);
        final map2 = l.mapCells(f);

        final c1 = map1.value.elementAt(1);
        final c2 = map2.value.elementAt(1);

        expect(c1 == c2, isTrue);
        expect(c1.hashCode == c2.hashCode, isTrue);
      });

      test('Element cells compare != when same cell and different function', () {
        final l = MutableCell([1, 2, 3, 4]);
        final map1 = l.mapCells((a) => a * 2);
        final map2 = l.mapCells((a) => a + 1);

        final c1 = map1.value.elementAt(1);
        final c2 = map2.value.elementAt(1);

        expect(c1 != c2, isTrue);
        expect(c1 == c1, isTrue);
      });

      test('Element cells compare != when different cells', () {
        f(a) => a * 2;

        final l1 = MutableCell([1, 2, 3, 4]);
        final l2 = MutableCell([1, 2, 3, 4]);
        final map1 = l1.mapCells(f);
        final map2 = l2.mapCells(f);

        final c1 = map1.value.elementAt(1);
        final c2 = map2.value.elementAt(1);

        expect(c1 != c2, isTrue);
        expect(c1 == c1, isTrue);
      });

      test('Element cells compare != when different elements', () {
        f(a) => a * 2;

        final l = MutableCell([1, 2, 3, 4]);
        final map1 = l.mapCells(f);

        final c1 = map1.value.elementAt(1);
        final c2 = map1.value.elementAt(2);

        expect(c1 != c2, isTrue);
        expect(c1 == c1, isTrue);
      });

      test('Element cells compare == after changes to elements', () {
        f(a) => a * 2;

        final l = MutableCell([1, 2, 3, 4]);
        final map1 = l.mapCells(f);

        final c1 = map1.value.elementAt(1);

        l.value = [5, 6, 7, 8];

        final c2 = map1.value.elementAt(1);

        expect(c1 == c2, isTrue);
        expect(c1.hashCode == c2.hashCode, isTrue);
      });

      test('Element cells compare == after changes to elements and list length', () {
        f(a) => a * 2;

        final l = MutableCell([1, 2, 3, 4]);
        final map1 = l.mapCells(f);

        final c1 = map1.value.elementAt(1);

        l.value = [5, 6];

        final c2 = map1.value.elementAt(1);

        expect(c1 == c2, isTrue);
        expect(c1.hashCode == c2.hashCode, isTrue);
      });
    });
  });

  group('Iterable Cell Extensions', () {
    group('.toList()', () {
      test('ValueCell.toList() returns iterable elements in list', () {
        final it = Iterable.generate(5, (i) => i).cell;
        final l = it.toList();

        expect(l.value, equals([0, 1, 2, 3, 4]));
      });

      test('ValueCell.toList() reevaluated when list changes', () {
        final it = MutableCell(Iterable.generate(5, (i) => i));
        final l = it.toList();

        observeCell(l);
        expect(l.value, equals([0, 1, 2, 3, 4]));

        it.value = Iterable.generate(3, (i) => 2 + i);
        expect(l.value, equals([2, 3, 4]));
      });

      test('ValueCell.toList() notifies observers when list changes', () {
        final it = MutableCell(Iterable.generate(5, (i) => i));
        final l = it.toList();

        final listener = addListener(l, MockSimpleListener());

        it.value = Iterable.generate(3, (i) => 2 + i);
        it.value = Iterable.generate(10, (i) => 2 * i);
        it.value = Iterable.generate(5, (_) => 0);

        verify(listener()).called(3);
      });

      test('ValueCell.toList() compares == when same list cell', () {
        final it = MutableCell(Iterable.generate(5, (i) => i));
        final f1 = it.toList();
        final f2 = it.toList();

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.toList() compares != when different list cells', () {
        final it1 = MutableCell(Iterable.generate(5, (i) => i));
        final it2 = MutableCell(Iterable.generate(5, (i) => i));

        final f1 = it1.toList();
        final f2 = it2.toList();

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.toSet()', () {
      test('ValueCell.toSet() returns iterable elements in list', () {
        final it = Iterable.generate(5, (i) => i).cell;
        final l = it.toSet();

        expect(l.value, equals({0, 1, 2, 3, 4}));
      });

      test('ValueCell.toSet() reevaluated when list changes', () {
        final it = MutableCell(Iterable.generate(5, (i) => i));
        final l = it.toSet();

        observeCell(l);
        expect(l.value, equals({0, 1, 2, 3, 4}));

        it.value = Iterable.generate(3, (i) => 2 + i);
        expect(l.value, equals({2, 3, 4}));

        it.value = Iterable.generate(15, (i) => i % 2);
        expect(l.value, {0, 1});
      });

      test('ValueCell.toSet() notifies observers when list changes', () {
        final it = MutableCell(Iterable.generate(5, (i) => i));
        final l = it.toSet();

        final listener = addListener(l, MockSimpleListener());

        it.value = Iterable.generate(3, (i) => 2 + i);
        it.value = Iterable.generate(10, (i) => 2 * i);
        it.value = Iterable.generate(5, (_) => 0);

        verify(listener()).called(3);
      });

      test('ValueCell.toSet() compares == when same list cell', () {
        final it = MutableCell(Iterable.generate(5, (i) => i));
        final f1 = it.toSet();
        final f2 = it.toSet();

        expect(f1 == f2, isTrue);
        expect(f1.hashCode == f2.hashCode, isTrue);
      });

      test('ValueCell.toSet() compares != when different list cells', () {
        final it1 = MutableCell(Iterable.generate(5, (i) => i));
        final it2 = MutableCell(Iterable.generate(5, (i) => i));

        final f1 = it1.toSet();
        final f2 = it2.toSet();

        expect(f1 != f2, isTrue);
        expect(f1 == f1, isTrue);
      });
    });

    group('.cast()', () {
      test('Returns correct value', () {
        final ValueCell<Iterable<dynamic>> cell = Iterable.generate(5, (e) => e).cell;
        final ValueCell<Iterable<num>> cast = cell.cast<num>();

        expect(cast.value.toList(), equals([0, 1, 2, 3, 4]));
      });

      test('Compares == when same cell and same type', () {
        final ValueCell<Iterable<dynamic>> cell = Iterable.generate(5, (e) => e).cell;
        final ValueCell<Iterable<num>> cast1 = cell.cast<num>();
        final ValueCell<Iterable<num>> cast2 = cell.cast<num>();

        expect(cast1 == cast2, isTrue);
        expect(cast1.hashCode == cast2.hashCode, isTrue);
      });

      test('Compares != when different cells', () {
        final cell1 = MutableCell<Iterable<dynamic>>(
            Iterable.generate(5, (e) => e)
        );

        final cell2 = MutableCell<Iterable<dynamic>>(
            Iterable.generate(5, (e) => e)
        );

        final cast1 = cell1.cast<num>();
        final cast2 = cell2.cast<num>();

        expect(cast1 != cast2, isTrue);
        expect(cast1 == cast1, isTrue);
      });

      test('Compares != when different types', () {
        final ValueCell<Iterable<dynamic>> cell = Iterable.generate(5, (e) => e).cell;
        final cast1 = cell.cast<num>();
        final cast2 = cell.cast<int>();

        expect(cast1 != cast2, isTrue);
        expect(cast1 == cast1, isTrue);
      });
    });

    group('.map()', () {
      test('Returns correct value', () {
        final it = Iterable.generate(5, (e) => e).cell;
        final map = it.map((e) => e + 1);

        expect(map.value.toList(), equals([1, 2, 3, 4, 5]));
      });

      test('Reacts to changes in iterable', () {
        final it = MutableCell(
            Iterable.generate(5, (e) => e)
        );

        final map = it.map((e) => e * 2);
        expect(map.value.toList(), equals([0, 2, 4, 6, 8]));

        it.value = Iterable.generate(3, (e) => 10 + e);
        expect(map.value.toList(), equals([20, 22, 24]));
      });
    });
  });

  group('Map Cell Extensions', () {
    group('.isEmpty', () {
      test('Returns correct value', () {
        final m = MutableCell({'a': 0, 'b': 1});

        final obs = addObserver(m.isEmpty, MockValueObserver());

        m.value = {
          'b': 100
        };

        m.value = {};
        m.value = {'d': 9, 'b': 5};

        expect(obs.values, equals([false, true, false]));
      });

      test('compares == when same map cell', () {
        final map = {'a': 1}.cell;
        final e1 = map.isEmpty;
        final e2 = map.isEmpty;

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('compares != when different map cells', () {
        final m1 = MutableCell({ 'a': 0 });
        final m2 = MutableCell({ 'a': 0 });

        final e1 = m1.isEmpty;
        final e2 = m2.isEmpty;

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });
    });

    group('.isNotEmpty', () {
      test('Returns correct value', () {
        final m = MutableCell({'a': 0, 'b': 1});
        final obs = addObserver(m.isNotEmpty, MockValueObserver());

        m.value = {
          'b': 100
        };

        m.value = {};
        m.value = {'d': 9, 'b': 5};

        expect(obs.values, equals([true, false, true]));
      });

      test('compares == when same map cell', () {
        final map = {'a': 1}.cell;
        final e1 = map.isNotEmpty;
        final e2 = map.isNotEmpty;

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('compares != when different map cells', () {
        final m1 = MutableCell({ 'a': 0 });
        final m2 = MutableCell({ 'a': 0 });

        final e1 = m1.isNotEmpty;
        final e2 = m2.isNotEmpty;

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });
    });

    group('.length', () {
      test('Returns correct value', () {
        final m = MutableCell({'a': 0, 'b': 1});
        final obs = addObserver(m.length, MockValueObserver());

        m.value = {
          'b': 100
        };

        m.value = {};
        m.value = {'d': 9, 'b': 5};

        expect(obs.values, equals([1, 0, 2]));
      });

      test('compares == when same map cell', () {
        final map = {'a': 1}.cell;
        final e1 = map.length;
        final e2 = map.length;

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('compares != when different map cells', () {
        final m1 = MutableCell({ 'a': 0 });
        final m2 = MutableCell({ 'a': 0 });

        final e1 = m1.length;
        final e2 = m2.length;

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });
    });

    group('.keys', () {
      test('ValueCell.keys retrieves map keys', () {
        final m = {'k1': 1, 'k2': 2, 'k3': 3}.cell;
        final keys = m.keys;

        expect(keys.value.toSet(), equals({'k1', 'k2', 'k3'}));
      });

      test('ValueCell.keys reacts to changes in map', () {
        final m = MutableCell({'k1': 1, 'k2': 2, 'k3': 3});
        final keys = m.keys;
        final keySet = keys.toSet();

        final observer = addObserver(keySet, MockValueObserver());

        m.value = {
          'a': 0,
          'b': 1,
          'c': 2,
          'd': 3
        };

        expect(observer.values, equals([{'a', 'b', 'c', 'd'}]));
      });

      test('ValueCell.keys compare == if same map cell', () {
        final m = {'a': 1}.cell;
        final keys1 = m.keys;
        final keys2 = m.keys;

        expect(keys1 == keys2, isTrue);
        expect(keys1.hashCode == keys2.hashCode, isTrue);
      });

      test('ValueCell.keys compare != if different map cells', () {
        final m1 = MutableCell({'a': 1});
        final m2 = MutableCell({'a': 1});

        final keys1 = m1.keys;
        final keys2 = m2.keys;

        expect(keys1 != keys2, isTrue);
        expect(keys1 == keys1, isTrue);
      });
    });

    group('.values', () {
      test('ValueCell.values retrieves map values', () {
        final m = {'k1': 1, 'k2': 2, 'k3': 3}.cell;
        final values = m.values;

        expect(values.value.toSet(), equals({1, 2, 3}));
      });

      test('ValueCell.values reacts to changes in map', () {
        final m = MutableCell({'k1': 1, 'k2': 2, 'k3': 3});
        final values = m.values;
        final valueSet = values.toSet();

        final observer = addObserver(valueSet, MockValueObserver());

        m.value = {
          'a': 10,
          'b': 11,
          'c': 12,
          'd': 13
        };

        expect(observer.values, equals([{10, 11, 12, 13}]));
      });

      test('ValueCell.values compare == if same map cell', () {
        final m = {'a': 1}.cell;
        final values1 = m.values;
        final values2 = m.values;

        expect(values1 == values2, isTrue);
        expect(values1.hashCode == values2.hashCode, isTrue);
      });

      test('ValueCell.values compare != if different map cells', () {
        final m1 = MutableCell({'a': 1});
        final m2 = MutableCell({'a': 1});

        final values1 = m1.values;
        final values2 = m2.values;

        expect(values1 != values2, isTrue);
        expect(values1 == values1, isTrue);
      });
    });

    group('.entries', () {
      test('ValueCell.entries retrieves map values', () {
        final m = {'k1': 1, 'k2': 2, 'k3': 3}.cell;
        final entries = m.entries;

        expect(entries.value.map((e) => e.key).toSet(), equals({
          'k1', 'k2', 'k3'
        }));

        expect(entries.value.map((e) => e.value).toSet(), equals({
          1, 2, 3
        }));
      });

      test('ValueCell.entries reacts to changes in map', () {
        final m = MutableCell({'k1': 1, 'k2': 2, 'k3': 3});
        final entries = m.entries;
        final entrySet = entries.toSet();

        final observer = addObserver(entrySet, MockValueObserver());

        m.value = {
          'a': 10,
          'b': 11,
          'c': 12,
          'd': 13
        };

        expect(observer.values[0].map((e) => e.key).toSet(), equals({'a', 'b', 'c', 'd'}));
        expect(observer.values[0].map((e) => e.value).toSet(), equals({10, 11, 12, 13}));
      });

      test('ValueCell.entries compare == if same map cell', () {
        final m = {'a': 1}.cell;
        final entries1 = m.entries;
        final entries2 = m.entries;

        expect(entries1 == entries2, isTrue);
        expect(entries1.hashCode == entries2.hashCode, isTrue);
      });

      test('ValueCell.entries compare != if different map cells', () {
        final m1 = MutableCell({'a': 1});
        final m2 = MutableCell({'a': 1});

        final entries1 = m1.entries;
        final entries2 = m2.entries;

        expect(entries1 != entries2, isTrue);
        expect(entries1 == entries1, isTrue);
      });
    });

    group('.containsKey()', () {
      test('Returns correct value', () {
        final m = MutableCell({'a': 0, 'b': 1});
        final k = m.containsKey('b'.cell);

        final obs = addObserver(k, MockValueObserver());

        m.value = {
          'b': 100
        };

        m.value = {'d': 9};
        m.value = {'d': 9, 'b': 5};

        expect(obs.values, equals([true, false, true]));
      });

      test('compares == when same map and key cells', () {
        final map = {}.cell;
        final e1 = map.containsKey('key1'.cell);
        final e2 = map.containsKey('key1'.cell);

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('compares != when different map cells', () {
        final m1 = {}.cell;
        final m2 = { 'a': 0 }.cell;

        final e1 = m1.containsKey('key1'.cell);
        final e2 = m2.containsKey('key1'.cell);

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });

      test('compares != when different key cells', () {
        final map = {}.cell;
        final e1 = map.containsKey('key1'.cell);
        final e2 = map.containsKey('key2'.cell);

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });
    });

    group('.containsValue()', () {
      test('Returns correct value', () {
        final m = MutableCell({'a': 0, 'b': 1});
        final k = m.containsValue(5.cell);

        final obs = addObserver(k, MockValueObserver());

        m.value = {
          'f': 5
        };

        m.value = {'d': 9};
        m.value = {'d': 9, 'b': 5};
        m.value = {};

        expect(obs.values, equals([true, false, true, false]));
      });

      test('compares == when same map and value cells', () {
        final map = {}.cell;
        final e1 = map.containsValue(100.cell);
        final e2 = map.containsValue(100.cell);

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('compares != when different map cells', () {
        final m1 = {}.cell;
        final m2 = { 'a': 0 }.cell;

        final e1 = m1.containsValue(100.cell);
        final e2 = m2.containsValue(100.cell);

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });

      test('compares != when different value cells', () {
        final map = {}.cell;
        final e1 = map.containsValue(1.cell);
        final e2 = map.containsValue(2.cell);

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });
    });

    group('.operator[]', () {
      test('ValueCell.operator[] retrieves entry value', () {
        const m = ValueCell.value({
          'a': 10,
          'b': 4,
          'c': 1
        });
        final v = m['b'.cell];

        expect(v.value, 4);
      });

      test('MutableCell.operator[] retrieves entry value', () {
        final m = MutableCell({
          'a': 10,
          'b': 4,
          'c': 1
        });
        final v = m['b'.cell];

        expect(v.value, 4);
      });

      test('ValueCell.operator[] notifies observers when entry changes', () {
        final m1 = MutableCell({
          'a': 10,
          'b': 4,
          'c': 1
        });

        final ValueCell<Map<String, int>> m2 = m1;

        final v = m2['b'.cell];
        final observer = addObserver(v, MockValueObserver());

        m1.value = {
          'a': 0,
          'b': 34
        };

        m1.value = {
          'b': 7
        };

        m1.value = {
          'a': 9,
          'd': 89
        };

        expect(observer.values, equals([34, 7, null]));
      });

      test('MutableCell.operator[] notifies observers when entry changes', () {
        final m = MutableCell({
          'a': 10,
          'b': 4,
          'c': 1
        });

        final v = m['b'.cell];
        final observer = addObserver(v, MockValueObserver());

        m.value = {
          'a': 0,
          'b': 34
        };

        m.value = {
          'b': 7
        };

        m.value = {
          'a': 9,
          'd': 89
        };

        expect(observer.values, equals([34, 7, null]));
      });

      test('ValueCell.operator[] does not notify observers when entry does not change', () {
        final m = MutableCell({
          'a1': 0,
          'a2': 3,
          'b3': 5,
          'c4': 10
        });

        final ValueCell<Map<String, int>> m2 = m;

        final e = m2['b3'.cell];
        final listener = addListener(e, MockSimpleListener());

        m.value = {
          'a1': -100,
          'a2': 70,
          'b3': 5
        };

        verifyNever(listener());

        m.value = {
          'b3': 5
        };

        verifyNever(listener());

        m.value = {
          'b3': 90
        };

        verify(listener()).called(1);

        m.value = {
          'b3': 90,
          'a': 180
        };

        verifyNever(listener());

        m.value = {};
        verify(listener()).called(1);
      });

      test('MutableCell.operator[] does not notify observers when entry does not change', () {
        final m = MutableCell({
          'a1': 0,
          'a2': 3,
          'b3': 5,
          'c4': 10
        });

        final e = m['b3'.cell];
        final listener = addListener(e, MockSimpleListener());

        m.value = {
          'a1': -100,
          'a2': 70,
          'b3': 5
        };

        verifyNever(listener());

        m.value = {
          'b3': 5
        };

        verifyNever(listener());

        m.value = {
          'b3': 90
        };

        verify(listener()).called(1);

        m.value = {
          'b3': 90,
          'a': 180
        };

        verifyNever(listener());

        m.value = {};
        verify(listener()).called(1);
      });

      test('Setting MutableCell.operator[].value updates map cell value', () {
        final m = MutableCell({
          'k1': 2,
          'k2': 4,
          'k3': 8
        });

        final e = m['k2'.cell];

        e.value = 64;
        expect(m.value, equals({
          'k1': 2,
          'k2': 64,
          'k3': 8
        }));

        e.value = 100;
        expect(m.value, equals({
          'k1': 2,
          'k2': 100,
          'k3': 8
        }));
      });

      test('ValueCell.operator[] notifies observers when key changed', () {
        const m = ValueCell.value({
          'a': 3,
          'b': 9,
          'c': 27
        });

        final k = MutableCell('');
        final e = m[k];

        final observer = addObserver(e, MockValueObserver());

        k.value = 'b';
        k.value = 'c';
        k.value = 'something else';
        k.value = 'a';

        expect(observer.values, equals([9, 27, null, 3]));
      });

      test('MutableCell.operator[] notifies observers when key changed', () {
        final m = MutableCell({
          'a': 3,
          'b': 9,
          'c': 27
        });

        final k = MutableCell('');
        final e = m[k];

        final observer = addObserver(e, MockValueObserver());

        k.value = 'b';
        k.value = 'c';
        k.value = 'something else';
        k.value = 'a';

        expect(observer.values, equals([9, 27, null, 3]));
      });

      test('ValueCell.operator[] gets correct value in batch update', () {
        final m = MutableCell({'1': 100, '2': 300});
        final ValueCell<Map<String, int>> m2 = m;

        final k = MutableCell('1');
        final e = m2[k];

        final observer = addObserver(e, MockValueObserver());

        MutableCell.batch(() {
          k.value = '5';
          m.value = {
            '3': 9,
            '5': 80
          };
        });

        expect(observer.values, equals([80]));
      });

      test('MutableCell.operator[] gets correct value in batch update', () {
        final m = MutableCell({'1': 100, '2': 300});
        final k = MutableCell('1');
        final e = m[k];

        final observer = addObserver(e, MockValueObserver());

        MutableCell.batch(() {
          k.value = '5';
          m.value = {
            '3': 9,
            '5': 80
          };
        });

        expect(observer.values, equals([80]));
      });

      test('ValueCell.operator[] compares == when same map and key cells', () {
        final map = {}.cell;
        final e1 = map['key1'.cell];
        final e2 = map['key1'.cell];

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('ValueCell.operator[] compares != when different map cells', () {
        final m1 = {}.cell;
        final m2 = { 'a': 0 }.cell;

        final e1 = m1['key1'.cell];
        final e2 = m2['key1'.cell];

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });

      test('ValueCell.operator[] compares != when different key cells', () {
        final map = {}.cell;
        final e1 = map['key1'.cell];
        final e2 = map['key2'.cell];

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });

      test('MutableCell.operator[] compares == when same map and key cells', () {
        final map = MutableCell({});
        final e1 = map['key1'.cell];
        final e2 = map['key1'.cell];

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('MutableCell.operator[] compares != when different map cells', () {
        final m1 = MutableCell({});
        final m2 = MutableCell({ 'a': 0 });

        final e1 = m1['key1'.cell];
        final e2 = m2['key1'.cell];

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });

      test('MutableCell.operator[] compares != when different key cells', () {
        final map = MutableCell({});
        final e1 = map['key1'.cell];
        final e2 = map['key2'.cell];

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });
    });

    group('.operator[]=', () {
      test('MutableCell.operator[]= updates map cell value', () {
        final m = MutableCell({
          'a': 4,
          'b': 16
        });

        final observer = addObserver(m, MockValueObserver());

        m['a'] = 20;
        m['b'] = 50;

        expect(observer.values, equals([
          {'a': 20, 'b': 16},
          {'a': 20, 'b': 50}
        ]));
      });
    });
  });

  group('Set Cell Extensions', () {
    group('.contains()', () {
      test('Returns correct value', () {
        final s = MutableCell({2, 4, 8, 16});
        final k = s.contains(8.cell);

        final obs = addObserver(k, MockValueObserver());

        s.value = {6, 7};

        s.value = {9, 8};
        s.value = {9, 5};

        expect(obs.values, equals([false, true, false]));
      });

      test('compares == when same set and key cells', () {
        final set = {1, 2, 3}.cell;
        final e1 = set.contains(5.cell);
        final e2 = set.contains(5.cell);

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('compares != when different set cells', () {
        final s1 = MutableCell({1, 2, 3});
        final s2 = MutableCell({1, 2, 3});

        final e1 = s1.contains(5.cell);
        final e2 = s2.contains(5.cell);

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });

      test('compares != when different key cells', () {
        final set = {4, 5, 6}.cell;
        final e1 = set.contains(5.cell);
        final e2 = set.contains(6.cell);

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });
    });

    group('.containsAll()', () {
      test('Returns correct value', () {
        final s = MutableCell({2, 4, 8, 16});
        final k = s.containsAll(const [2, 4].cell);

        final obs = addObserver(k, MockValueObserver());

        s.value = {2, 6, 8};

        s.value = {4, 8, 2};
        s.value = {4, 8};

        expect(obs.values, equals([false, true, false]));
      });

      test('compares == when same set and key cells', () {
        final set = {1, 2, 3}.cell;
        final keys = [1, 3].cell;

        final e1 = set.containsAll(keys);
        final e2 = set.containsAll(keys);

        expect(e1 == e2, isTrue);
        expect(e1.hashCode == e2.hashCode, isTrue);
      });

      test('compares != when different set cells', () {
        final keys = [1, 3].cell;

        final s1 = MutableCell({1, 2, 3});
        final s2 = MutableCell({1, 2, 3});

        final e1 = s1.containsAll(keys);
        final e2 = s2.containsAll(keys);

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });

      test('compares != when different key cells', () {
        final set = {4, 5, 6}.cell;
        final e1 = set.containsAll(const {5}.cell);
        final e2 = set.containsAll(const {6}.cell);

        expect(e1 != e2, isTrue);
        expect(e1 == e1, isTrue);
      });
    });
  });
}

// Test utility functions

/// Add an observer to a cell so that it reacts to changes in is dependencies.
///
/// The observer is removed in a teardown function added to the current test.
void observeCell(ValueCell cell) {
  addObserver(cell, MockSimpleObserver());
}

/// Add an observer to a cell.
///
/// This function also adds a teardown to the current test which removes
/// the [observer] from [cell], after the current test runs.
T addObserver<T extends CellObserver>(ValueCell cell, T observer) {
  cell.addObserver(observer);
  addTearDown(() => cell.removeObserver(observer));

  return observer;
}

/// Add a listener to a cell, which is called whenever the cell changes.
///
/// This function adds a watch function that references [cell]. Unlike
/// [ValueCell.watch] the watch function is not called on the initial setup.
///
/// This function also adds a teardown to the current test which removes
/// the [listener] from [cell], after the current test runs.
T addListener<T extends SimpleListener>(ValueCell cell, T? listener) {
  listener ??= MockSimpleListener() as T?;

  var first = true;

  final watcher = ValueCell.watch(() {
    try {
      cell();
    }
    catch (e) {
      // Print exceptions from failing tests
      // The value is only referenced to set up the dependency. An exception
      // doesn't actually mean a test failed
    }

    if (!first) {
      listener!.call();
    }

    first = false;
  });

  addTearDown(() => watcher.stop());

  return listener!;
}