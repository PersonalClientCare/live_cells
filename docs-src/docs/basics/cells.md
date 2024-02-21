---
title: Cells
description: Introduction to the cell -- the basic building block of Live Cells.
sidebar_position: 1
---

# Cells

A cell, denoted by the base type `ValueCell`, is an object with a
value and a set of observers that react to changes in its value,
you'll see exactly what that means in a moment.

```dart title="Creating cells"
final a = 1.cell;
final b = 'hello world'.cell;
final c = ValueCell.value(someValue);
```

The above is an example of *constant cells*, which can be created
either using the `.cell` property, which is added to the value types
built into Dart, or the `ValueCell.value` constructor which takes a
value and wraps it in a `ValueCell`. A constant cell has a value that
does not change throughout its lifetime. 

The value of a cell is accessed using the `value` property.

```dart title="Accessing cell values"
print(a.value); // Prints: 1
print(b.value); // Prints: 'hello world'
print(c.value); // Prints the value of `someValue`
```

## Mutable Cells

Mutable cells, created with the `MutableCell` constructor, hold a
value that can be set directly, by assigning a value to the `value`
property.

```dart title="Creating mutable cells"
final a = MutableCell(0);

print(a.value); // Prints: 0

a.value = 3;
print(a.value); // Prints: 3
```

## Observing Cells

When the value of a cell changes, its observers are notified of the
change. The simplest way to demonstrate this is to set up a *watch
function* using `ValueCell.watch`:

```dart title="Observing cells"
final a = MutableCell(0);
final b = MutableCell(1);

// Set up a watch function observing cells `a` and `b`
final watcher = ValueCell.watch(() {
    print('${a()} + ${b()} = ${a() + b()}');
});

a.value = 5;  // Prints: 5 + 1 = 6
b.value = 10; // Prints: 5 + 10 = 15
```


In the example above, a watch function that prints the values of cells
`a` and `b` to the console, along with their sum, is defined. This
function is called automatically when the value of either `a` or `b`
change. 

**Note**, the value of a cell is referenced using the function call
syntax, within a watch function, rather than accessing the value
property directly.

Every call to `ValueCell.watch` adds a new watch function, for
example:

```dart title="Multiple watch functions"
final watcher2 = ValueCell.watch(() => print('A = ${a()}'));

// Prints: 20 + 10 = 30
// Also prints: A = 20
a.value = 20;

// Prints: 20 + 1 = 21
b.value = 1;
```

The watch function defined above, `watcher2`, observes the value of
`a` only. Changing the value of `a` results in both watch functions
being called. Changing the value of `b` only results in the first
watch function being called, since the second watch function is not
observing `b`.

:::tip
When you no longer need the watch function to be called, call `stop`
on the `CellWatcher` object returned by `ValueCell.watch`.
:::

## Computed Cells

A *computed cell*, defined using `ValueCell.computed`, is a cell
with a value that is defined as a function of the values of one or
more argument cells. Whenever the value of an argument cell changes,
the value of the computed cell is recomputed.

```dart title="Computed cells"
final a = MutableCell(1);
final b = MutableCell(2);
final sum = ValueCell.computed(() => a() + b());
```

In the above example, `sum` is a computed cell with the value defined
as the sum of cells `a` and `b`. The value of `sum` is recomputed
whenever the values of either `a` or `b` change. This is demonstrated
below:

```dart title="Computed cells"
final watcher = ValueCell.watch(() {
    print('The sum is ${sum()}');
});

a.value = 3; // Prints: The sum is 5
b.value = 4; // Prints: The sum is 7
```

In this example:

1. A watch function observing the `sum` cell is defined.
2. The value of `a` is set to `3`, which:
   1. Causes the value of `sum` to be recomputed
   2. Calls the watch function defined in 1.
3. The value of `b` is set to `4`, which likewise also results in the
   sum being recomputed and the watch function being called.

## Batch Updates

The `MutableCell.batch` function allows the values of multiple mutable
cells to be set simultaneously. The effect of this is that while the
values of the cells are changed as soon as their `value` properties
are set, the observers of the cells are only notified after all the
cell values have been set.

```dart title="Batch updates"
final a = MutableCell(0);
final b = MutableCell(1);

final watcher = ValueCell.watch(() {
    print('a = ${a()}, b = ${b()}');
});

// This only prints: a = 15, b = 3
MutableCell.batch(() {
    a.value = 15;
    b.value = 3;
});
```

In the example above, the values of `a` and `b` are set to `15` and
`3` respectively, within a `MutableCell.batch`. The watch function,
which observes both `a` and `b`, is only called once after the value
of both `a` and `b` is set within `MutableCell.batch`.

As a result the following is printed to the console:

```
a = 0, b = 1
a = 15, b = 3
```

1. `a = 0, b = 1` is printed when the watch function is first defined.  
2. `a = 15, b = 3` is printed when `MutableCell.batch` returns.

:::info
A watch function is always called once immediately after it is set
up. This is necessary to determine, which cells the watch function is
observing.
:::