import 'package:flutter/material.dart';

class ReportOption {
  final String description;

  const ReportOption({required this.description});
}

class ReportCategory {
  final String name;
  final IconData icon;
  final List<ReportOption> options;

  const ReportCategory({
    required this.name,
    required this.icon,
    required this.options
  });
}

class ReportCategories {
  static const List<ReportCategory> categories = [
    ReportCategory(
      name: 'Bacheo',
      icon: Icons.car_repair,
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
      icon: Icons.lightbulb_outline,
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
      icon: Icons.delete_outline,
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
      options: [
        ReportOption(description: 'Alcantarilla tapada o bloqueada'),
        ReportOption(description: 'Inundación en la vía pública'),
        ReportOption(description: 'Tapa de alcantarilla faltante'),
        ReportOption(description: 'Malos olores del drenaje'),
        ReportOption(description: 'Otro (especificar)'),
      ],
    ),
  ];

  static ReportCategory getCategoryByName(String name) {
    return categories.firstWhere(
          (category) => category.name.toLowerCase() == name.toLowerCase(),
      orElse: () => categories[0], // Default to the first category if not found
    );
  }
}