enum TemplateFieldType { text, image, info, imageArray }

class TemplateField {
  final String? key;
  final String label;
  final TemplateFieldType type;
  final String? hint;
  final int minItems;
  final int maxItems;

  TemplateField(
    this.key,
    this.label,
    this.type, {
    this.hint,
    this.minItems = 1,
    this.maxItems = 1,
  });
}

class TemplateMetadata {
  final List<TemplateField> fields;
  TemplateMetadata(this.fields);

  static TemplateMetadata fromApi(Map<String, dynamic> response, String kind) {
    final List<TemplateField> fields = [];
    final data = response['data'] ?? {};

    // Check new format: data.parameters.definitions
    final parameters = data['parameters'];
    dynamic definitions;
    if (parameters != null &&
        parameters is Map &&
        parameters['definitions'] != null) {
      definitions = parameters['definitions'];
    } else {
      definitions = data['parameterDefinitions'];
    }

    if (definitions is Map && definitions.isNotEmpty) {
      definitions.forEach((key, def) {
        if (def is! Map) return;
        final label = def['description'] ?? def['label'] ?? key ?? '';
        final typeStr = def['type']?.toString().toLowerCase() ?? '';
        final binding = def['binding']?.toString().toLowerCase() ?? '';
        final hint = def['hint']?.toString();
        final minItems = def['minItems'] as int? ?? 1;
        final maxItems = def['maxItems'] as int? ?? 1;

        TemplateFieldType type = TemplateFieldType.text;

        if (binding == 'collagegallery' ||
            binding == 'rowgallery' ||
            binding == 'gallery') {
          type = TemplateFieldType.imageArray;
        } else if (binding == 'file') {
          type = TemplateFieldType.image;
        } else if (typeStr == 'string') {
          type = TemplateFieldType.text;
        } else {
          type = TemplateFieldType.info;
        }

        fields.add(
          TemplateField(
            key,
            label,
            type,
            hint: hint,
            minItems: minItems,
            maxItems: maxItems,
          ),
        );
      });
    } else if (definitions is List && definitions.isNotEmpty) {
      for (var def in definitions) {
        final key = def['key'] ?? def['name'];
        final label = def['label'] ?? def['description'] ?? key ?? '';
        final typeStr =
            def['type']?.toString().toLowerCase() ??
            (key != null ? 'text' : 'info');
        final hint = def['hint']?.toString();

        TemplateFieldType type = TemplateFieldType.text;
        if (typeStr == 'info' || (key == null && typeStr != 'image')) {
          type = TemplateFieldType.info;
        } else if (typeStr.contains('image') ||
            typeStr.contains('photo') ||
            (key?.toLowerCase().contains('photo') ?? false) ||
            (key?.toLowerCase().contains('image') ?? false)) {
          type = TemplateFieldType.image;
        }

        fields.add(TemplateField(key, label, type, hint: hint));
      }
    }

    if (fields.isEmpty) {
      if (kind == "cover") {
        fields.add(
          TemplateField(
            "title",
            "책 제목",
            TemplateFieldType.text,
            hint: "책의 제목을 입력하세요",
          ),
        );
        fields.add(
          TemplateField(
            "subtitle",
            "부제목",
            TemplateFieldType.text,
            hint: "여행 날짜나 장소를 입력하세요",
          ),
        );
        fields.add(
          TemplateField("coverPhoto", "표지 사진", TemplateFieldType.image),
        );
      } else if (kind == "divider") {
        fields.add(
          TemplateField(
            "yearMonthDayTitle",
            "날짜",
            TemplateFieldType.text,
            hint: "2026.04.01",
          ),
        );
        fields.add(
          TemplateField(
            "location",
            "장소",
            TemplateFieldType.text,
            hint: "여행 장소를 입력하세요",
          ),
        );
      } else {
        fields.add(
          TemplateField(
            "contents",
            "이야기",
            TemplateFieldType.text,
            hint: "오늘의 일기를 작성해 보세요",
          ),
        );
        fields.add(TemplateField("photo1", "사진", TemplateFieldType.image));
      }
    }

    return TemplateMetadata(fields);
  }
}
