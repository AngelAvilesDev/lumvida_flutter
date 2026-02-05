import 'package:flutter/material.dart';
import 'package:lumvida_app/cliente/utils/report_categories.dart';
import 'package:lumvida_app/cliente/components/CategoryCard.dart';

class CategoriesGrid extends StatelessWidget {
  final List<ReportCategory> categories;
  final int columns;
  final double aspectRatio;

  const CategoriesGrid({
    Key? key,
    required this.categories,
    required this.columns,
    required this.aspectRatio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return CategoryCard(
          category: category,
          index: index,
        );
      },
    );
  }
}
