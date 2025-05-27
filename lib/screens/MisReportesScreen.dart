import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../viewmodels/MisReportesViewModel.dart';

class MisReportesScreen extends StatefulWidget {
  const MisReportesScreen({Key? key}) : super(key: key);

  @override
  State<MisReportesScreen> createState() => _MisReportesScreenState();
}

class _MisReportesScreenState extends State<MisReportesScreen> {
  Future<void> _cargarReportesIniciales(MisReportesViewModel viewModel) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (!authViewModel.isAuthenticated) {
      viewModel.limpiar();
      return;
    }

    await viewModel.cargarReportes(authViewModel.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MisReportesViewModel(),
      child: Consumer<MisReportesViewModel>(
        builder: (context, misReportesVM, child) {
          // Cargar datos solo una vez cuando se crea el ViewModel
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!misReportesVM.isLoading && misReportesVM.reportes.isEmpty) {
              _cargarReportesIniciales(misReportesVM);
            }
          });

          return Scaffold(
            appBar: AppBar(
              title: const Text('Mis Reportes', style: TextStyle(color: kPrimaryColor)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: kPrimaryColor),
            ),
            body: Container(
              decoration: backgroundDecoration,
              child: Column(
                children: [
                  // Filtros
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Todos', misReportesVM.filtroActual == 'Todos', misReportesVM),
                          _buildFilterChip('Pendientes', misReportesVM.filtroActual == 'Pendientes', misReportesVM),
                          _buildFilterChip('En proceso', misReportesVM.filtroActual == 'En proceso', misReportesVM),
                          _buildFilterChip('Resueltos', misReportesVM.filtroActual == 'Resueltos', misReportesVM),
                        ],
                      ),
                    ),
                  ),

                  // Contenido principal
                  Expanded(
                    child: _buildMainContent(context, misReportesVM),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomNavigationBar(),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, MisReportesViewModel misReportesVM) {
    if (misReportesVM.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      );
    }

    if (misReportesVM.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              misReportesVM.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _cargarReportesIniciales(misReportesVM),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final reportesFiltrados = misReportesVM.reportesFiltrados;

    if (reportesFiltrados.isEmpty) {
      return const Center(
        child: Text(
          'No tienes reportes en esta categoría',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargarReportesIniciales(misReportesVM),
      color: kPrimaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reportesFiltrados.length,
        itemBuilder: (context, index) {
          final reporte = reportesFiltrados[index];
          return _buildReportCard(context, reporte);
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, MisReportesViewModel viewModel) {
    return GestureDetector(
      onTap: () {
        viewModel.cambiarFiltro(label);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> reporte) {
    IconData getIconForType(String type) {
      if (type.toLowerCase().contains('basura') || type.toLowerCase().contains('recolección')) {
        return Icons.delete_outline;
      } else if (type.toLowerCase().contains('alumbrado')) {
        return Icons.lightbulb_outline;
      } else if (type.toLowerCase().contains('baches') || type.toLowerCase().contains('bacheo')) {
        return Icons.car_repair;
      } else if (type.toLowerCase().contains('alcantarillado') || type.toLowerCase().contains('drenajes')) {
        return Icons.water_drop;
      }
      return Icons.report_problem_outlined;
    }

    // Crear historial simplificado basado en el estado actual
    List<Map<String, dynamic>> historialEstados = [
      {
        'estado': 'Reporte recibido',
        'fecha': reporte['fecha'],
        'hora': '09:00'
      }
    ];

    if (reporte['estado'].toLowerCase() == 'en proceso') {
      historialEstados.add({
        'estado': 'Asignado al departamento correspondiente',
        'fecha': reporte['fecha'],
        'hora': '10:30'
      });
    } else if (reporte['estado'].toLowerCase() == 'resuelto') {
      historialEstados.add({
        'estado': 'Asignado al departamento correspondiente',
        'fecha': reporte['fecha'],
        'hora': '10:30'
      });
      historialEstados.add({
        'estado': 'Problema solucionado',
        'fecha': reporte['fecha'],
        'hora': '14:45'
      });
    }

    return GestureDetector(
      onTap: () => _mostrarDetalleReporte(context, reporte),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con icono y título
              Row(
                children: [
                  Icon(
                    getIconForType(reporte['tipo']),
                    color: kPrimaryColor,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reporte['tipo'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getColorPorEstado(reporte['estado']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reporte['estado'].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Número de folio
              Text(
                'Folio: ${reporte['folio']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),

              // Descripción
              Text(
                reporte['descripcion'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Ubicación
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reporte['ubicacion'],
                      style: TextStyle(color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Fecha
              Text(
                'Reportado el ${reporte['fecha']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),

              const Divider(height: 24),

              // Seguimiento de estados
              const Text(
                'Seguimiento del reporte',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Estados del reporte
              ...List.generate(historialEstados.length, (index) {
                final estado = historialEstados[index];
                String estadoTexto = estado['estado'] ?? 'Estado desconocido';
                String fechaHora = '${estado['fecha'] ?? reporte['fecha']} • ${estado['hora'] ?? '00:00'}';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              estadoTexto,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              fechaHora,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.location_on, color: Colors.white, size: 28),
                  onPressed: () {},
                ),
                Consumer<AuthViewModel>(
                  builder: (context, authViewModel, _) => IconButton(
                    icon: const Icon(Icons.person, color: Colors.white, size: 28),
                    onPressed: () => _mostrarDialogoCerrarSesion(context, authViewModel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleReporte(BuildContext context, Map<String, dynamic> reporte) {
    // Verificar si el reporte tiene imágenes
    Widget? imagenWidget;
    if (reporte['imagenes'] != null && (reporte['imagenes'] as List).isNotEmpty) {
      // Si hay URLs de imágenes, mostrar la primera
      final imageUrl = (reporte['imagenes'] as List).first;
      imagenWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
          );
        },
      );
    } else if (reporte['foto'] != null && reporte['foto'].toString().isNotEmpty) {
      // Fallback para imágenes en base64 (compatibilidad)
      try {
        final imageBytes = base64Decode(reporte['foto']);
        imagenWidget = Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
        );
      } catch (e) {
        print("Error decodificando imagen: $e");
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reporte #${reporte['folio']}',
              style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mostrar imagen si existe
                if (imagenWidget != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imagenWidget,
                  ),
                  const SizedBox(height: 16),
                ],

                // Fecha y estado
                _buildDetailRow('Fecha', reporte['fecha']),
                _buildDetailRow('Estado', reporte['estado']),

                // Categoría y descripción
                _buildDetailRow('Categoría', reporte['tipo']),
                _buildDetailSection('Comentario', reporte['descripcion']),

                // Ubicación
                _buildDetailSection('Ubicación', reporte['ubicacion']),

                // Datos del denunciante (si no es anónimo)
                if (!(reporte['isAnonymous'] ?? false) && (reporte['nombreCompleto'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  _buildDetailRow('Reportado por', reporte['nombreCompleto']),
                  if ((reporte['telefono'] ?? '').isNotEmpty)
                    _buildDetailRow('Teléfono', reporte['telefono']),
                ],

                // Estadísticas adicionales
                const SizedBox(height: 8),
                const Divider(),
                Consumer<MisReportesViewModel>(
                  builder: (context, misReportesVM, child) {
                    final stats = misReportesVM.obtenerEstadisticas();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estadísticas de tus reportes:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text('Total: ${stats['total']}', style: const TextStyle(fontSize: 12)),
                        Text('Pendientes: ${stats['pendientes']}', style: const TextStyle(fontSize: 12)),
                        Text('En proceso: ${stats['enProceso']}', style: const TextStyle(fontSize: 12)),
                        Text('Resueltos: ${stats['resueltos']}', style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(color: kPrimaryColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getColorPorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
      case 'nuevo':
        return Colors.grey;
      case 'en revision':
      case 'en revisión':
        return Colors.orange;
      case 'asignado':
        return Colors.blue;
      case 'en proceso':
        return Colors.yellow.shade700; // Amarillo más oscuro para mejor contraste
      case 'resuelto':
      case 'completado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _mostrarDialogoCerrarSesion(BuildContext context, AuthViewModel authViewModel) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión', style: TextStyle(color: kPrimaryColor)),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: kPrimaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                await authViewModel.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }
}