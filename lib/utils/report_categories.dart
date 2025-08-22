import 'package:flutter/material.dart';

class ReportOption {
  final String description;

  const ReportOption({required this.description});
}

class ReportCategory {
  final String name;
  final IconData icon;
  final List<ReportOption> options;
  final Color? color;
  final Color? backgroundColor;
  final String? description;

  const ReportCategory({
    required this.name,
    required this.icon,
    required this.options,
    this.color,
    this.backgroundColor,
    this.description,
  });
}

class ReportCategories {
  // Configuración de categorías - FÁCIL DE MODIFICAR
  static const List<ReportCategory> categories = [
    ReportCategory(
      name: 'Bacheo',
      icon: Icons.car_crash,
      color: Colors.white,
      backgroundColor: Color(0xFFFF7043), // Naranja
      description: 'Problemas de pavimento y calles',
      options: [
        ReportOption(description: 'Bache grande que dificulta el tránsito'),
        ReportOption(description: 'Múltiples baches en la zona'),
        ReportOption(description: 'Hundimiento en la calle'),
        ReportOption(description: 'Pavimento agrietado'),
        ReportOption(description: 'Otro (especificar)'),
      ],
    ),
    ReportCategory(
      name: 'Alumbrado Público',
      icon: Icons.lightbulb,
      color: Colors.white,
      backgroundColor: Color(0xFFFFA726), // Amarillo/Ámbar
      description: 'Problemas de iluminación urbana',
      options: [
        ReportOption(description: 'Luminaria apagada'),
        ReportOption(description: 'Luminaria intermitente'),
        ReportOption(description: 'Poste dañado o inclinado'),
        ReportOption(description: 'Cableado expuesto o suelto'),
        ReportOption(description: 'Otro (especificar)'),
      ],
    ),
    ReportCategory(
      name: 'Basura Acumulada',
      icon: Icons.delete,
      color: Colors.white,
      backgroundColor: Color(0xFF66BB6A), // Verde
      description: 'Problemas de recolección de basura',
      options: [
        ReportOption(description: 'Basurero desbordado'),
        ReportOption(description: 'Basura en la vía pública'),
        ReportOption(description: 'No pasó el camión recolector'),
        ReportOption(description: 'Lote baldío con basura'),
        ReportOption(description: 'Otro (especificar)'),
      ],
    ),
    ReportCategory(
      name: 'Drenajes Obstruidos',
      icon: Icons.water_drop,
      color: Colors.white,
      backgroundColor: Color(0xFF42A5F5), // Azul
      description: 'Problemas de drenaje y alcantarillado',
      options: [
        ReportOption(description: 'Alcantarilla tapada o bloqueada'),
        ReportOption(description: 'Inundación en la vía pública'),
        ReportOption(description: 'Tapa de alcantarilla faltante'),
        ReportOption(description: 'Malos olores del drenaje'),
        ReportOption(description: 'Otro (especificar)'),
      ],
    ),
  ];

  // Método para obtener categoría por nombre
  static ReportCategory getCategoryByName(String name) {
    return categories.firstWhere(
          (category) => category.name.toLowerCase() == name.toLowerCase(),
      orElse: () => categories[0], // Default to the first category if not found
    );
  }

  // Método para agregar nuevas categorías dinámicamente (si es necesario en el futuro)
  static List<ReportCategory> getActiveCategories() {
    // Aquí podrías filtrar categorías activas desde una configuración
    return categories;
  }

  // Método para obtener el número óptimo de columnas según el número de categorías
  static int getOptimalColumns(int totalCategories) {
    if (totalCategories <= 2) return 1;
    if (totalCategories <= 4) return 2;
    if (totalCategories <= 6) return 2;
    if (totalCategories <= 9) return 3;
    return 3; // Máximo 3 columnas para mejor UX en móviles
  }

  // Método para calcular la proporción del grid
  static double getChildAspectRatio(int totalCategories) {
    // Ajustar la proporción según el número de categorías
    // Valores más altos = más ancho, valores más bajos = más alto
    if (totalCategories <= 4) return 1.2; // Ligeramente más anchos
    if (totalCategories <= 6) return 1.1; // Casi cuadrados
    return 1.0; // Cuadrados perfectos
  }
}