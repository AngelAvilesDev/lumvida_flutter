import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class Base64ImageWidget extends StatelessWidget {
  final String base64String;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const Base64ImageWidget({
    Key? key,
    required this.base64String,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.loadingWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    try {
      // Limpiar el base64 si tiene prefijo
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }

      // Validar que no esté vacío
      if (cleanBase64.isEmpty) {
        return _buildErrorWidget();
      }

      // Decodificar Base64
      final Uint8List bytes = base64Decode(cleanBase64);

      if (bytes.isEmpty) {
        return _buildErrorWidget();
      }

      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  Widget _buildErrorWidget() {
    return errorWidget ?? Container(
      width: width ?? 100,
      height: height ?? 100,
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
        size: 40,
      ),
    );
  }
}

// Widget específico para mostrar imágenes de reportes
class ReportImageWidget extends StatelessWidget {
  final String base64String;
  final double size;
  final VoidCallback? onTap;
  final bool showBorder;

  const ReportImageWidget({
    Key? key,
    required this.base64String,
    this.size = 120,
    this.onTap,
    this.showBorder = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: showBorder ? Border.all(color: Colors.grey.shade300) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Base64ImageWidget(
            base64String: base64String,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: Colors.grey.shade100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Colors.grey.shade400,
                    size: size * 0.3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Error al cargar imagen',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: size * 0.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para galería de imágenes de reportes
class ReportImageGallery extends StatelessWidget {
  final List<String> base64Images;
  final double imageSize;
  final Axis scrollDirection;
  final Function(int index, String base64)? onImageTap;

  const ReportImageGallery({
    Key? key,
    required this.base64Images,
    this.imageSize = 120,
    this.scrollDirection = Axis.horizontal,
    this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (base64Images.isEmpty) {
      return Container(
        height: imageSize,
        child: Center(
          child: Text(
            'No hay imágenes disponibles',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: scrollDirection == Axis.horizontal ? imageSize : null,
      child: ListView.builder(
        scrollDirection: scrollDirection,
        itemCount: base64Images.length,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(
              right: scrollDirection == Axis.horizontal ? 8 : 0,
              bottom: scrollDirection == Axis.vertical ? 8 : 0,
            ),
            child: Stack(
              children: [
                ReportImageWidget(
                  base64String: base64Images[index],
                  size: imageSize,
                  onTap: onImageTap != null
                      ? () => onImageTap!(index, base64Images[index])
                      : null,
                ),
                // Número de imagen
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Modal para ver imagen en pantalla completa
class FullScreenImageModal extends StatelessWidget {
  final String base64String;
  final String? title;

  const FullScreenImageModal({
    Key? key,
    required this.base64String,
    this.title,
  }) : super(key: key);

  static void show(BuildContext context, String base64String, {String? title}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FullScreenImageModal(
        base64String: base64String,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Base64ImageWidget(
                  base64String: base64String,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Toca para cerrar',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Utilidades para trabajar con Base64
class Base64ImageUtils {
  // Validar si un string es Base64 válido
  static bool isValidBase64(String base64String) {
    try {
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }

      final decoded = base64Decode(cleanBase64);
      return decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Obtener el tamaño en bytes de una imagen Base64
  static int getBase64ImageSize(String base64String) {
    try {
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }

      return (cleanBase64.length * 3 / 4).round();
    } catch (e) {
      return 0;
    }
  }

  // Formatear tamaño en string legible
  static String formatImageSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '${sizeInBytes}B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(sizeInBytes / 1024 / 1024).toStringAsFixed(1)}MB';
    }
  }

  // Comprimir imagen Base64 (reducir calidad)
  static String compressBase64Image(String base64String, {double quality = 0.7}) {
    // Nota: Esta es una implementación básica
    // En una implementación real, necesitarías usar una librería como image
    // para comprimir realmente la imagen
    return base64String;
  }

  // Obtener información de una imagen Base64
  static Map<String, dynamic> getImageInfo(String base64String) {
    final size = getBase64ImageSize(base64String);
    final isValid = isValidBase64(base64String);
    final hasPrefix = base64String.contains('data:image');

    String format = 'unknown';
    if (base64String.contains('data:image/jpeg')) {
      format = 'JPEG';
    } else if (base64String.contains('data:image/png')) {
      format = 'PNG';
    } else if (base64String.contains('data:image/gif')) {
      format = 'GIF';
    } else if (base64String.contains('data:image/webp')) {
      format = 'WebP';
    }

    return {
      'isValid': isValid,
      'sizeBytes': size,
      'sizeFormatted': formatImageSize(size),
      'format': format,
      'hasDataPrefix': hasPrefix,
      'base64Length': base64String.length,
    };
  }
}