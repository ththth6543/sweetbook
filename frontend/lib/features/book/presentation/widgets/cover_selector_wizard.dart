import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/features/book/domain/models/book.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/book/domain/models/template_metadata.dart';
import 'package:frontend/core/utils/image_utils.dart';
import 'package:frontend/core/presentation/widgets/preview_dialog.dart';

class CoverSelectorWizard extends StatefulWidget {
  final TravelBook book;
  final List<dynamic> templates;
  final VoidCallback onSuccess;

  const CoverSelectorWizard({
    super.key,
    required this.book,
    required this.templates,
    required this.onSuccess,
  });

  @override
  State<CoverSelectorWizard> createState() => _CoverSelectorWizardState();
}

class _CoverSelectorWizardState extends State<CoverSelectorWizard> {
  int _step = 0; // 0: Grid, 1: Dynamic Edit
  String? _selectedTemplateUid;
  Map<String, dynamic>? _selectedTemplate;
  bool _isSaving = false;
  bool _isLoadingMetadata = false;
  List<TemplateField> _dynamicFields = [];

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, XFile?> _imageFiles = {};
  final Map<String, List<XFile>> _imageArrayFiles = {};
  final ImagePicker _picker = ImagePicker();

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
      final metadata = TemplateMetadata.fromApi(details, "cover");

      for (var c in _textControllers.values) {
        c.dispose();
      }
      _textControllers.clear();
      _imageFiles.clear();
      _imageArrayFiles.clear();

      _dynamicFields = metadata.fields;
      for (var field in _dynamicFields) {
        final key = field.key;
        if (key == null) continue;

        if (field.type == TemplateFieldType.text) {
          String initialValue = "";
          if (key == "title") initialValue = widget.book.title;
          if (key == "subtitle") initialValue = widget.book.description ?? "";
          _textControllers[key] = TextEditingController(text: initialValue);
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
          "title",
          "책 제목",
          TemplateFieldType.text,
          hint: "책의 제목을 입력하세요",
        ),
        TemplateField(
          "subtitle",
          "부제목",
          TemplateFieldType.text,
          hint: "여행 날짜나 장소를 입력하세요",
        ),
        TemplateField("coverPhoto", "표지 사진", TemplateFieldType.image),
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
                _step == 0 ? '표지 디자인 선택' : '표지 꾸미기',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_step == 0)
            Expanded(child: _buildGrid())
          else
            Expanded(child: _buildEditor()),
          const SizedBox(height: 24),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (widget.templates.isEmpty) {
      return const Center(child: Text('불러올 수 있는 디자인이 없습니다.'));
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: widget.templates.length,
      itemBuilder: (context, index) {
        final t = widget.templates[index];
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
              borderRadius: BorderRadius.circular(16),
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
                      : const Center(child: Icon(Icons.style)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    t['templateName'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditor() {
    final thumb = _selectedTemplate?['thumbnails']?['layout'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Preview
        Expanded(
          flex: 4,
          child: Column(
            children: [
              const Text(
                '디자인 예시',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
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
                          child: Icon(Icons.zoom_in, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Icon(Icons.image, size: 64, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Right: Dynamic Form
        Expanded(
          flex: 6,
          child: _isLoadingMetadata
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _dynamicFields.map((field) {
                      final key = field.key;

                      if (field.type == TemplateFieldType.imageArray &&
                          key != null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${field.label} (최대 ${field.maxItems}장)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...(_imageArrayFiles[key] ?? []).map((img) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        height: 100,
                                        width: 100,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                          image: DecorationImage(
                                            image: kIsWeb
                                                ? NetworkImage(img.path)
                                                      as ImageProvider
                                                : FileImage(File(img.path)),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: -8,
                                        right: -8,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _imageArrayFiles[key]?.remove(
                                                img,
                                              );
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                if ((_imageArrayFiles[key]?.length ?? 0) <
                                    field.maxItems)
                                  GestureDetector(
                                    onTap: () async {
                                      List<XFile>? imgs;
                                      if (field.maxItems > 1) {
                                        imgs = await _picker.pickMultiImage();
                                      } else {
                                        final img = await _picker.pickImage(
                                          source: ImageSource.gallery,
                                        );
                                        if (img != null) imgs = [img];
                                      }
                                      if (imgs != null && imgs.isNotEmpty) {
                                        setState(() {
                                          final currentList =
                                              _imageArrayFiles[key] ?? [];
                                          final maxAllowed =
                                              field.maxItems -
                                              currentList.length;
                                          final toAdd = imgs!
                                              .take(maxAllowed)
                                              .toList();
                                          _imageArrayFiles[key] = [
                                            ...currentList,
                                            ...toAdd,
                                          ];
                                        });
                                      }
                                    },
                                    child: Container(
                                      height: 100,
                                      width: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add_photo_alternate,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }

                      if (field.type == TemplateFieldType.info) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            field.label,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.indigo,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final img = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (img != null)
                                  setState(() => _imageFiles[key] = img);
                              },
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
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
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.add_a_photo,
                                            color: Colors.grey,
                                          ),
                                          Text(
                                            '${field.label} 선택',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
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
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _textControllers[key],
                              decoration: InputDecoration(
                                hintText:
                                    field.hint ?? '${field.label} 내용을 입력하세요',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
                      return const SizedBox();
                    }).toList(),
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
                        final Map<String, dynamic> params = {};

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
                                widget.book.id,
                                bytes,
                                imageFile.name,
                              );
                              if (res['success'] == true) {
                                params[key] = res['data']['fileName'];
                              }
                            }
                          } else if (field.type ==
                              TemplateFieldType.imageArray) {
                            final fileList = _imageArrayFiles[key] ?? [];
                            List<String> uploadedFileNames = [];
                            for (var imgFile in fileList) {
                              final bytes = await imgFile.readAsBytes();
                              final res = await apiService.uploadPhoto(
                                widget.book.id,
                                bytes,
                                imgFile.name,
                              );
                              if (res['success'] == true &&
                                  res['data'] != null &&
                                  res['data']['fileName'] != null) {
                                uploadedFileNames.add(res['data']['fileName']);
                              }
                            }
                            params[key] = uploadedFileNames;
                          }
                        }

                        await apiService.updateCover(
                          widget.book.id,
                          _selectedTemplateUid!,
                          jsonEncode(params),
                        );
                        widget.onSuccess();
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('오류: $e')));
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
