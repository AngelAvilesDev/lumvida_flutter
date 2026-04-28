import 'package:flutter_test/flutter_test.dart';
import 'package:lumvida_app/cliente/models/ReporteModel.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Clase Fake para simular DocumentSnapshot de Firestore
class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic operator [](Object key) => _data?[key];
}

// Función auxiliar para probar la lógica de deduplicación del Grupo 3
ReporteModel? buscarReporteDuplicado({
  required double latitud,
  required double longitud,
  required String categoria,
  required List<ReporteModel> reportesExistentes,
}) {
  if (reportesExistentes.isEmpty) return null;

  for (final reporte in reportesExistentes) {
    if (reporte.categoria != categoria) continue;
    if (reporte.estado.toLowerCase() == 'resuelto') continue;

    final distancia = reporte.distanciaA(LatLng(latitud, longitud));
    if (distancia <= 0.1) {
      return reporte;
    }
  }

  return null;
}

void main() {
  group('GRUPO 1 — ReporteModel campos nuevos', () {
    test('fromFirestore devuelve duplicados=0 cuando el campo no existe en el doc', () {
      final doc = FakeDocumentSnapshot('test-id', {
        'folio': 'REP-123',
        'categoria': 'Bache',
        'comentario': 'Bache grande',
        'direccion': 'Calle 1',
        'latitud': 21.1743,
        'longitud': -86.8466,
        'estado': 'pendiente',
        'fecha': Timestamp.now(),
        'userId': 'user-1',
        'nombreCompleto': 'Juan Pérez',
        'telefono': '1234567890',
      });

      final reporte = ReporteModel.fromFirestore(doc);
      expect(reporte.duplicados, 0);
    });

    test('fromFirestore lee duplicados=3 cuando el campo existe', () {
      final doc = FakeDocumentSnapshot('test-id', {
        'folio': 'REP-123',
        'categoria': 'Bache',
        'comentario': 'Bache grande',
        'direccion': 'Calle 1',
        'latitud': 21.1743,
        'longitud': -86.8466,
        'estado': 'pendiente',
        'fecha': Timestamp.now(),
        'userId': 'user-1',
        'nombreCompleto': 'Juan Pérez',
        'telefono': '1234567890',
        'duplicados': 3,
      });

      final reporte = ReporteModel.fromFirestore(doc);
      expect(reporte.duplicados, 3);
    });

    test('toMap incluye los campos duplicados, reportesRelacionados, esDuplicadoDe', () {
      final fecha = DateTime.now();
      final reporte = ReporteModel(
        id: 'test-id',
        folio: 'REP-123',
        categoria: 'Bache',
        descripcion: 'Bache grande',
        direccion: 'Calle 1',
        latitud: 21.1743,
        longitud: -86.8466,
        estado: 'pendiente',
        fecha: fecha,
        userId: 'user-1',
        nombreCompleto: 'Juan Pérez',
        telefono: '1234567890',
        duplicados: 2,
        reportesRelacionados: ['rep-456'],
        esDuplicadoDe: 'rep-original',
      );

      final map = reporte.toMap();
      expect(map['duplicados'], 2);
      expect(map['reportesRelacionados'], ['rep-456']);
      expect(map['esDuplicadoDe'], 'rep-original');
    });

    test('copyWith actualiza correctamente duplicados y reportesRelacionados', () {
      final reporte = ReporteModel(
        id: 'test-id',
        folio: 'REP-123',
        categoria: 'Bache',
        descripcion: 'Bache grande',
        direccion: 'Calle 1',
        latitud: 21.1743,
        longitud: -86.8466,
        estado: 'pendiente',
        fecha: DateTime.now(),
        userId: 'user-1',
        nombreCompleto: 'Juan Pérez',
        telefono: '1234567890',
      );

      final reporteCopiado = reporte.copyWith(
        duplicados: 5,
        reportesRelacionados: ['rep-789'],
      );

      expect(reporteCopiado.duplicados, 5);
      expect(reporteCopiado.reportesRelacionados, ['rep-789']);
      expect(reporteCopiado.folio, 'REP-123');
    });
  });

  group('GRUPO 2 — distanciaA()', () {
    test('distancia entre mismas coordenadas es 0', () {
      final reporte = ReporteModel(
        id: 'test-id',
        folio: 'REP-123',
        categoria: 'Bache',
        descripcion: 'Bache grande',
        direccion: 'Calle 1',
        latitud: 21.1743,
        longitud: -86.8466,
        estado: 'pendiente',
        fecha: DateTime.now(),
        userId: 'user-1',
        nombreCompleto: 'Juan Pérez',
        telefono: '1234567890',
      );

      final distancia = reporte.distanciaA(LatLng(21.1743, -86.8466));
      expect(distancia, 0.0);
    });

    test('distancia entre (21.1743, -86.8466) y (21.1743, -86.8475) es aproximadamente 0.083 km', () {
      final reporte = ReporteModel(
        id: 'test-id',
        folio: 'REP-123',
        categoria: 'Bache',
        descripcion: 'Bache grande',
        direccion: 'Calle 1',
        latitud: 21.1743,
        longitud: -86.8466,
        estado: 'pendiente',
        fecha: DateTime.now(),
        userId: 'user-1',
        nombreCompleto: 'Juan Pérez',
        telefono: '1234567890',
      );

      final distancia = reporte.distanciaA(LatLng(21.1743, -86.8475));
      expect(distancia, closeTo(0.083, 0.01));
      expect(distancia < 0.1, isTrue);
    });

    test('distancia entre (21.1743, -86.8466) y (21.1800, -86.8466) es aproximadamente 0.63 km', () {
      final reporte = ReporteModel(
        id: 'test-id',
        folio: 'REP-123',
        categoria: 'Bache',
        descripcion: 'Bache grande',
        direccion: 'Calle 1',
        latitud: 21.1743,
        longitud: -86.8466,
        estado: 'pendiente',
        fecha: DateTime.now(),
        userId: 'user-1',
        nombreCompleto: 'Juan Pérez',
        telefono: '1234567890',
      );

      final distancia = reporte.distanciaA(LatLng(21.1800, -86.8466));
      expect(distancia, closeTo(0.63, 0.05));
      expect(distancia > 0.1, isTrue);
    });

    test('tieneUbicacionValida retorna false cuando latitud y longitud son 0.0', () {
      final reporte = ReporteModel(
        id: 'test-id',
        folio: 'REP-123',
        categoria: 'Bache',
        descripcion: 'Bache grande',
        direccion: 'Calle 1',
        latitud: 0.0,
        longitud: 0.0,
        estado: 'pendiente',
        fecha: DateTime.now(),
        userId: 'user-1',
        nombreCompleto: 'Juan Pérez',
        telefono: '1234567890',
      );

      expect(reporte.tieneUbicacionValida, isFalse);
    });
  });

  group('GRUPO 3 — Lógica de deduplicación', () {
    test('buscarReporteDuplicado retorna null cuando la lista de reportes está vacía', () {
      final resultado = buscarReporteDuplicado(
        latitud: 21.1743,
        longitud: -86.8466,
        categoria: 'Bache',
        reportesExistentes: [],
      );

      expect(resultado, isNull);
    });

    test('buscarReporteDuplicado retorna null cuando todos los reportes están en estado \'resuelto\'', () {
      final reporteResuelto = ReporteModel(
        id: 'rep-1',
        folio: 'REP-1',
        categoria: 'Bache',
        descripcion: 'Bache 1',
        direccion: 'Calle 1',
        latitud: 21.1743,
        longitud: -86.8466,
        estado: 'resuelto',
        fecha: DateTime.now(),
        userId: 'user-1',
        nombreCompleto: 'Juan',
        telefono: '123',
      );

      final resultado = buscarReporteDuplicado(
        latitud: 21.1743,
        longitud: -86.8466,
        categoria: 'Bache',
        reportesExistentes: [reporteResuelto],
      );

      expect(resultado, isNull);
    });

    test('buscarReporteDuplicado retorna el reporte cuando hay uno activo dentro del radio', () {
      final reporteActivo = ReporteModel(
        id: 'rep-1',
        folio: 'REP-1',
        categoria: 'Bache',
        descripcion: 'Bache 1',
        direccion: 'Calle 1',
        latitud: 21.1743,
        longitud: -86.8466,
        estado: 'pendiente',
        fecha: DateTime.now(),
        userId: 'user-1',
        nombreCompleto: 'Juan',
        telefono: '123',
      );

      final resultado = buscarReporteDuplicado(
        latitud: 21.1743,
        longitud: -86.8475,
        categoria: 'Bache',
        reportesExistentes: [reporteActivo],
      );

      expect(resultado, isNotNull);
      expect(resultado!.id, 'rep-1');
    });

    test('buscarReporteDuplicado retorna null cuando el reporte activo está fuera del radio', () {
      final reporteActivo = ReporteModel(
        id: 'rep-1',
        folio: 'REP-1',
        categoria: 'Bache',
        descripcion: 'Bache 1',
        direccion: 'Calle 1',
        latitud: 21.1743,
        longitud: -86.8466,
        estado: 'pendiente',
        fecha: DateTime.now(),
        userId: 'user-1',
        nombreCompleto: 'Juan',
        telefono: '123',
      );

      final resultado = buscarReporteDuplicado(
        latitud: 21.1800,
        longitud: -86.8466,
        categoria: 'Bache',
        reportesExistentes: [reporteActivo],
      );

      expect(resultado, isNull);
    });
  });
}
