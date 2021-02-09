import 'package:dnd_listview/dnd/dnd-listview.widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum DndItemStateType {
  NORMAL,
  PLACEHOLDER,
  DRAG_PROXY,
  DRAG_PROXY_FINISHED,
  REMOVE
}

typedef Widget DndItemChildBuilder(
    BuildContext context, AbstractDndItemModel itemModel, DndItemStateType state);

class DndItem extends StatefulWidget {
  DndItem({
    @required this.itemModel,
    @required this.childBuilder,
  }) : super(key: itemModel.key);

  final DndItemChildBuilder childBuilder;
  final AbstractDndItemModel itemModel;

  @override
  DndItemState createState() => DndItemState();
}

class DndItemState extends State<DndItem> {
  DndListViewState _listState;
  AbstractDndItemModel _itemModel;
  bool _isRemoved;
  Duration _animatedDuration;

  @override
  void initState() {
    _itemModel = widget.itemModel;
    _isRemoved = false;
    _animatedDuration = const Duration();
    super.initState();
  }

  @override
  build(BuildContext context) {
    _listState = DndListViewState.of(context);
    _listState.registerItem(this);

    final bool dragging = _listState.dragging == key;
    final double translation = _listState.itemTranslation(key);

    return Transform(
      transform: Matrix4.translationValues(0.0, translation, 0.0),
      child: buildChild(
          context,
          widget.itemModel,
          _isRemoved ? DndItemStateType.REMOVE
              : dragging
              ? DndItemStateType.PLACEHOLDER
              : DndItemStateType.NORMAL),
    );
  }

  buildChild(BuildContext context, AbstractDndItemModel itemModel, DndItemStateType state){
    return AnimatedOpacity(
      duration: _animatedDuration,
      opacity: state == DndItemStateType.PLACEHOLDER
          || state == DndItemStateType.REMOVE
          ? 0.0 : 1.0,
      child: widget.childBuilder(context, itemModel, state)
    );
  }

  @override
  didUpdateWidget(DndItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    _listState = DndListViewState.of(context);

    if (_listState.dragging == this.key) {
      _listState.draggedItemWidgetUpdated();
    }
  }

  remove(Duration duration){
    _isRemoved = true;
    _animatedDuration = duration;

    update();

    Future.delayed(duration).then((_){
      _listState.remove(this);
    });
  }

  update() {
    setState(() {});
  }

  @override
  deactivate() {
    _listState?.unregisterItem(this);
    _listState = null;

    super.deactivate();
  }

  Key get key => widget.key;
  AbstractDndItemModel get itemModel => _itemModel;
}


abstract class AbstractDndItemModel<T> {
  AbstractDndItemModel(this.key, this.data);

  final T data;
  final Key key;

  @override
  String toString() {
    // TODO: implement toString
    return '$key, ${data.toString()}';
  }
}