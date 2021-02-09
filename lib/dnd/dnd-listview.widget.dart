import 'package:dnd_listview/dnd/dnd-item.widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'dart:collection';
import 'dart:math';
import 'dart:io';
import 'dart:ui' show lerpDouble;

typedef Widget LayoutBuilder(BuildContext context,  List<AbstractDndItemModel> updatedItemModels);
typedef ItemChangeCallback(AbstractDndItemModel draggedItem, AbstractDndItemModel newPositionItem);
typedef ItemRemoveCallback(AbstractDndItemModel removedItem);
typedef CompleteCallback(List<AbstractDndItemModel> results);
typedef DecoratedPlaceholder DecoratePlaceholder(Widget widget, double decorationOpacity);


class DndListView extends StatefulWidget {
  DndListView({
    Key key,
    @required this.initData,
    @required this.layoutBuilder,
    this.controller,
    this.onItemChanged,
    this.onItemRemoved,
    this.onDone,
    this.cancellationToken,
    this.decoratePlaceholder = _defaultDecoratePlaceholder,
  }) : super(key: key);

  final DndController controller;
  final List<AbstractDndItemModel> initData;
  final LayoutBuilder layoutBuilder;
  final ItemChangeCallback onItemChanged;
  final ItemRemoveCallback onItemRemoved;
  final CompleteCallback onDone;
  final DecoratePlaceholder decoratePlaceholder;
  final CancellationToken cancellationToken;

  @override
  DndListViewState createState() => DndListViewState();
}

class DndListViewState extends State<DndListView> with TickerProviderStateMixin, Drag {

  Key _draggingKey, _tmpDraggingKey, _lastReportedKey;
  MultiDragGestureRecognizer _recognizer;
  ScrollableState _scrollable;
  AnimationController _finalAnimation;

  List<AbstractDndItemModel> _itemModels;
  HashMap<Key, DndItemState> _items;
  Map<Key, AnimationController> _itemTranslations;
  bool _scrolling = false;
  bool _scheduledRebuild = false;

  _DragProxyState _dragProxy;


  List<AbstractDndItemModel> get datas => _itemModels;

  @override
  initState() {
    _itemModels = widget.initData.toList();
    _items = HashMap<Key, DndItemState>();

    _itemTranslations = HashMap();
    _scrolling = false;
    _scheduledRebuild = false;

    if(null != widget.controller) {
      widget.controller.state = this;
    }

    if (widget.cancellationToken != null) {
      widget.cancellationToken.callbacks.add(_cancel);
    }

    super.initState();
  }

  @override
  dispose() {
    if (widget.cancellationToken != null) {
      widget.cancellationToken.callbacks.remove(_cancel);
    }
    _finalAnimation?.dispose();
    for (var controller in _itemTranslations.values) {
      controller.dispose();
    }
    _scrolling = null;
    _recognizer?.dispose();

    super.dispose();
  }

  @override
  build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.layoutBuilder(context, _itemModels),
        _DragProxy(widget.decoratePlaceholder)
      ],
    );
  }

  remove(DndItemState itemState) {
    if (widget.onItemRemoved != null) {
      widget.onItemRemoved(itemState.itemModel);
    }
    _itemModels.remove(itemState.itemModel);

    setState(() {

    });
  }

  _cancel() {
    if (_draggingKey != null) {
      if (_finalAnimation != null) {
        _finalAnimation.dispose();
        _finalAnimation = null;
      }

      _draggingKey = null;
      _dragProxy.hide();

      var current = _items[_draggingKey];
      current?.update();

      if (widget.onDone != null) {
        widget.onDone(_itemModels);
      }
    }
  }

  startDragging({
    Key key,
    PointerEvent event,
    MultiDragGestureRecognizer recognizer,
    ScrollableState scrollable,
  }) {
    _scrollable = scrollable;
    _finalAnimation?.stop(canceled: true);
    _finalAnimation?.dispose();
    _finalAnimation = null;

    if (_draggingKey != null) {
      _items[_draggingKey].update();
      _draggingKey = null;
    }

    _tmpDraggingKey = key;
    _lastReportedKey = null;
    _recognizer?.dispose();
    _recognizer = recognizer;
    _recognizer.onStart = _dragStart;
    _recognizer.addPointer(event);
  }

  Drag _dragStart(Offset position) {
    if (_draggingKey == null && _tmpDraggingKey != null) {
      _draggingKey = _tmpDraggingKey;
      _tmpDraggingKey = null;
    }
    _hapticFeedback();

    final draggedItem = _items[_draggingKey];

    draggedItem.update();

    _dragProxy.setWidget(
        draggedItem.buildChild(draggedItem.context, draggedItem.widget.itemModel, DndItemStateType.DRAG_PROXY),
        draggedItem.context.findRenderObject()
    );

    this._scrollable.position.addListener(this._scrolled);

    return this;
  }

  draggedItemWidgetUpdated() {
    final draggedItem = _items[_draggingKey];

    if (draggedItem != null) {
      _dragProxy.updateWidget(
          draggedItem.buildChild(
              draggedItem.context, draggedItem.widget.itemModel, DndItemStateType.DRAG_PROXY
          )
      );
    }
  }

  _scrolled() {
    checkDragPosition();
  }

  @override
  update(DragUpdateDetails details) {
    _dragProxy.offset += details.delta.dy;
    checkDragPosition();
    maybeScroll();
  }


  maybeScroll() async {
    if (!_scrolling && _scrollable != null && _draggingKey != null) {
      final position = _scrollable.position;

      double newOffset;
      int duration = 14;
      double step = 1.0;
      double overdragMax = 20.0;
      double overdragCoef = 10.0;

      MediaQueryData d = MediaQuery.of(context, nullOk: true);

      double top = d?.padding?.top ?? 0.0;
      double bottom = this._scrollable.position.viewportDimension -
          (d?.padding?.bottom ?? 0.0);

      if (_dragProxy.offset < top &&
          position.pixels > position.minScrollExtent) {
        final overdrag = max(top - _dragProxy.offset, overdragMax);

        newOffset = max(position.minScrollExtent,
            position.pixels - step * overdrag / overdragCoef);

      } else if (_dragProxy.offset + _dragProxy.height > bottom &&
          position.pixels < position.maxScrollExtent) {

        final overdrag = max<double>(
            _dragProxy.offset + _dragProxy.height - bottom, overdragMax);

        newOffset = min(position.maxScrollExtent,
            position.pixels + step * overdrag / overdragCoef);
      }

      if (newOffset != null && (newOffset - position.pixels).abs() >= 1.0) {

        _scrolling = true;
        await this._scrollable.position.animateTo(
            newOffset,
            duration: Duration(milliseconds: duration), curve: Curves.linear
        );

        _scrolling = false;
        if (_draggingKey != null) {
          checkDragPosition();
          maybeScroll();
        }
      }
    }
  }

  @override
  cancel() {
    end(null);
  }

  @override
  end(DragEndDetails details) async {
    if (_draggingKey == null) {
      return;
    }

    _hapticFeedback();
    if (_scrolling) {
      var prevDragging = _draggingKey;
      _draggingKey = null;
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
        _draggingKey = prevDragging;
        end(details);
      });
      return;
    }

    if (_scheduledRebuild) {
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
        if (mounted) end(details);
      });
      return;
    }

    this._scrollable.position.removeListener(this._scrolled);

    var current = _items[_draggingKey];
    if (current == null) return;

    final originalOffset = _itemOffset(current);
    final dragProxyOffset = _dragProxy.offset;

    _dragProxy.updateWidget(
        current.buildChild(
            current.context, current.widget.itemModel, DndItemStateType.DRAG_PROXY_FINISHED
        )
    );

    _finalAnimation = AnimationController(
        vsync: this,
        lowerBound: 0.0,
        upperBound: 1.0,
        value: 0.0,
        duration: Duration(milliseconds: 300));

    _finalAnimation.addListener(() {
      _dragProxy.offset =
          lerpDouble(dragProxyOffset, originalOffset, _finalAnimation.value);
      _dragProxy.decorationOpacity = 1.0 - _finalAnimation.value;
    });

    _recognizer?.dispose();
    _recognizer = null;

    await _finalAnimation.animateTo(1.0, curve: Curves.easeOut);

    if (_finalAnimation != null) {
      _finalAnimation.dispose();
      _finalAnimation = null;

      _draggingKey = null;
      _dragProxy.hide();
      current.update();
      _scrollable = null;

      if (widget.onDone != null) {
        widget.onDone(_itemModels);
      }
    }
  }

  checkDragPosition() {
    if (_scheduledRebuild) {
      return;
    }
    final draggingState = _items[_draggingKey];
    if (draggingState == null) {
      return;
    }

    final draggingTop = _itemOffset(draggingState);
    final draggingHeight = draggingState.context.size.height;

    DndItemState closest;
    double closestDistance = 0.0;

    List<Function> onApproved = List();

    if (_dragProxy.offset < draggingTop) {
      for (DndItemState item in _items.values) {
        if (item.key == _draggingKey)
          continue;

        final itemTop = _itemOffset(item);

        if (itemTop > draggingTop)
          continue;

        final itemBottom = itemTop +
            (item.context.findRenderObject() as RenderBox).size.height / 2;

        if (_dragProxy.offset < itemBottom) {
          onApproved.add(() {
            _adjustItemTranslation(item.key, -draggingHeight, draggingHeight);
          });

          if (closest == null ||
              closestDistance > (itemBottom - _dragProxy.offset)) {
            closest = item;
            closestDistance = (itemBottom - _dragProxy.offset);
          }
        }
      }
    } else {
      double draggingBottom = _dragProxy.offset + draggingHeight;

      for (DndItemState item in _items.values) {
        if (item.key == _draggingKey)
          continue;

        final itemTop = _itemOffset(item);

        if (itemTop < draggingTop)
          continue;

        final itemBottom = itemTop +
            (item.context.findRenderObject() as RenderBox).size.height / 2;

        if (draggingBottom > itemBottom) {
          onApproved.add(() {
            _adjustItemTranslation(item.key, draggingHeight, draggingHeight);
          });

          if (closest == null ||
              closestDistance > (draggingBottom - itemBottom)) {
            closest = item;
            closestDistance = draggingBottom - itemBottom;
          }
        }
      }
    }

    if (closest != null &&
        closest.key != _draggingKey &&
        closest.key != _lastReportedKey) {
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
        _scheduledRebuild = false;
      });
      _scheduledRebuild = true;
      _lastReportedKey = closest.key;
        if (_onItemChanged(_draggingKey, closest.key)) {
          if (Platform.isIOS) {
            _hapticFeedback();
          }
          for (var func in onApproved) {
            func();
          }
          _lastReportedKey = null;
      }
    }
  }

  bool _onItemChanged(Key item, Key newPosition){
    final int draggingIndex = _indexOfKey(item);
    final int newPositionIndex = _indexOfKey(newPosition);
    final draggedItem = _itemModels[draggingIndex];
    final newPositionItem = _itemModels[newPositionIndex];

    if (widget.onItemChanged != null) {
      widget.onItemChanged(draggedItem, newPositionItem);
    }

    setState(() {
      _itemModels.removeAt(draggingIndex);
      _itemModels.insert(newPositionIndex, draggedItem);
    });
    return true;
  }

  int _indexOfKey(Key key) {
    return _itemModels.indexWhere((AbstractDndItemModel m) => m.key == key);
  }

  _hapticFeedback() {
    HapticFeedback.lightImpact();
  }

  registerItem(DndItemState item) {
    _items[item.key] = item;
  }

  unregisterItem(DndItemState item) {
    if (_items[item.key] == item) _items.remove(item.key);
  }

  _itemOffset(DndItemState item) {
    final topRenderBox = context.findRenderObject() as RenderBox;

    return (item.context.findRenderObject() as RenderBox)
        .localToGlobal(Offset.zero, ancestor: topRenderBox)
        .dy;
  }

  itemTranslation(Key key) {
    if (!_itemTranslations.containsKey(key))
      return 0.0;
    else
      return _itemTranslations[key].value;
  }

  _adjustItemTranslation(Key key, double delta, double max) {
    double current = 0.0;
    final currentController = _itemTranslations[key];
    if (currentController != null) {
      current = currentController.value;
      currentController.stop(canceled: true);
      currentController.dispose();
    }

    current += delta;

    final newController = AnimationController(
        vsync: this,
        lowerBound: current < 0.0 ? -max : 0.0,
        upperBound: current < 0.0 ? 0.0 : max,
        value: current,
        duration: const Duration(milliseconds: 300));
    newController.addListener(() {
      _items[key]?.setState(() {}); // update offset
    });
    newController.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
        newController.dispose();
        if (_itemTranslations[key] == newController) {
          _itemTranslations.remove(key);
        }
      }
    });
    _itemTranslations[key] = newController;

    newController.animateTo(0.0, curve: Curves.easeInOut);
  }

  Key get dragging => _draggingKey;

  static DndListViewState of(BuildContext context) {
    return context.ancestorStateOfType(const TypeMatcher<DndListViewState>());
  }
}


class _DragProxy extends StatefulWidget {
  _DragProxy(this.decoratePlaceholder);

  final DecoratePlaceholder decoratePlaceholder;

  @override
  State<StatefulWidget> createState() => _DragProxyState();
}

class _DragProxyState extends State<_DragProxy> {
  Widget _widget;
  Size _size;
  double _offset;
  double _offsetX;
  double _decorationOpacity;

  @override
  build(BuildContext context) {
    DndListViewState.of(context)?._dragProxy = this;

    if (_widget != null && _size != null && _offset != null) {

      final Widget child = IgnorePointer(
        child: MediaQuery.removePadding(
          context: context,
          child: _widget,
          removeTop: true,
          removeBottom: true,
        ),
      );

      final decoratedPlaceholder = widget.decoratePlaceholder(child, _decorationOpacity);

      return Positioned(
        child: decoratedPlaceholder.widget,
        left: _offsetX,
        width: _size.width,
        top: offset - decoratedPlaceholder.offset,
      );
    } else {
      return Container(
          width: 0.0,
          height: 0.0
      );
    }
  }

  @override
  deactivate() {
    DndListViewState.of(context)?._dragProxy = null;

    super.deactivate();
  }

  setWidget(Widget widget, RenderBox position) {
    setState(() {
      final DndListViewState state = DndListViewState.of(context);
      final RenderBox renderBox = state.context.findRenderObject();
      final Offset offset = position.localToGlobal(Offset.zero, ancestor: renderBox);

      _decorationOpacity = 1.0;
      _widget = widget;
      _offsetX = offset.dx;
      _offset = offset.dy;
      _size = position.size;
    });
  }

  updateWidget(Widget widget) {
    _widget = widget;
  }

  hide() {
    setState(() {
      _widget = null;
    });
  }

  get offset => _offset;
  get height => _size.height;

  set offset(double newOffset) {
    setState(() {
      _offset = newOffset;
    });
  }

  set decorationOpacity(double val) {
    setState(() {
      _decorationOpacity = val;
    });
  }
}


class CancellationToken {
  CancellationToken(){
    _callbacks = List<VoidCallback>();
  }

  List<VoidCallback> _callbacks;

  cancelDragging() {
    for (VoidCallback callback in _callbacks) {
      callback();
    }
  }

  List get callbacks =>  _callbacks;
}

class DecoratedPlaceholder {
  DecoratedPlaceholder({
    this.offset,
    this.widget,
  });

  final double offset;
  final Widget widget;
}

class DndController {

  DndListViewState _state;

  set state(DndListViewState value) {
    _state = value;
  }

  List<AbstractDndItemModel> get datas => _state.datas;
}


DecoratedPlaceholder _defaultDecoratePlaceholder(Widget widget, double decorationOpacity) {

  final double decorationHeight = 10.0;
  final decoratedWidget = Builder(builder: (BuildContext context) {

    final ratio = MediaQuery.of(context).devicePixelRatio;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Opacity(
              opacity: decorationOpacity,
              child: Container(
                height: decorationHeight,
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: Color(0x50000000),
                            width: 1.0 / ratio)),
                    gradient: LinearGradient(
                        begin: Alignment(0.0, -1.0),
                        end: Alignment(0.0, 1.0),
                        colors: <Color>[
                          Color(0x00000000),
                          Color(0x10000000),
                          Color(0x30000000)
                        ])),
              )),
          widget,
          Opacity(
              opacity: decorationOpacity,
              child: Container(
                height: decorationHeight,
                decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: Color(0x50000000),
                            width: 1.0 / ratio)),
                    gradient: LinearGradient(
                        begin: Alignment(0.0, -1.0),
                        end: Alignment(0.0, 1.0),
                        colors: <Color>[
                          Color(0x30000000),
                          Color(0x10000000),
                          Color(0x00000000)
                        ])),
              )),
        ]);
  });

  return DecoratedPlaceholder(
      offset: decorationHeight, widget: decoratedWidget);
}