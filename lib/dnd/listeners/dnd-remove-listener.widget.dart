import 'package:dnd_listview/dnd/dnd-item.widget.dart';
import 'package:dnd_listview/dnd/dnd-listview.widget.dart';
import 'package:flutter/material.dart';

class DndRemoveListener extends StatelessWidget {
  DndRemoveListener({
    Key key,
    this.child,
    this.removedDuration = const Duration(milliseconds: 300)
  }) : super(key: key);

  final Widget child;
  final Duration removedDuration;

  @override
  build(BuildContext context) {

    return FlatButton(
      child: child,
      onPressed: ()=> _onPressed(context)
    );
  }

  _onPressed(BuildContext context) {
    DndItemState state = context.ancestorStateOfType(
        const TypeMatcher<DndItemState>()
    );

    state.remove(removedDuration);
  }
}