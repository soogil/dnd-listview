import 'package:dnd_listview/dnd/widget/dnd-item.widget.dart';
import 'package:dnd_listview/dnd/widget/dnd-listview.widget.dart';
import 'package:dnd_listview/dnd/listeners/dnd-listener.widget.dart';
import 'package:dnd_listview/page/home-page.viewmodel.dart';
import 'package:flutter/material.dart';


class HomePageView extends StatelessWidget {
  HomePageViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    _viewModel ??= HomePageViewModel();

    return Scaffold(
      appBar: _getAppBar(),
      body: _getBody(),
    );
  }

  _getAppBar() {
    return AppBar(title: Text('Dnd ListView',));
  }

  _getBody() {
    return Container(
      child: DndListView(
        controller: _viewModel.dndController,
        initData: _viewModel.items,
        layoutBuilder: (context, items) {
          return ListView.separated(
              controller: _viewModel.scrollController,
              itemCount: items.length,
              separatorBuilder: (context, index) {
                return Container(
                  height: 1,
                  color: Colors.grey,
                );
              },
              itemBuilder: (context, index) {
                return DndItem(
                  itemModel: items[index],
                  childBuilder: (context, item, type) => _getListItem(item));
              });
        },
      ),
    );
  }

  _getListItem(DndItemModel itemModel) {
    return DndListener(
      child: Container(
        height: 50,
        color: Colors.transparent,
        child: Center(
          child: Text(
            itemModel.displayName,
          ),
        ),
      ),
    );
  }
}
