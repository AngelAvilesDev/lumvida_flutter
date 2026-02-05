import 'package:flutter/material.dart';
import 'package:lumvida_app/shared/utils/constants.dart';
import 'package:lumvida_app/cliente/utils/report_categories.dart';
import 'package:lumvida_app/cliente/screens/ReportesScreen.dart';

class CategoryCard extends StatelessWidget {
  final ReportCategory category;
  final int index;

  const CategoryCard({
    Key? key,
    required this.category,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Valores por defecto si no están definidos
    final backgroundColor = category.backgroundColor ?? kPrimaryColor;
    final textColor = category.color ?? Colors.white;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportesScreen(
                        categoria: category.name,
                        categoriaDetectadaPorIA: null,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, // Importante: usar min
                    children: [
                      // Icono
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          category.icon,
                          color: textColor,
                          size: 28,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Título - Solo el nombre, sin descripción extra
                      Flexible(
                        child: Text(
                          category.name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
