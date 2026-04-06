import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/travel_log/domain/models/travel_log.dart';
import 'package:frontend/features/travel_log/presentation/providers/travel_log_provider.dart';

class EditorPage extends ConsumerStatefulWidget {
  final TravelLog? log;
  const EditorPage({super.key, this.log});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log?.title ?? '');
    _locationController = TextEditingController(text: widget.log?.location ?? '');
    _contentController = TextEditingController(text: widget.log?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.log != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '기록 확인' : '새 여행 기록'),
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveLog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '여행 기록 제목',
                border: OutlineInputBorder(),
                hintText: '예: 에펠탑 아래에서의 피크닉',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              readOnly: isEditing,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '장소/도시/국가',
                border: OutlineInputBorder(),
                hintText: '예: 프랑스, 파리',
              ),
              maxLines: 2,
              readOnly: isEditing,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '상세 여행 기록',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                hintText: '그날의 감정이나 발견한 것들을 자유롭게 적어보세요...',
              ),
              maxLines: 15,
              readOnly: isEditing,
            ),
            const SizedBox(height: 30),
            if (!isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('저장하기', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _saveLog() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요.')),
      );
      return;
    }

    final newLog = TravelLog(
      title: _titleController.text,
      location: _locationController.text,
      content: _contentController.text,
    );

    ref.read(travelLogListProvider.notifier).addLog(newLog);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('여행 기록이 저장되었습니다.')),
    );
  }
}
