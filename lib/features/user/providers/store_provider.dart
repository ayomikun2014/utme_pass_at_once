import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/features/user/models/store_item.dart';
class StoreProvider extends ChangeNotifier{
  StoreItem? _selectedItem;

  StoreItem? get selectedItem => _selectedItem;

  void selectItem(StoreItem item){
    _selectedItem = item;
    notifyListeners();
  }
}

