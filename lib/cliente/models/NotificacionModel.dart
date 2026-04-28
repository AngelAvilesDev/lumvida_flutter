class NotificacionModel {
  final String id;
  final String folio;
  final String reporteId;
  final String estadoAnterior;
  final String estadoNuevo;
  final DateTime fecha;
  final bool leida;

  NotificacionModel({
    required this.id,
    required this.folio,
    required this.reporteId,
    required this.estadoAnterior,
    required this.estadoNuevo,
    required this.fecha,
    this.leida = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'reporteId': reporteId,
      'estadoAnterior': estadoAnterior,
      'estadoNuevo': estadoNuevo,
      'fecha': fecha.toIso8601String(),
      'leida': leida,
    };
  }

  factory NotificacionModel.fromMap(Map<String, dynamic> map) {
    return NotificacionModel(
      id: map['id'] ?? '',
      folio: map['folio'] ?? '',
      reporteId: map['reporteId'] ?? '',
      estadoAnterior: map['estadoAnterior'] ?? '',
      estadoNuevo: map['estadoNuevo'] ?? '',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      leida: map['leida'] ?? false,
    );
  }

  NotificacionModel copyWith({
    String? id,
    String? folio,
    String? reporteId,
    String? estadoAnterior,
    String? estadoNuevo,
    DateTime? fecha,
    bool? leida,
  }) {
    return NotificacionModel(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      reporteId: reporteId ?? this.reporteId,
      estadoAnterior: estadoAnterior ?? this.estadoAnterior,
      estadoNuevo: estadoNuevo ?? this.estadoNuevo,
      fecha: fecha ?? this.fecha,
      leida: leida ?? this.leida,
    );
  }
}
