import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/features/book/domain/models/book.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/book/domain/models/template_metadata.dart';
import 'package:frontend/core/utils/image_utils.dart';
import 'package:frontend/core/presentation/widgets/preview_dialog.dart';

class AddPageWizard extends ConsumerStatefulWidget {
  final int bookId;
  final String bookSpecUid;
  final List<dynamic> templates;
  final BookPage? editingPage;
  final VoidCallback onSuccess;

  const AddPageWizard({
    super.key,
    required this.bookId,
    required this.bookSpecUid,
    required this.templates,
    required this.onSuccess,
    this.editingPage,
  });

  @override
  ConsumerState<AddPageWizard> createState() => _AddPageWizardState();
}

class _AddPageWizardState extends ConsumerState<AddPageWizard> {
  int _step = 0; // 0: Grid, 1: Dynamic Editor
  String? _selectedTemplateUid;
  Map<String, dynamic>? _selectedTemplate;
  bool _isSaving = false;
  bool _isLoadingMetadata = false;
  bool _isLoadingTemplates = false;
  List<TemplateField> _dynamicFields = [];

  String _selectedKind = 'content';
  final Map<String, List<dynamic>> _templatesCache = {};

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, XFile?> _imageFiles = {};
  final Map<String, List<XFile>> _imageArrayFiles = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _templatesCache['content'] = widget.templates;

    if (widget.editingPage != null) {
      _selectedTemplateUid = widget.editingPage!.templateUid;
      _step = 1;
      _fetchAndInitFields();
    }
  }

  @override
  void dispose() {
    for (var c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchAndInitFields() async {
    if (_selectedTemplateUid == null) return;

    setState(() => _isLoadingMetadata = true);
    try {
      final details = await apiService.getTemplateDetails(
        _selectedTemplateUid!,
      );
      final metadata = TemplateMetadata.fromApi(details, "content");

      for (var c in _textControllers.values) {
        c.dispose();
      }
      _textControllers.clear();
      _imageFiles.clear();
      _imageArrayFiles.clear();

      setState(() {
        _dynamicFields = metadata.fields;
        _selectedTemplate = details['data'];
      });

      Map<String, dynamic> initialParams = {};
      if (widget.editingPage != null) {
        initialParams = jsonDecode(widget.editingPage!.parameters);
      }

      for (var field in _dynamicFields) {
        final key = field.key;
        if (key == null) continue;

        if (field.type == TemplateFieldType.text) {
          final initialValue = initialParams[key] ?? "";
          _textControllers[key] = TextEditingController(
            text: initialValue.toString(),
          );
        } else if (field.type == TemplateFieldType.image) {
          _imageFiles[key] = null;
        } else if (field.type == TemplateFieldType.imageArray) {
          _imageArrayFiles[key] = [];
        }
      }
    } catch (e) {
      print('Error mapping template fields: $e');
      _dynamicFields = [
        TemplateField(
          "contents",
          "이야기",
          TemplateFieldType.text,
          hint: "오늘의 일기를 작성해 보세요",
        ),
        TemplateField("photo1", "사진", TemplateFieldType.image),
      ];
      for (var field in _dynamicFields) {
        final key = field.key!;
        if (field.type == TemplateFieldType.text) {
          _textControllers[key] = TextEditingController();
        } else {
          _imageFiles[key] = null;
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingMetadata = false);
    }
  }

  Future<void> _fetchTemplatesForKind(String kind) async {
    if (_templatesCache.containsKey(kind)) {
      setState(() => _selectedKind = kind);
      return;
    }

    setState(() {
      _isLoadingTemplates = true;
      _selectedKind = kind;
    });

    try {
      final templates = await apiService.getTemplates(
        widget.bookSpecUid,
        kind: kind,
        scope: 'all',
        limit: 50,
      );
      setState(() {
        _templatesCache[kind] = templates;
      });
    } catch (e) {
      setState(() {
        _templatesCache[kind] = [];
      });
    } finally {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  Widget _buildCategoryTabs() {
    final kinds = [
      {'label': '내지', 'kind': 'content'},
      {'label': '구분면', 'kind': 'divider'},
      {'label': '발행면', 'kind': 'publish'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: kinds.map((k) {
          final isSelected = _selectedKind == k['kind'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(k['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) _fetchTemplatesForKind(k['kind']!);
              },
              selectedColor: Colors.indigo,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _step == 0 ? '디자인 선택' : '내용 채우기',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (_step == 0) ...[const SizedBox(height: 16), _buildCategoryTabs()],
          const SizedBox(height: 20),
          if (_step == 0)
            Expanded(child: _buildTemplateGrid())
          else
            Expanded(child: _buildEditorView()),
          const SizedBox(height: 24),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildTemplateGrid() {
    final templates = _templatesCache[_selectedKind] ?? [];

    if (_isLoadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (templates.isEmpty) {
      return const Center(child: Text('해당 카테고리에 템플릿이 없습니다.'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: templates.length,
      itemBuilder: (context, i) {
        final t = templates[i];
        final isSelected = _selectedTemplateUid == t['templateUid'];
        final thumb = t['thumbnails']?['layout'];
        return GestureDetector(
          onTap: () => setState(() {
            _selectedTemplateUid = t['templateUid'];
            _selectedTemplate = t;
          }),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(
                color: isSelected ? Colors.indigo : Colors.grey[200]!,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: thumb != null
                      ? Image.network(
                          ImageUtils.getProxyUrl(thumb),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 20,
                              ),
                            );
                          },
                        )
                      : const Center(child: Icon(Icons.image)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Text(
                    t['templateName'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorView() {
    final thumb = _selectedTemplate?['thumbnails']?['layout'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              const Text(
                '디자인 예시',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (thumb != null)
                Expanded(
                  child: GestureDetector(
                    onTap: () => showPreviewDialog(
                      context,
                      ImageUtils.getProxyUrl(thumb),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ImageUtils.getProxyUrl(thumb),
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Positioned(
                          bottom: 8,
                          right: 8,
                          child: Icon(
                            Icons.zoom_in,
                            color: Colors.black54,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Expanded(
                  child: Center(child: Icon(Icons.image, color: Colors.grey)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: _isLoadingMetadata
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '페이지 입력',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._dynamicFields.map((field) {
                        final key = field.key;

                        if (field.type == TemplateFieldType.info) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              field.label,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.indigo,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        if (field.type == TemplateFieldType.imageArray && key != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${field.label} (최대 ${field.maxItems}장)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...(_imageArrayFiles[key] ?? []).map((img) {
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          height: 80, width: 80,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey[300]!),
                                            image: DecorationImage(
                                              image: kIsWeb ? NetworkImage(img.path) as ImageProvider : FileImage(File(img.path)),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: -8, right: -8,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _imageArrayFiles[key]?.remove(img);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                  if ((_imageArrayFiles[key]?.length ?? 0) < field.maxItems)
                                    GestureDetector(
                                      onTap: () async {
                                        List<XFile>? imgs;
                                        if (field.maxItems > 1) {
                                          imgs = await _picker.pickMultiImage();
                                        } else {
                                          final img = await _picker.pickImage(source: ImageSource.gallery);
                                          if (img != null) imgs = [img];
                                        }
                                        
                                        if (imgs != null && imgs.isNotEmpty) {
                                          setState(() {
                                            final currentList = _imageArrayFiles[key] ?? [];
                                            final maxAllowed = field.maxItems - currentList.length;
                                            final toAdd = imgs!.take(maxAllowed).toList();
                                            _imageArrayFiles[key] = [...currentList, ...toAdd];
                                          });
                                        }
                                      },
                                      child: Container(
                                        height: 80, width: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100], borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey[300]!),
                                        ),
                                        child: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }

                        if (field.type == TemplateFieldType.image &&
                            key != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                field.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  final img = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (img != null) {
                                    setState(() => _imageFiles[key] = img);
                                  }
                                },
                                child: Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: _imageFiles[key] != null
                                      ? kIsWeb
                                            ? Image.network(
                                                _imageFiles[key]!.path,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                File(_imageFiles[key]!.path),
                                                fit: BoxFit.cover,
                                              )
                                      : const Icon(
                                          Icons.add_a_photo,
                                          color: Colors.grey,
                                          size: 24,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        } else if (key != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                field.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _textControllers[key],
                                maxLines: key == "contents" ? 4 : 1,
                                decoration: InputDecoration(
                                  hintText: field.hint ?? '${field.label} 입력',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }
                        return const SizedBox();
                      }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (_step == 1)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 0),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('이전'),
            ),
          ),
        if (_step == 1) const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed:
                _selectedTemplateUid == null || _isSaving || _isLoadingMetadata
                ? null
                : () async {
                    if (_step == 0) {
                      await _fetchAndInitFields();
                      setState(() => _step = 1);
                    } else {
                      setState(() => _isSaving = true);
                      try {
                        final Map<String, dynamic> params = {
                          'dateStr': DateTime.now().toString().split(' ')[0],
                        };

                        for (var field in _dynamicFields) {
                          final key = field.key;
                          if (key == null) continue;

                          if (field.type == TemplateFieldType.text) {
                            params[key] = _textControllers[key]?.text ?? "";
                          } else if (field.type == TemplateFieldType.image) {
                            final imageFile = _imageFiles[key];
                            if (imageFile != null) {
                              final bytes = await imageFile.readAsBytes();
                              final res = await apiService.uploadPhoto(
                                widget.bookId,
                                bytes,
                                imageFile.name,
                              );
                              if (res['success'] == true) {
                                params[key] = res['data']['fileName'];
                              }
                            }
                          } else if (field.type == TemplateFieldType.imageArray) {
                            final fileList = _imageArrayFiles[key] ?? [];
                            List<String> uploadedFileNames = [];
                            for (var imgFile in fileList) {
                               final bytes = await imgFile.readAsBytes();
                               final res = await apiService.uploadPhoto(widget.bookId, bytes, imgFile.name);
                               if (res['success'] == true && res['data'] != null && res['data']['fileName'] != null) {
                                 uploadedFileNames.add(res['data']['fileName']);
                               }
                            }
                            params[key] = uploadedFileNames;
                          }
                        }

                        if (widget.editingPage != null) {
                          await apiService.updatePage(
                            widget.bookId,
                            widget.editingPage!.id,
                            _selectedTemplateUid,
                            params,
                          );
                        } else {
                          await apiService.addPage(
                            widget.bookId,
                            _selectedTemplateUid!,
                            params,
                          );
                        }

                        widget.onSuccess();
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        String errorMessage = e.toString();
                        if (e is DioException) {
                          final data = e.response?.data;
                          if (data != null) {
                            errorMessage = data is Map
                                ? (data['detail'] ?? data.toString())
                                : data.toString();
                          }
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('오류: $errorMessage')),
                          );
                        }
                      } finally {
                        setState(() => _isSaving = false);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(_step == 0 ? '단계를 넘어가기' : '확인'),
          ),
        ),
      ],
    );
  }
}
