import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_cell_widgets/live_cell_widgets.dart';
import 'package:live_cell_widgets/live_cell_widgets_base.dart';
import 'package:live_cells_core/live_cells_core.dart';

/// Wraps a widget in a [MaterialApp] for testing
class TestApp extends StatelessWidget {
  /// Child widget to test
  final Widget child;

  const TestApp({
    super.key,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }
}

/// Tests CellWidget subclass observing one cell
class CellWidgetTest1 extends CellWidget {
  final ValueCell<int> count;

  const CellWidgetTest1({
    super.key,
    required this.count
  });

  @override
  Widget build(BuildContext context) {
    return Text('${count()}');
  }
}

/// Tests CellWidget subclass observing two cells
class CellWidgetTest2 extends CellWidget {
  final ValueCell<num> a;
  final ValueCell<num> b;
  final ValueCell<num> sum;

  const CellWidgetTest2({
    super.key,
    required this.a,
    required this.b,
    required this.sum
  });

  @override
  Widget build(BuildContext context) {
    return Text('${a()} + ${b()} = ${sum()}');
  }
}

/// Tests CellWidget subclass with cells defined in build method
class CellWidgetTest3 extends CellWidget with CellInitializer {
  const CellWidgetTest3({super.key});

  @override
  Widget build(BuildContext context) {
    final c1 = cell(() => MutableCell(0));
    final c2 = cell(() => MutableCell(10));

    return Column(
      children: [
        ElevatedButton(
            onPressed: () => c1.value++,
            child: Text('${c1()}')
        ),
        ElevatedButton(
            onPressed: () => c2.value++,
            child: Text('${c2()}')
        )
      ],
    );
  }
}

/// Tests that cells defined in build method are persisted across builds.
class CellWidgetTest4 extends CellWidget with CellInitializer {
  final String title;

  const CellWidgetTest4(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final c1 = cell(() => MutableCell(0));
    final c2 = cell(() => MutableCell(10));

    return Column(
      children: [
        Text(title),
        ElevatedButton(
            onPressed: () => c1.value++,
            child: Text('${c1()}')
        ),
        ElevatedButton(
            onPressed: () => c2.value++,
            child: Text('${c2()}')
        )
      ],
    );
  }
}

/// Tests StaticWidget subclass with cells defined in build method
class StaticWidgetTest1 extends StaticWidget {
  const StaticWidgetTest1({super.key});

  @override
  Widget build(BuildContext context) {
    final c1 = MutableCell(0);
    final c2 = MutableCell(10);

    return Column(
      children: [
        ElevatedButton(
            onPressed: () => c1.value++,
            child: CellWidget.builder((_) => Text('${c1()}'))
        ),
        ElevatedButton(
            onPressed: () => c2.value++,
            child: CellWidget.builder((_) => Text('${c2()}'))
        )
      ],
    );
  }
}

/// Tests that cells defined in build method are persisted across builds.
///
/// Additionally also tests that the widgets defined in the build method are
/// not rebuilt.
class StaticWidgetTest2 extends StaticWidget {
  final String title;

  const StaticWidgetTest2(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final c1 = MutableCell(0);
    final c2 = MutableCell(10);

    return Column(
      children: [
        Text(title),
        ElevatedButton(
            onPressed: () => c1.value++,
            child: CellWidget.builder((_) => Text('${c1()}'))
        ),
        ElevatedButton(
            onPressed: () => c2.value++,
            child: CellWidget.builder((_) => Text('${c2()}'))
        )
      ],
    );
  }
}

// Group Value enum for unit tests
enum RadioTestValue {
  value1,
  value2
}

void main() {
  group('CellWidget.builder', () {
    testWidgets('Rebuilt when referenced cell changes', (tester) async {
      final count = MutableCell(0);
      await tester.pumpWidget(TestApp(
          child: CellWidget.builder((context) => Text('${count()}'))
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      count.value++;
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      count.value++;
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Rebuilt when multiple referenced cells changed', (tester) async {
      final a = MutableCell(0);
      final b = MutableCell(1);
      final sum = (a + b).store();

      await tester.pumpWidget(TestApp(
          child: CellWidget.builder((context) => Text('${a()} + ${b()} = ${sum()}'))
      ));

      expect(find.text('0 + 1 = 1'), findsOneWidget);

      a.value = 2;
      await tester.pump();
      expect(find.text('2 + 1 = 3'), findsOneWidget);

      MutableCell.batch(() {
        a.value = 5;
        b.value = 8;
      });
      await tester.pump();
      expect(find.text('5 + 8 = 13'), findsOneWidget);
    });

    testWidgets('Cells defined in build method', (tester) async {
      await tester.pumpWidget(TestApp(
        child: CellWidget.builder((context) {
          final c1 = context.cell(() => MutableCell(0));
          final c2 = context.cell(() => MutableCell(10));

          return Column(
            children: [
              ElevatedButton(
                  onPressed: () => c1.value++,
                  child: Text('${c1()}')
              ),
              ElevatedButton(
                  onPressed: () => c2.value++,
                  child: Text('${c2()}')
              )
            ],
          );
        }),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      await tester.tap(find.text('1'));
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('Cells defined in build method persisted between builds', (tester) async {
      await tester.pumpWidget(TestApp(
        child: Column(
          children: [
            const Text('First Build'),
            CellWidget.builder((context) {
              final c1 = context.cell(() => MutableCell(0));
              final c2 = context.cell(() => MutableCell(10));

              return Column(
                children: [
                  ElevatedButton(
                      onPressed: () => c1.value++,
                      child: Text('${c1()}')
                  ),
                  ElevatedButton(
                      onPressed: () => c2.value++,
                      child: Text('${c2()}')
                  )
                ],
              );
            }),
          ],
        ),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('First Build'), findsOneWidget);

      // Press first button
      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Press second button
      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Rebuild widget hierarchy
      await tester.pumpWidget(TestApp(
        child: Column(
          children: [
            const Text('Second Build'),
            CellWidget.builder((context) {
              final c1 = context.cell(() => MutableCell(0));
              final c2 = context.cell(() => MutableCell(10));

              return Column(
                children: [
                  ElevatedButton(
                      onPressed: () => c1.value++,
                      child: Text('${c1()}')
                  ),
                  ElevatedButton(
                      onPressed: () => c2.value++,
                      child: Text('${c2()}')
                  )
                ],
              );
            }),
          ],
        ),
      ));

      // Check that counters still have the same values
      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Check that the hierarchy has been rebuilt
      expect(find.text('Second Build'), findsOneWidget);
      expect(find.text('First Build'), findsNothing);

      // Press first button
      await tester.tap(find.text('1'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Press second button
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('CellWidget subclass', () {
    testWidgets('Rebuilt when referenced cell changes', (tester) async {
      final count = MutableCell(0);
      await tester.pumpWidget(TestApp(
          child: CellWidgetTest1(count: count)
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      count.value++;
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      count.value++;
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Rebuilt when multiple referenced cells changed', (tester) async {
      final a = MutableCell(0);
      final b = MutableCell(1);
      final sum = (a + b).store();

      await tester.pumpWidget(TestApp(
          child: CellWidgetTest2(
            a: a,
            b: b,
            sum: sum,
          )
      ));

      expect(find.text('0 + 1 = 1'), findsOneWidget);

      a.value = 2;
      await tester.pump();
      expect(find.text('2 + 1 = 3'), findsOneWidget);

      MutableCell.batch(() {
        a.value = 5;
        b.value = 8;
      });
      await tester.pump();
      expect(find.text('5 + 8 = 13'), findsOneWidget);
    });

    testWidgets('Cells defined in build method', (tester) async {
      await tester.pumpWidget(const TestApp(
        child: CellWidgetTest3(),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      await tester.tap(find.text('1'));
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('Cells defined in build method persisted between builds', (tester) async {
      await tester.pumpWidget(const TestApp(
        child: CellWidgetTest4('First Build'),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('First Build'), findsOneWidget);

      // Press first button
      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Press second button
      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Rebuild widget hierarchy
      await tester.pumpWidget(const TestApp(
        child: CellWidgetTest4('Second Build'),
      ));

      // Check that counters still have the same values
      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Check that the hierarchy has been rebuilt
      expect(find.text('Second Build'), findsOneWidget);
      expect(find.text('First Build'), findsNothing);

      // Press first button
      await tester.tap(find.text('1'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Press second button
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('StaticWidget.builder', () {
    testWidgets('Cells defined in build method', (tester) async {
      await tester.pumpWidget(TestApp(
        child: StaticWidget.builder((context) {
          final c1 = MutableCell(0);
          final c2 = MutableCell(10);

          return Column(
            children: [
              ElevatedButton(
                  onPressed: () => c1.value++,
                  child: CellWidget.builder((_) => Text('${c1()}'))
              ),
              ElevatedButton(
                  onPressed: () => c2.value++,
                  child: CellWidget.builder((_) => Text('${c2()}'))
              )
            ],
          );
        }),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      await tester.tap(find.text('1'));
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('Cells defined in build method persisted between builds', (tester) async {
      await tester.pumpWidget(TestApp(
        child: Column(
          children: [
            const Text('First Build'),
            StaticWidget.builder((context) {
              final c1 = MutableCell(0);
              final c2 = MutableCell(10);

              return Column(
                children: [
                  ElevatedButton(
                      onPressed: () => c1.value++,
                      child: CellWidget.builder((_) => Text('${c1()}'))
                  ),
                  ElevatedButton(
                      onPressed: () => c2.value++,
                      child: CellWidget.builder((_) => Text('${c2()}'))
                  )
                ],
              );
            }),
          ],
        ),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('First Build'), findsOneWidget);

      // Press first button
      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Press second button
      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Rebuild widget hierarchy
      await tester.pumpWidget(TestApp(
        child: Column(
          children: [
            const Text('Second Build'),
            StaticWidget.builder((context) {
              final c1 = MutableCell(0);
              final c2 = MutableCell(10);

              return Column(
                children: [
                  ElevatedButton(
                      onPressed: () => c1.value++,
                      child: CellWidget.builder((_) => Text('${c1()}'))
                  ),
                  ElevatedButton(
                      onPressed: () => c2.value++,
                      child: CellWidget.builder((_) => Text('${c2()}'))
                  )
                ],
              );
            }),
          ],
        ),
      ));

      // Check that counters still have the same values
      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Check that the hierarchy has been rebuilt
      expect(find.text('Second Build'), findsOneWidget);
      expect(find.text('First Build'), findsNothing);

      // Press first button
      await tester.tap(find.text('1'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Press second button
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('StaticWidget subclass', () {
    testWidgets('Cells defined in build method', (tester) async {
      await tester.pumpWidget(const TestApp(
        child: StaticWidgetTest1(),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      await tester.tap(find.text('1'));
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('Cells defined in build method persisted between builds', (tester) async {
      await tester.pumpWidget(const TestApp(
        child: Column(
          children: [
            Text('First Build'),
            StaticWidgetTest2('Build 1'),
          ],
        ),
      ));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      expect(find.text('First Build'), findsOneWidget);
      expect(find.text('Build 1'), findsOneWidget);

      // Press first button
      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Press second button
      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Rebuild widget hierarchy
      await tester.pumpWidget(const TestApp(
        child: Column(
          children: [
            Text('Second Build'),
            StaticWidgetTest2('Build 2'),
          ],
        ),
      ));

      // Check that counters still have the same values
      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Check that the hierarchy has been rebuilt
      expect(find.text('Second Build'), findsOneWidget);
      expect(find.text('First Build'), findsNothing);

      // Check that the widgets inside the [StaticWidget] have not been rebuilt
      expect(find.text('Build 1'), findsOneWidget);
      expect(find.text('Build 2'), findsNothing);

      // Press first button
      await tester.tap(find.text('1'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Press second button
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });

  // The following tests will test some of the generated widget wrappers

  // Writing unit tests for every single wrapper is an insurmountable task,
  // so the tests will focus on those Widgets with customizations to the
  // generated code, such as CellSwitch, CellRadio, CellTextField
  // (which is written by hand), and those which are likely to be problematic
  // such as Row and Column.

  group('CellText', () {
    testWidgets('Data updated when cell value changed', (tester) async {
      final data = MutableCell('hello');

      await tester.pumpWidget(TestApp(
        child: CellText(data: data),
      ));

      expect(find.text('hello'), findsOneWidget);

      data.value = 'bye';
      await tester.pump();
      expect(find.text('bye'), findsOneWidget);
    });

    testWidgets('All properties updated when cell values change', (tester) async {
      final data = MutableCell('hello');
      final align = MutableCell(TextAlign.left);

      await tester.pumpWidget(TestApp(
        child: CellText(
          data: data,
          textAlign: align,
        ),
      ));

      findText(String data, TextAlign align) => find.byWidgetPredicate((widget) => widget is Text &&
          widget.data == data &&
          widget.textAlign == align
      );

      expect(findText('hello', TextAlign.left), findsOneWidget);

      MutableCell.batch(() {
        data.value = 'bye';
        align.value = TextAlign.center;
      });

      await tester.pump();
      expect(findText('bye', TextAlign.center), findsOneWidget);
    });
  });

  group('CellSwitch', () {
    testWidgets('Switch initialized to on', (tester) async {
      final state = MutableCell(true);

      await tester.pumpWidget(TestApp(
        child: CellSwitch(value: state),
      ));

      final onFinder = find.byWidgetPredicate((widget) => widget is Switch && widget.value);
      final offFinder = find.byWidgetPredicate((widget) => widget is Switch && !widget.value);

      expect(onFinder, findsOneWidget);
      expect(offFinder, findsNothing);
    });

    testWidgets('Switch initialized to off', (tester) async {
      final state = MutableCell(false);

      await tester.pumpWidget(TestApp(
        child: CellSwitch(value: state),
      ));

      final onFinder = find.byWidgetPredicate((widget) => widget is Switch && widget.value);
      final offFinder = find.byWidgetPredicate((widget) => widget is Switch && !widget.value);

      expect(onFinder, findsNothing);
      expect(offFinder, findsOneWidget);
    });

    testWidgets('Switch state reflects value of cell', (tester) async {
      final state = MutableCell(true);

      await tester.pumpWidget(TestApp(
        child: CellSwitch(value: state),
      ));

      final onFinder = find.byWidgetPredicate((widget) => widget is Switch && widget.value);
      final offFinder = find.byWidgetPredicate((widget) => widget is Switch && !widget.value);

      // Check that the switch is initially on
      expect(onFinder, findsOneWidget);
      expect(offFinder, findsNothing);

      state.value = false;
      await tester.pump();

      // Check that the switch is now off
      expect(onFinder, findsNothing);
      expect(offFinder, findsOneWidget);
    });

    testWidgets('Value of cell reflects the switch state', (tester) async {
      final state = MutableCell(true);

      await tester.pumpWidget(TestApp(
        child: CellSwitch(value: state),
      ));

      final onFinder = find.byWidgetPredicate((widget) => widget is Switch && widget.value);
      final offFinder = find.byWidgetPredicate((widget) => widget is Switch && !widget.value);

      // Check that the switch is initially on
      expect(onFinder, findsOneWidget);
      expect(offFinder, findsNothing);

      // Toggle the switch
      await tester.tap(onFinder);

      expect(state.value, isFalse);
    });
  });

  group('CellRadioListTile', () {
    testWidgets('group value initialized correctly', (tester) async {
      final groupValue = MutableCell<RadioTestValue?>(RadioTestValue.value1);

      await tester.pumpWidget(TestApp(
        child: Column(
          children: [
            CellRadioListTile(
              value: RadioTestValue.value1.cell,
              groupValue: groupValue,
              title: const Text('value1').cell,
            ),
            CellRadioListTile(
              value: RadioTestValue.value2.cell,
              groupValue: groupValue,
              title: const Text('value2').cell,
            )
          ],
        )
      ));

      final value1Finder = find.byWidgetPredicate((widget) => widget is RadioListTile &&
          widget.value == RadioTestValue.value1 &&
          widget.groupValue == RadioTestValue.value1
      );

      final value2Finder = find.byWidgetPredicate((widget) => widget is RadioListTile &&
          widget.value == RadioTestValue.value2 &&
          widget.groupValue == RadioTestValue.value1
      );

      expect(value1Finder, findsOneWidget);
      expect(value2Finder, findsOneWidget);
    });

    testWidgets('group value initialized correctly when null', (tester) async {
      final groupValue = MutableCell<RadioTestValue?>(null);

      await tester.pumpWidget(TestApp(
          child: Column(
            children: [
              CellRadioListTile(
                value: RadioTestValue.value1.cell,
                groupValue: groupValue,
                title: const Text('value1').cell,
              ),
              CellRadioListTile(
                value: RadioTestValue.value2.cell,
                groupValue: groupValue,
                title: const Text('value2').cell,
              )
            ],
          )
      ));

      final value1Finder = find.byWidgetPredicate((widget) => widget is RadioListTile &&
          widget.value == RadioTestValue.value1 &&
          widget.groupValue == null
      );

      final value2Finder = find.byWidgetPredicate((widget) => widget is RadioListTile &&
          widget.value == RadioTestValue.value2 &&
          widget.groupValue == null
      );

      expect(value1Finder, findsOneWidget);
      expect(value2Finder, findsOneWidget);
    });

    testWidgets('group value reflects value of cell', (tester) async {
      final groupValue = MutableCell<RadioTestValue?>(null);

      await tester.pumpWidget(TestApp(
          child: Column(
            children: [
              CellRadioListTile(
                value: RadioTestValue.value1.cell,
                groupValue: groupValue,
                title: const Text('value1').cell,
              ),
              CellRadioListTile(
                value: RadioTestValue.value2.cell,
                groupValue: groupValue,
                title: const Text('value2').cell,
              )
            ],
          )
      ));

      finder(RadioTestValue? groupValue, RadioTestValue value) =>
          find.byWidgetPredicate((widget) => widget is RadioListTile &&
              widget.value == value &&
              widget.groupValue == groupValue
          );

      expect(finder(null, RadioTestValue.value1), findsOneWidget);
      expect(finder(null, RadioTestValue.value2), findsOneWidget);

      groupValue.value = RadioTestValue.value1;
      await tester.pump();

      // Check that the group value is updated in both radio buttons
      expect(finder(RadioTestValue.value1, RadioTestValue.value1), findsOneWidget);
      expect(finder(RadioTestValue.value1, RadioTestValue.value2), findsOneWidget);
    });

    testWidgets('value of cell reflects group value', (tester) async {
      final groupValue = MutableCell<RadioTestValue?>(null);

      await tester.pumpWidget(TestApp(
          child: Column(
            children: [
              CellRadioListTile(
                value: RadioTestValue.value1.cell,
                groupValue: groupValue,
                title: const Text('value1').cell,
              ),
              CellRadioListTile(
                value: RadioTestValue.value2.cell,
                groupValue: groupValue,
                title: const Text('value2').cell,
              )
            ],
          )
      ));

      finder(RadioTestValue? groupValue, RadioTestValue value) =>
          find.byWidgetPredicate((widget) => widget is RadioListTile &&
              widget.value == value &&
              widget.groupValue == groupValue
          );

      expect(finder(null, RadioTestValue.value1), findsOneWidget);
      expect(finder(null, RadioTestValue.value2), findsOneWidget);

      // Tap first radio button
      await tester.tap(find.text('value1'));
      expect(groupValue.value, equals(RadioTestValue.value1));

      // Tap second radio button
      await tester.tap(find.text('value2'));
      expect(groupValue.value, equals(RadioTestValue.value2));
    });
  });

  group('CellColumn', () {
    testWidgets('All children rendered correctly', (tester) async {
      final children = MutableCell(const [
        Text('Child 1'),
        Expanded(child: Text('Child 2'))
      ]);

      await tester.pumpWidget(TestApp(
        child: CellColumn(children: children),
      ));

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);

      // Change the first child
      children[0] = const Text('New Child');
      await tester.pump();

      expect(find.text('New Child'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 1'), findsNothing);
    });

    testWidgets('Children added to list are rendered correctly', (tester) async {
      final children = MutableCell(const [
        Text('Child 1'),
        Expanded(child: Text('Child 2'))
      ]);

      await tester.pumpWidget(TestApp(
        child: CellColumn(children: children),
      ));

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsNothing);

      // Add a widget to the list
      children.value = const [
        Text('Child 1'),
        Text('Child 2'),
        Text('Child 3')
      ];

      await tester.pump();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
    });

    testWidgets('Children rendered correctly when widgets removed from list', (tester) async {
      final children = MutableCell(const [
        Text('Child 1'),
        Expanded(child: Text('Child 2')),
        Text('Child 3')
      ]);

      await tester.pumpWidget(TestApp(
        child: CellColumn(children: children),
      ));

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);

      // Add a widget to the list
      children.value = const [
        Expanded(child: Text('Child 2')),
        Text('Child 3')
      ];

      await tester.pump();

      expect(find.text('Child 1'), findsNothing);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
    });
  });

  group('CellRow', () {
    testWidgets('All children rendered correctly', (tester) async {
      final children = MutableCell(const [
        Text('Child 1'),
        Expanded(child: Text('Child 2'))
      ]);

      await tester.pumpWidget(TestApp(
        child: CellRow(children: children),
      ));

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);

      // Change the first child
      children[0] = const Text('New Child');
      await tester.pump();

      expect(find.text('New Child'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 1'), findsNothing);
    });

    testWidgets('Children added to list are rendered correctly', (tester) async {
      final children = MutableCell(const [
        Text('Child 1'),
        Expanded(child: Text('Child 2'))
      ]);

      await tester.pumpWidget(TestApp(
        child: CellRow(children: children),
      ));

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsNothing);

      // Add a widget to the list
      children.value = const [
        Text('Child 1'),
        Text('Child 2'),
        Text('Child 3')
      ];

      await tester.pump();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
    });

    testWidgets('Children rendered correctly when widgets removed from list', (tester) async {
      final children = MutableCell(const [
        Text('Child 1'),
        Expanded(child: Text('Child 2')),
        Text('Child 3')
      ]);

      await tester.pumpWidget(TestApp(
        child: CellRow(children: children),
      ));

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);

      // Add a widget to the list
      children.value = const [
        Expanded(child: Text('Child 2')),
        Text('Child 3')
      ];

      await tester.pump();

      expect(find.text('Child 1'), findsNothing);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
    });
  });
}