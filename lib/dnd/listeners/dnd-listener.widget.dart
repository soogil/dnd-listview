import 'package:dnd_listview/dnd/widget/dnd-item.widget.dart';
import 'package:dnd_listview/dnd/widget/dnd-listview.widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';


typedef DndListenerCallback = bool Function();

class DndListener extends StatelessWidget {
  DndListener({
    Key key,
    this.child,
    this.canStart,
  }) : super(key: key);

  final Widget child;
  final DndListenerCallback canStart;

  @override
  build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerEvent event) => _routePointer(event, context),
      child: child,
    );
  }

  _routePointer(PointerEvent event, BuildContext context) {
    if (canStart == null || canStart()) {
      _startDragging(context: context, event: event);
    }
  }

  _startDragging({BuildContext context, PointerEvent event}) {
    DndItemState state = context.ancestorStateOfType(
        const TypeMatcher<DndItemState>()
    );

    final scrollable = Scrollable.of(context);
    final listState = DndListViewState.of(context);

    if (listState.dragging == null) {
      listState.startDragging(
          key: state.key,
          event: event,
          scrollable: scrollable,
          recognizer: _createRecognizer());
    }
  }

  _createRecognizer() => _Recognizer();
}

class _Recognizer extends MultiDragGestureRecognizer<_VerticalPointerState> {
  _Recognizer() : super(debugOwner: null);

  @override
  createNewPointerState(PointerDownEvent event) => _VerticalPointerState(event.position);

  @override
  String get debugDescription => 'vertical';
}

class _VerticalPointerState extends MultiDragPointerState {

  _VerticalPointerState(Offset initialPosition) : super(initialPosition, PointerDeviceKind.touch) {
    _resolveTimer = Timer(Duration(milliseconds: 150), () {
      resolve(GestureDisposition.accepted);
      _resolveTimer = null;
    });
  }

  Timer _resolveTimer;

  @override
  checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta.dy.abs() > pendingDelta.dx.abs())
      resolve(GestureDisposition.accepted);
  }

  @override
  accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
    _resolveTimer?.cancel();
    _resolveTimer = null;
  }

  dispose() {
    _resolveTimer?.cancel();
    _resolveTimer = null;
    super.dispose();
  }
}

class DelayedDndListener extends DndListener {
  DelayedDndListener({
    Key key,
    Widget child,
    DndListenerCallback canStart,
    this.delay = kLongPressTimeout,
  }) : super(key: key, child: child, canStart: canStart);

  final Duration delay;

  @override
  _createRecognizer() => DelayedMultiDragGestureRecognizer(delay: delay);
}
