/// Provides the base classes for integrating [ValueCell]'s with widgets.
library live_cell_widgets_base;

export 'src/extensions/widget_extension.dart'
    show WidgetExtension, WidgetCellExtension, ComputeWidgetExtension;

export 'src/cell_widget/cell_widget.dart'
    show
        CellWidget,
        CreateCell,
        CellInitializer,
        CellWidgetContextExtension,
        CellObserverState;

export 'src/cell_widget/static_widget.dart' show StaticWidget;

export 'src/restoration/restorable_cell_widget.dart' show RestorableCellWidget;
