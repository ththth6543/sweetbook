import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/book/presentation/providers/book_provider.dart';
import 'package:frontend/features/book/presentation/pages/book_builder_page.dart';

class CreateBookWizard extends ConsumerStatefulWidget {
  const CreateBookWizard({super.key});

  @override
  ConsumerState<CreateBookWizard> createState() => _CreateBookWizardState();
}

class _CreateBookWizardState extends ConsumerState<CreateBookWizard> {
  final _titleController = TextEditingController();
  String? _selectedSpecUid = 'SQUAREBOOK_HC';
  List<dynamic> _specs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSpecs();
  }

  Future<void> _loadSpecs() async {
    setState(() => _isLoading = true);
    try {
      final specs = await apiService.getSpecs();
      if (mounted) {
        setState(() {
          _specs = specs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '새 여행 프로젝트',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: '여행기 제목',
              hintText: '예: 2024년 가족 유럽 여행',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 20),
          const Text('책 종류 선택', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _isLoading
              ? const Center(child: LinearProgressIndicator())
              : DropdownButtonFormField<String>(
                  value: _selectedSpecUid,
                  items: _specs.map<DropdownMenuItem<String>>((spec) {
                    return DropdownMenuItem<String>(
                      value: spec['bookSpecUid'],
                      child: Text(spec['bookSpecName'] ?? spec['bookSpecUid']),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedSpecUid = val),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_titleController.text.isEmpty) return;

                final res = await ref
                    .read(bookListProvider.notifier)
                    .createBook(
                      title: _titleController.text,
                      bookSpecUid: _selectedSpecUid,
                      manualEdit: true,
                    );

                if (res != null && mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookBuilderPage(book: res),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '프로젝트 생성 및 편집 시작',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
