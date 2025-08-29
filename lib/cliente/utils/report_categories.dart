import 'package:flutter/material.dart';

// ASEGURAMOS QUE ESTÉ EN utils/report_categories.dart

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

  // NUEVOS CAMPOS PARA FLEXIBILIDAD DEL MAPA
  final Color? mapMarkerColor;        // Color específico para marcadores del mapa
  final Color? estadoChartColor;      // Color para gráficas de estado
  final double? markerIconSize;       // Tamaño personalizable del icono
  final IconData? alternativeIcon;    // Icono alternativo para el mapa

  const ReportCategory({
    required this.name,
    required this.icon,
    required this.options,
    this.color,
    this.backgroundColor,
    this.description,
    this.mapMarkerColor,
    this.estadoChartColor,
    this.markerIconSize,
    this.alternativeIcon,
  });

  // MÉTODOS PARA OBTENER COLORES EFECTIVOS
  Color getEffectiveMarkerColor() {
    return mapMarkerColor ?? backgroundColor ?? Colors.blue.shade700;
  }

  Color getEffectiveChartColor() {
    return estadoChartColor ?? backgroundColor ?? Colors.grey.shade600;
  }

  IconData getEffectiveMapIcon() {
    return alternativeIcon ?? icon;
  }

  double getEffectiveIconSize() {
    return markerIconSize ?? 40.0;
  }

  // Método para crear una copia con modificaciones (útil para configuraciones dinámicas)
  ReportCategory copyWith({
    String? name,
    IconData? icon,
    List<ReportOption>? options,
    Color? color,
    Color? backgroundColor,
    String? description,
    Color? mapMarkerColor,
    Color? estadoChartColor,
    double? markerIconSize,
    IconData? alternativeIcon,
  }) {
    return ReportCategory(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      options: options ?? this.options,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      description: description ?? this.description,
      mapMarkerColor: mapMarkerColor ?? this.mapMarkerColor,
      estadoChartColor: estadoChartColor ?? this.estadoChartColor,
      markerIconSize: markerIconSize ?? this.markerIconSize,
      alternativeIcon: alternativeIcon ?? this.alternativeIcon,
    );
  }
}

class ReportCategories {
  // CONFIGURACIÓN DE CATEGORÍAS - AHORA CON COLORES ESPECÍFICOS PARA MAPA
  static const List<ReportCategory> categories = [
    ReportCategory(
      name: 'Bacheo',
      icon: Icons.car_crash,
      color: Colors.white,
      backgroundColor: Color(0xFFFF7043), // Naranja para UI
      mapMarkerColor: Color(0xFFE65100),  // Naranja más oscuro para mapa
      description: 'Problemas de pavimento y calles',
      markerIconSize: 42.0, // Ligeramente más grande para bacheo
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
      backgroundColor: Color(0xFFFFA726), // Amarillo/Ámbar para UI
      mapMarkerColor: Color(0xFFF57C00),  // Ámbar más oscuro para mapa
      description: 'Problemas de iluminación urbana',
      alternativeIcon: Icons.lightbulb_outline, // Icono alternativo para mapa
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
      backgroundColor: Color(0xFF66BB6A), // Verde para UI
      mapMarkerColor: Color(0xFF2E7D32),  // Verde más oscuro para mapa
      description: 'Problemas de recolección de basura',
      alternativeIcon: Icons.delete_forever, // Icono más fuerte para mapa
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
      backgroundColor: Color(0xFF42A5F5), // Azul para UI
      mapMarkerColor: Color(0xFF1565C0),  // Azul más oscuro para mapa
      description: 'Problemas de drenaje y alcantarillado',
      alternativeIcon: Icons.water_damage, // Icono más específico para mapa
      markerIconSize: 44.0, // Más grande para drenajes (problema crítico)
      options: [
        ReportOption(description: 'Alcantarilla tapada o bloqueada'),
        ReportOption(description: 'Inundación en la vía pública'),
        ReportOption(description: 'Tapa de alcantarilla faltante'),
        ReportOption(description: 'Malos olores del drenaje'),
        ReportOption(description: 'Otro (especificar)'),
      ],
    ),
  ];

  // MÉTODOS MEJORADOS Y EXTENDIDOS

  // Método para obtener categoría por nombre (con búsqueda flexible)
  static ReportCategory getCategoryByName(String name) {
    // Primero busqueda exacta
    try {
      return categories.firstWhere(
            (category) => category.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      // Búsqueda parcial si no encuentra exacta
      try {
        return categories.firstWhere(
              (category) => category.name.toLowerCase().contains(name.toLowerCase()) ||
              name.toLowerCase().contains(category.name.toLowerCase()),
        );
      } catch (e) {
        // Si no encuentra nada, devolver la primera categoría
        return categories.isNotEmpty ? categories[0] : _getDefaultCategory();
      }
    }
  }

  // Categoría por defecto si no se encuentra ninguna
  static ReportCategory _getDefaultCategory() {
    return const ReportCategory(
      name: 'Otros',
      icon: Icons.report_problem,
      color: Colors.white,
      backgroundColor: Colors.grey,
      mapMarkerColor: Colors.grey,
      description: 'Categoría por defecto',
      options: [
        ReportOption(description: 'Problema no categorizado'),
      ],
    );
  }

  // Obtener todas las categorías activas
  static List<ReportCategory> getActiveCategories() {
    return categories;
  }

  // Obtener todos los nombres de categorías (útil para filtros)
  static List<String> getCategoryNames() {
    return categories.map((category) => category.name).toList();
  }

  // Obtener mapa de colores por categoría (útil para gráficas)
  static Map<String, Color> getCategoryColorMap() {
    final Map<String, Color> colorMap = {};
    for (final category in categories) {
      colorMap[category.name] = category.getEffectiveChartColor();
    }
    return colorMap;
  }

  // Obtener mapa de colores de marcadores por categoría
  static Map<String, Color> getMarkerColorMap() {
    final Map<String, Color> colorMap = {};
    for (final category in categories) {
      colorMap[category.name] = category.getEffectiveMarkerColor();
    }
    return colorMap;
  }

  // Verificar si una categoría existe
  static bool categoryExists(String name) {
    return categories.any(
          (category) => category.name.toLowerCase() == name.toLowerCase(),
    );
  }

  // MÉTODOS PARA UI DINÁMICA

  // Número óptimo de columnas según el número de categorías
  static int getOptimalColumns(int totalCategories) {
    if (totalCategories <= 2) return 1;
    if (totalCategories <= 4) return 2;
    if (totalCategories <= 6) return 2;
    if (totalCategories <= 9) return 3;
    return 3; // Máximo 3 columnas para mejor UX en móviles
  }

  // Calcular proporción del grid
  static double getChildAspectRatio(int totalCategories) {
    if (totalCategories <= 4) return 1.2; // Ligeramente más anchos
    if (totalCategories <= 6) return 1.1; // Casi cuadrados
    return 1.0; // Cuadrados perfectos
  }

  // MÉTODOS PARA CONFIGURACIÓN FUTURA (preparado para persistencia)

  // Obtener configuración serializable (para guardar en SharedPreferences)
  static Map<String, dynamic> getSerializableConfig() {
    return {
      'categories_count': categories.length,
      'categories': categories.map((cat) => {
        'name': cat.name,
        'icon_code': cat.icon.codePoint,
        'background_color': cat.backgroundColor?.value,
        'marker_color': cat.mapMarkerColor?.value,
        'marker_size': cat.markerIconSize,
      }).toList(),
    };
  }
}