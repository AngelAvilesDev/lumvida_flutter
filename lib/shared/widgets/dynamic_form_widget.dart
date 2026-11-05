import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/dynamic_schema/tenant_config_model.dart';

class DynamicFormWidget extends StatefulWidget {
  final List<FormFieldSchema> fields;
  final Map<String, dynamic> initialValues;
  final void Function(Map<String, dynamic> values, bool isValid) onChanged;

  const DynamicFormWidget({
    Key? key,
    required this.fields,
    this.initialValues = const {},
    required this.onChanged,
  }) : super(key: key);

  @override
  State<DynamicFormWidget> createState() => _DynamicFormWidgetState();
}

class _DynamicFormWidgetState extends State<DynamicFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _values = {};
  final Map<String, List<File>> _selectedFiles = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Inicializar valores por defecto o valores iniciales
    for (final field in widget.fields) {
      if (widget.initialValues.containsKey(field.key)) {
        _values[field.key] = widget.initialValues[field.key];
      } else if (field.defaultValue != null) {
        _values[field.key] = field.defaultValue;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChange());
  }

  // Notificar al padre el estado actual y validez del formulario
  void _notifyChange() {
    final isValid = _validateAll();
    widget.onChanged(Map<String, dynamic>.from(_values), isValid);
  }

  // Comprobar visibilidad según reglas de dependencia lógica
  bool _isFieldVisible(FormFieldSchema field) {
    if (field.dependsOn == null) return true;
    final parentValue = _values[field.dependsOn!.fieldKey];
    return field.dependsOn!.evaluate(parentValue);
  }

  // Validación espejo completa para habilitar o deshabilitar envío
  bool _validateAll() {
    for (final field in widget.fields) {
      if (!_isFieldVisible(field)) continue;

      final val = _values[field.key];
      final rules = field.validation;

      if (rules.required) {
        if (field.type == 'file') {
          final files = _selectedFiles[field.key] ?? [];
          if (files.isEmpty) return false;
          if (rules.minFiles != null && files.length < rules.minFiles!) return false;
        } else if (field.type == 'boolean') {
          if (val == null) return false;
        } else {
          if (val == null || val.toString().trim().isEmpty) return false;
        }
      }

      if (val is String && val.isNotEmpty) {
        if (rules.minLength != null && val.length < rules.minLength!) return false;
        if (rules.maxLength != null && val.length > rules.maxLength!) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.fields.map((field) {
          if (!_isFieldVisible(field)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildFieldWidget(field),
          );
        }).toList(),
      ),
    );
  }

  // Factoría de renderizado según el tipo de campo
  Widget _buildFieldWidget(FormFieldSchema field) {
    switch (field.type) {
      case 'textarea':
        return _buildTextFormField(field, maxLines: 4);
      case 'number':
        return _buildTextFormField(field, keyboardType: TextInputType.number);
      case 'select':
        return _buildSelectFormField(field);
      case 'boolean':
        return _buildBooleanFormField(field);
      case 'date':
        return _buildDateFormField(field);
      case 'file':
        return _buildFileFormField(field);
      case 'text':
      default:
        return _buildTextFormField(field);
    }
  }

  // Renderizar campos de texto y áreas de texto
  Widget _buildTextFormField(
    FormFieldSchema field, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label + (field.validation.required ? ' *' : ''),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _values[field.key]?.toString(),
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: field.placeholder,
            helperText: field.helpText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (text) {
            setState(() {
              _values[field.key] = text;
            });
            _notifyChange();
          },
        ),
      ],
    );
  }

  // Renderizar selector de opciones (dropdown)
  Widget _buildSelectFormField(FormFieldSchema field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label + (field.validation.required ? ' *' : ''),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _values[field.key]?.toString(),
          hint: Text(field.placeholder ?? 'Selecciona una opción'),
          items: field.options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt.value,
              child: Text(opt.label),
            );
          }).toList(),
          onChanged: (selected) {
            setState(() {
              _values[field.key] = selected;
            });
            _notifyChange();
          },
          decoration: InputDecoration(
            helperText: field.helpText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  // Renderizar interruptor booleano
  Widget _buildBooleanFormField(FormFieldSchema field) {
    final isChecked = (_values[field.key] as bool?) ?? false;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        title: Text(
          field.label + (field.validation.required ? ' *' : ''),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: field.helpText != null ? Text(field.helpText!, style: const TextStyle(fontSize: 12)) : null,
        value: isChecked,
        onChanged: (bool newVal) {
          setState(() {
            _values[field.key] = newVal;
          });
          _notifyChange();
        },
      ),
    );
  }

  // Renderizar selector de fecha
  Widget _buildDateFormField(FormFieldSchema field) {
    final currentDateStr = _values[field.key]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label + (field.validation.required ? ' *' : ''),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() {
                _values[field.key] = picked.toIso8601String().split('T').first;
              });
              _notifyChange();
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              helperText: field.helpText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(currentDateStr ?? field.placeholder ?? 'Seleccionar fecha'),
                const Icon(Icons.calendar_today, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Renderizar componente para carga de evidencias fotográficas
  Widget _buildFileFormField(FormFieldSchema field) {
    final files = _selectedFiles[field.key] ?? [];
    final maxFiles = field.validation.maxFiles ?? 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label + (field.validation.required ? ' *' : ''),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        if (field.helpText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(field.helpText!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...files.asMap().entries.map((entry) {
              final idx = entry.key;
              final file = entry.value;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          files.removeAt(idx);
                          _values[field.key] = files.map((f) => f.path).toList();
                        });
                        _notifyChange();
                      },
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (files.length < maxFiles)
              InkWell(
                onTap: () async {
                  final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) {
                    setState(() {
                      files.add(File(picked.path));
                      _selectedFiles[field.key] = files;
                      _values[field.key] = files.map((f) => f.path).toList();
                    });
                    _notifyChange();
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.grey),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

