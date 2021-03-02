import 'package:dnd_listview/page/home-page.view.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(DnDListApp());
}

class DnDListApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePageView(),
    );
  }
}
