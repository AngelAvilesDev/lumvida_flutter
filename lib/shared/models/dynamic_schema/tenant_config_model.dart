// Modelos de datos para el contrato de reportes dinámicos y multi-tenant

class TenantBranding {
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String backgroundColor;
  final String logoUrl;
  final String coatOfArmsUrl;

  const TenantBranding({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.logoUrl,
    required this.coatOfArmsUrl,
  });

  factory TenantBranding.fromJson(Map<String, dynamic> json) {
    return TenantBranding(
      primaryColor: json['primary_color'] ?? '#1E3A8A',
      secondaryColor: json['secondary_color'] ?? '#0D9488',
      accentColor: json['accent_color'] ?? '#F59E0B',
      backgroundColor: json['background_color'] ?? '#F8FAFC',
      logoUrl: json['logo_url'] ?? '',
      coatOfArmsUrl: json['coat_of_arms_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'primary_color': primaryColor,
    'secondary_color': secondaryColor,
    'accent_color': accentColor,
    'background_color': backgroundColor,
    'logo_url': logoUrl,
    'coat_of_arms_url': coatOfArmsUrl,
  };
}

class TenantConfig {
  final String id;
  final String name;
  final String slug;
  final int schemaVersion;
  final DateTime updatedAt;
  final TenantBranding branding;
  final List<CategorySchema> categories;

  const TenantConfig({
    required this.id,
    required this.name,
    required this.slug,
    required this.schemaVersion,
    required this.updatedAt,
    required this.branding,
    required this.categories,
  });

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    final tenantJson = json['tenant'] as Map<String, dynamic>? ?? {};
    final categoriesList = (json['categories'] as List<dynamic>? ?? [])
        .map((c) => CategorySchema.fromJson(c as Map<String, dynamic>))
        .toList();

    return TenantConfig(
      id: tenantJson['id'] ?? '',
      name: tenantJson['name'] ?? '',
      slug: tenantJson['slug'] ?? '',
      schemaVersion: tenantJson['schema_version'] ?? 1,
      updatedAt: DateTime.tryParse(tenantJson['updated_at'] ?? '') ?? DateTime.now(),
      branding: TenantBranding.fromJson(tenantJson['branding'] as Map<String, dynamic>? ?? {}),
      categories: categoriesList,
    );
  }

  Map<String, dynamic> toJson() => {
    'tenant': {
      'id': id,
      'name': name,
      'slug': slug,
      'schema_version': schemaVersion,
      'updated_at': updatedAt.toIso8601String(),
      'branding': branding.toJson(),
    },
    'categories': categories.map((c) => c.toJson()).toList(),
  };
}

class CategorySchema {
  final String id;
  final String name;
  final String slug;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final int maxVisibleReports;
  final List<ReportTypeSchema> reportTypes;

  const CategorySchema({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.sortOrder,
    required this.isActive,
    required this.maxVisibleReports,
    required this.reportTypes,
  });

  factory CategorySchema.fromJson(Map<String, dynamic> json) {
    final reportsList = (json['report_types'] as List<dynamic>? ?? [])
        .map((r) => ReportTypeSchema.fromJson(r as Map<String, dynamic>))
        .toList();

    return CategorySchema(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      icon: json['icon'] ?? 'folder',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      maxVisibleReports: json['max_visible_reports'] ?? 10,
      reportTypes: reportsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'icon': icon,
    'sort_order': sortOrder,
    'is_active': isActive,
    'max_visible_reports': maxVisibleReports,
    'report_types': reportTypes.map((r) => r.toJson()).toList(),
  };
}

class ReportTypeSchema {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final bool requiresLocation;
  final bool requiresEvidence;
  final List<FormFieldSchema> formSchema;

  const ReportTypeSchema({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.icon,
    required this.sortOrder,
    required this.isActive,
    required this.requiresLocation,
    required this.requiresEvidence,
    required this.formSchema,
  });

  factory ReportTypeSchema.fromJson(Map<String, dynamic> json) {
    final fieldsList = (json['form_schema'] as List<dynamic>? ?? [])
        .map((f) => FormFieldSchema.fromJson(f as Map<String, dynamic>))
        .toList();

    return ReportTypeSchema(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'flag',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      requiresLocation: json['requires_location'] ?? true,
      requiresEvidence: json['requires_evidence'] ?? true,
      formSchema: fieldsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'description': description,
    'icon': icon,
    'sort_order': sortOrder,
    'is_active': isActive,
    'requires_location': requiresLocation,
    'requires_evidence': requiresEvidence,
    'form_schema': formSchema.map((f) => f.toJson()).toList(),
  };
}

class FieldOption {
  final String value;
  final String label;

  const FieldOption({required this.value, required this.label});

  factory FieldOption.fromJson(Map<String, dynamic> json) => FieldOption(
    value: json['value']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {'value': value, 'label': label};
}

class FieldDependency {
  final String fieldKey;
  final String operator;
  final dynamic value;

  const FieldDependency({
    required this.fieldKey,
    this.operator = 'equals',
    required this.value,
  });

  factory FieldDependency.fromJson(Map<String, dynamic> json) => FieldDependency(
    fieldKey: json['field_key'] ?? '',
    operator: json['operator'] ?? 'equals',
    value: json['value'],
  );

  Map<String, dynamic> toJson() => {
    'field_key': fieldKey,
    'operator': operator,
    'value': value,
  };

  // Evaluar condición lógica frente al valor actual del campo objetivo
  bool evaluate(dynamic currentValue) {
    switch (operator) {
      case 'equals':
        return currentValue == value;
      case 'not_equals':
        return currentValue != value;
      default:
        return currentValue == value;
    }
  }
}

class FieldValidation {
  final bool required;
  final int? minLength;
  final int? maxLength;
  final num? min;
  final num? max;
  final int? minFiles;
  final int? maxFiles;
  final List<String>? allowedMimes;
  final int? maxFileSizeMb;

  const FieldValidation({
    this.required = false,
    this.minLength,
    this.maxLength,
    this.min,
    this.max,
    this.minFiles,
    this.maxFiles,
    this.allowedMimes,
    this.maxFileSizeMb,
  });

  factory FieldValidation.fromJson(Map<String, dynamic> json) => FieldValidation(
    required: json['required'] ?? false,
    minLength: json['min_length'],
    maxLength: json['max_length'],
    min: json['min'],
    max: json['max'],
    minFiles: json['min_files'],
    maxFiles: json['max_files'],
    allowedMimes: (json['allowed_mimes'] as List<dynamic>?)?.cast<String>(),
    maxFileSizeMb: json['max_file_size_mb'],
  );

  Map<String, dynamic> toJson() => {
    'required': required,
    if (minLength != null) 'min_length': minLength,
    if (maxLength != null) 'max_length': maxLength,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (minFiles != null) 'min_files': minFiles,
    if (maxFiles != null) 'max_files': maxFiles,
    if (allowedMimes != null) 'allowed_mimes': allowedMimes,
    if (maxFileSizeMb != null) 'max_file_size_mb': maxFileSizeMb,
  };
}

class FormFieldSchema {
  final String key;
  final String label;
  final String type; // text, textarea, number, select, multiselect, boolean, date, file
  final String? placeholder;
  final String? helpText;
  final dynamic defaultValue;
  final FieldValidation validation;
  final FieldDependency? dependsOn;
  final List<FieldOption> options;

  const FormFieldSchema({
    required this.key,
    required this.label,
    required this.type,
    this.placeholder,
    this.helpText,
    this.defaultValue,
    required this.validation,
    this.dependsOn,
    this.options = const [],
  });

  factory FormFieldSchema.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List<dynamic>? ?? [])
        .map((o) => FieldOption.fromJson(o as Map<String, dynamic>))
        .toList();

    return FormFieldSchema(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      type: json['type'] ?? 'text',
      placeholder: json['placeholder'],
      helpText: json['help_text'],
      defaultValue: json['default_value'],
      validation: FieldValidation.fromJson(json['validation'] as Map<String, dynamic>? ?? {}),
      dependsOn: json['depends_on'] != null
          ? FieldDependency.fromJson(json['depends_on'] as Map<String, dynamic>)
          : null,
      options: opts,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type,
    if (placeholder != null) 'placeholder': placeholder,
    if (helpText != null) 'help_text': helpText,
    if (defaultValue != null) 'default_value': defaultValue,
    'validation': validation.toJson(),
    if (dependsOn != null) 'depends_on': dependsOn!.toJson(),
    if (options.isNotEmpty) 'options': options.map((o) => o.toJson()).toList(),
  };
}

