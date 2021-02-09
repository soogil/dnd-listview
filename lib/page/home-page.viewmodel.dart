import 'package:dnd_listview/dnd/dnd-item.widget.dart';
import 'package:dnd_listview/dnd/dnd-listview.widget.dart';
import 'package:flutter/material.dart';


class HomePageViewModel {

  HomePageViewModel() {
    _scrollController = ScrollController();
    _dndController = DndController();
    _items = [];

    int index = 0;
    for(; index < 50; index++) {
      _items.add(DndItemModel(
        key: Key(index.toString()),
        displayName: index.toString(),
      ));
    }
  }

  List<DndItemModel> _items;
  ScrollController _scrollController;
  DndController _dndController;

  List<DndItemModel> get items => _items;

  ScrollController get scrollController => _scrollController;

  DndController get dndController => _dndController;
}


class DndItemModel extends AbstractDndItemModel {
  DndItemModel({Key key, this.displayName}) : super(key, displayName);

  final String displayName;
}