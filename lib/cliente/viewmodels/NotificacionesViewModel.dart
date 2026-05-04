import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/NotificacionModel.dart';

class NotificacionesViewModel extends ChangeNotifier {
  List<NotificacionModel> _notificaciones = [];
  bool _isLoading = false;

  List<NotificacionModel> get notificaciones => _notificaciones;
  bool get isLoading => _isLoading;
  int get noLeidasCount => _notificaciones.where((n) => !n.leida).length;
  StreamSubscription? _reportesSubscription;

  NotificacionesViewModel() {
    cargarNotificaciones();
  }

  void iniciarEscuchaReportes(String userId) {
    if (userId.isEmpty) return;
    _reportesSubscription?.cancel();

    try {
      _reportesSubscription = FirebaseFirestore.instance
          .collection('reportes')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final id = doc.id;
            final folio = data['folio'] ?? 'Sin folio';
            final estado = data['estado'] ?? 'pendiente';

            verificarCambioEstado(id, folio, estado);
          } catch (e) {
            if (kDebugMode) {
              print('Error al procesar documento de reporte: $e');
            }
          }
        }
      }, onError: (e) {
        if (kDebugMode) {
          print('Error en stream de reportes para notificaciones: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al iniciar escucha de reportes global: $e');
      }
    }
  }

  @override
  void dispose() {
    _reportesSubscription?.cancel();
    super.dispose();
  }

  Future<void> configurarFCM(String userId) async {
    if (userId.isEmpty) return;

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Solicitar permisos (iOS y Android 13+)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) print('Permiso concedido para notificaciones');

        // 2. Obtener el token
        // En iOS, necesitamos asegurarnos de que el token de APNS esté listo
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          String? apnsToken = await messaging.getAPNSToken();
          if (apnsToken == null) {
            if (kDebugMode) print('Esperando token APNS...');
            // Reintentar un par de veces si es necesario
            await Future.delayed(const Duration(seconds: 2));
            apnsToken = await messaging.getAPNSToken();
          }
          if (kDebugMode) print('APNS Token: $apnsToken');
        }

        String? token = await messaging.getToken();
        
        if (token != null) {
          if (kDebugMode) print('FCM Token: $token');
          
          // 3. Guardar en Firestore
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(userId)
              .set({
                'fcm_token': token,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              
          await FirebaseFirestore.instance
              .collection('tokens')
              .doc(userId)
              .set({
                'token': token,
                'userId': userId,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      } else {
        if (kDebugMode) print('Permiso denegado para notificaciones');
      }
      
      // Escuchar si el token se actualiza
      messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .update({'fcm_token': newToken});
            
        await FirebaseFirestore.instance
            .collection('tokens')
            .doc(userId)
            .set({
              'token': newToken,
              'userId': userId,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      });

    } catch (e) {
      if (kDebugMode) {
        print('Error al configurar FCM: $e');
      }
    }
  }

  // Cargar notificaciones desde SharedPreferences
  Future<void> cargarNotificaciones() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notifJson = prefs.getString('notificaciones_locales');
      
      if (notifJson != null && notifJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(notifJson);
        _notificaciones = decoded
            .map((item) => NotificacionModel.fromMap(item))
            .toList();
            
        // Ordenar por fecha descendente (más recientes primero)
        _notificaciones.sort((a, b) => b.fecha.compareTo(a.fecha));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar notificaciones: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardar notificaciones en SharedPreferences
  Future<void> _guardarNotificaciones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        _notificaciones.map((n) => n.toMap()).toList(),
      );
      await prefs.setString('notificaciones_locales', encoded);
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar notificaciones: $e');
      }
    }
  }

  // Agregar una nueva notificación
  Future<void> agregarNotificacion(NotificacionModel notificacion) async {
    _notificaciones.insert(0, notificacion); // Agregar al inicio
    await _guardarNotificaciones();
    notifyListeners();
  }

  // Marcar una notificación como leída
  Future<void> marcarComoLeida(String id) async {
    final index = _notificaciones.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notificaciones[index] = _notificaciones[index].copyWith(leida: true);
      await _guardarNotificaciones();
      notifyListeners();
    }
  }

  // Marcar todas las notificaciones como leídas
  Future<void> marcarTodasComoLeidas() async {
    _notificaciones = _notificaciones
        .map((n) => n.copyWith(leida: true))
        .toList();
    await _guardarNotificaciones();
    notifyListeners();
  }

  // Limpiar/Eliminar todas las notificaciones
  Future<void> limpiarNotificaciones() async {
    _notificaciones.clear();
    await _guardarNotificaciones();
    notifyListeners();
  }

  // Verificar si un reporte cambió de estado y generar notificación
  Future<void> verificarCambioEstado(String reporteId, String folio, String estadoNuevo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = 'estado_reporte_$reporteId';
      final String? estadoGuardado = prefs.getString(key);

      // Si no hay estado guardado, es la primera vez que lo vemos, guardamos el actual y no notificamos
      if (estadoGuardado == null) {
        await prefs.setString(key, estadoNuevo);
        return;
      }

      // Si el estado cambió
      if (estadoGuardado != estadoNuevo) {
        // Creamos la notificación
        final nuevaNotif = NotificacionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          folio: folio,
          reporteId: reporteId,
          estadoAnterior: estadoGuardado,
          estadoNuevo: estadoNuevo,
          fecha: DateTime.now(),
        );

        // Agregamos la notificación
        await agregarNotificacion(nuevaNotif);

        // Actualizamos el estado guardado
        await prefs.setString(key, estadoNuevo);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar cambio de estado: $e');
      }
    }
  }
}
