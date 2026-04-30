import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/NotificacionesViewModel.dart';
import '../models/NotificacionModel.dart';
import 'MisReportesScreen.dart';
import '../../shared/utils/constants.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: .8),
                Colors.white.withValues(alpha: .95),
                kPrimaryColor.withValues(alpha: .03),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _buildNotificacionesList(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final notifViewModel = Provider.of<NotificacionesViewModel>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón de regreso
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF880E4F), size: 20),
                ),
              ),

              // Opciones
              Consumer<NotificacionesViewModel>(
                builder: (context, vm, child) {
                  if (vm.notificaciones.isEmpty) return const SizedBox.shrink();
                  
                  return Row(
                    children: [
                      // Marcar todas como leídas
                      if (vm.noLeidasCount > 0)
                        IconButton(
                          icon: const Icon(Icons.done_all, color: Color(0xFF880E4F)),
                          tooltip: 'Marcar todas como leídas',
                          onPressed: () => vm.marcarTodasComoLeidas(),
                        ),
                      const SizedBox(width: 8),
                      // Limpiar
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF880E4F)),
                        tooltip: 'Limpiar notificaciones',
                        onPressed: () => _confirmarLimpieza(context, vm),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notificaciones',
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF880E4F),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<NotificacionesViewModel>(
                    builder: (context, vm, child) {
                      return Text(
                        '${vm.noLeidasCount} sin leer',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blueGrey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificacionesList(BuildContext context) {
    return Consumer<NotificacionesViewModel>(
      builder: (context, vm, child) {
        if (vm.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        if (vm.notificaciones.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No tienes notificaciones',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: vm.notificaciones.length,
          itemBuilder: (context, index) {
            final notif = vm.notificaciones[index];
            return _buildNotificacionCard(context, notif, vm);
          },
        );
      },
    );
  }

  Widget _buildNotificacionCard(BuildContext context, NotificacionModel notif, NotificacionesViewModel vm) {
    final Color colorEstado = _getColorPorEstado(notif.estadoNuevo);
    final IconData iconoEstado = _getIconForEstado(notif.estadoNuevo);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: notif.leida ? Colors.white : const Color(0xFFFFF0F3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: notif.leida ? null : Border.all(color: const Color(0xFFFF80AB), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Marcar como leída
            if (!notif.leida) {
              vm.marcarComoLeida(notif.id);
            }
            // Navegar a MisReportesScreen con el folio
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MisReportesScreen(folioInicial: notif.folio),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono del estado
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(iconoEstado, color: colorEstado, size: 24),
                ),
                const SizedBox(width: 16),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Folio: ${notif.folio}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatearFecha(notif.fecha),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu reporte pasó de ${_getEstadoDisplayText(notif.estadoAnterior)} a ${_getEstadoDisplayText(notif.estadoNuevo)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: notif.leida ? FontWeight.normal : FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Punto de no leído
                if (!notif.leida)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF880E4F),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarLimpieza(BuildContext context, NotificacionesViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Limpiar notificaciones?'),
        content: const Text('Se eliminarán todas las notificaciones de tu historial local.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              vm.limpiarNotificaciones();
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _normalizeEstado(String estado) {
    switch (estado.toLowerCase().trim()) {
      case 'pendiente':
      case 'nuevo':
        return 'pendiente';
      case 'en revision':
      case 'en revisión':
      case 'revision':
        return 'en revisión';
      case 'asignado':
        return 'asignado';
      case 'en proceso':
      case 'en_proceso':
      case 'proceso':
        return 'en proceso';
      case 'resuelto':
      case 'completado':
      case 'terminado':
        return 'resuelto';
      default:
        return estado.toLowerCase();
    }
  }

  String _getEstadoDisplayText(String estado) {
    switch (_normalizeEstado(estado)) {
      case 'pendiente':
        return 'Pendiente';
      case 'en revisión':
        return 'En Revisión';
      case 'asignado':
        return 'Asignado';
      case 'en proceso':
        return 'En Proceso';
      case 'resuelto':
        return 'Resuelto';
      default:
        // Capitalizar primera letra si es un estado desconocido
        if (estado.isEmpty) return 'Pendiente';
        return estado.replaceFirst(estado[0], estado[0].toUpperCase());
    }
  }

  Color _getColorPorEstado(String estado) {
    switch (_normalizeEstado(estado)) {
      case 'pendiente':
        return Colors.grey.shade600;
      case 'en revisión':
        return Colors.orange.shade600;
      case 'asignado':
        return Colors.blue.shade600;
      case 'en proceso':
        return Colors.yellow.shade700;
      case 'resuelto':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getIconForEstado(String estado) {
    switch (_normalizeEstado(estado)) {
      case 'pendiente':
        return Icons.hourglass_empty;
      case 'en revisión':
        return Icons.search;
      case 'asignado':
        return Icons.person_outline;
      case 'en proceso':
        return Icons.build_circle_outlined;
      case 'resuelto':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_none;
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}
