import 'package:flutter/material.dart';
import '../../core/namkeen_theme.dart';
import 'category_list.dart';
import 'size_list.dart';

class ManageAttributesScreen extends StatelessWidget {
  const ManageAttributesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Product Attributes'),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primary,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Categories', icon: Icon(Icons.category)),
              Tab(text: 'Sizes / Weights', icon: Icon(Icons.scale)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CategoryList(),
            SizeList(),
          ],
        ),
      ),
    );
  }
}
