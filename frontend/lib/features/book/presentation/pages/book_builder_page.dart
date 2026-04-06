import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/book/domain/models/book.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/utils/image_utils.dart';
import 'package:frontend/features/book/presentation/widgets/cover_selector_wizard.dart';
import 'package:frontend/features/book/presentation/widgets/add_page_wizard.dart';

class BookBuilderPage extends ConsumerStatefulWidget {
  final TravelBook book;
  const BookBuilderPage({super.key, required this.book});

  @override
  ConsumerState<BookBuilderPage> createState() => _BookBuilderPageState();
}

class _BookBuilderPageState extends ConsumerState<BookBuilderPage> {
  late TravelBook _currentBook;
  bool _isLoading = false;

  bool _checkIsReadOnly() {
    final status = _currentBook.status.toLowerCase();
    if (status != 'draft' &&
        status != 'created' &&
        status != 'manual_editing') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            '수정 불가',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('이미 제작이 완료된 책은 수정하거나 페이지를 추가할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(color: Colors.indigo)),
            ),
          ],
        ),
      );
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
  }

  Future<void> _refreshBook() async {
    final books = await apiService.getBooks();
    final updated = books.firstWhere((b) => b.id == _currentBook.id);
    setState(() {
      _currentBook = updated;
    });
  }

  Future<void> _selectCover() async {
    if (_checkIsReadOnly()) return;

    final specUid = _currentBook.bookSpecUid ?? 'SQUAREBOOK_HC';
    final templates = await apiService.getTemplates(
      specUid,
      kind: 'cover',
      scope: 'all',
      limit: 50,
    );

    var coverTemplates = templates
        .where(
          (t) =>
              t['templateKind']?.toString().toLowerCase() == 'cover' ||
              t['kind']?.toString().toLowerCase() == 'cover',
        )
        .toList();

    if (coverTemplates.isEmpty && templates.isNotEmpty) {
      coverTemplates = templates;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: CoverSelectorWizard(
          book: _currentBook,
          templates: coverTemplates,
          onSuccess: () => _refreshBook(),
        ),
      ),
    );
  }

  Future<void> _addPage() async {
    if (_checkIsReadOnly()) return;

    final specUid = _currentBook.bookSpecUid ?? 'SQUAREBOOK_HC';
    final templates = await apiService.getTemplates(
      specUid,
      kind: 'content',
      scope: 'all',
      limit: 50,
    );

    var contentTemplates = _filterTemplates(templates, 'content');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AddPageWizard(
          bookId: _currentBook.id,
          bookSpecUid: specUid,
          templates: contentTemplates,
          onSuccess: () => _refreshBook(),
        ),
      ),
    );
  }

  Future<void> _editPage(BookPage page) async {
    if (_checkIsReadOnly()) return;

    final specUid = _currentBook.bookSpecUid ?? 'SQUAREBOOK_HC';
    final templates = await apiService.getTemplates(
      specUid,
      kind: 'content',
      scope: 'all',
      limit: 100,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AddPageWizard(
          bookId: _currentBook.id,
          bookSpecUid: specUid,
          templates: templates,
          editingPage: page,
          onSuccess: () => _refreshBook(),
        ),
      ),
    );
  }

  List<dynamic> _filterTemplates(List<dynamic> templates, String targetKind) {
    var filtered = templates.where((t) {
      final kind = (t['templateKind'] ?? t['kind'] ?? '')
          .toString()
          .toLowerCase();
      if (targetKind == 'content' && kind == 'page') return true;
      return kind == targetKind;
    }).toList();

    return filtered.isEmpty ? templates : filtered;
  }

  Future<void> _deletePage(int pageId) async {
    if (_checkIsReadOnly()) return;

    setState(() => _isLoading = true);
    try {
      await apiService.deletePage(_currentBook.id, pageId);
      await _refreshBook();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizeAndOrder() async {
    if (_currentBook.coverTemplateId == null) {
      _showErrorDialog(context, '표지를 먼저 설정해 주세요.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await apiService.finalizeBook(_currentBook.id);
      await _refreshBook();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              '제작 완료',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text('책이 완성됐습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인', style: TextStyle(color: Colors.indigo)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = '$e';
        if (e is DioException && e.response != null) {
          final data = e.response!.data;
          if (data is Map && data.containsKey('detail')) {
            errorMsg = '${data['detail']}';
          } else if (data != null) {
            errorMsg = data.toString();
          }
        }
        _showErrorDialog(context, errorMsg);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentBook.title),
            Row(
              children: [
                Text(
                  '정산 예정 금액: ${_currentBook.price}원',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.indigo.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _currentBook.totalPages >= _currentBook.minPages
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _currentBook.totalPages >= _currentBook.minPages
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Text(
                    '${_currentBook.totalPages} / ${_currentBook.minPages}p',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _currentBook.totalPages >= _currentBook.minPages
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_currentBook.pages.isNotEmpty &&
              _currentBook.coverTemplateId != null &&
              (_currentBook.status.toLowerCase() == 'draft' ||
                  _currentBook.status.toLowerCase() == 'created' ||
                  _currentBook.status.toLowerCase() == 'manual_editing'))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Tooltip(
                message: '제작을 확정합니다. (페이지 부족 무시)',
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _finalizeAndOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('제작 완료'),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSectionTitle('1. 표지 디자인 설정', Icons.auto_awesome),
              const SizedBox(height: 12),
              _buildCoverSection(),
              const SizedBox(height: 40),
              _buildSectionTitle(
                '2. 페이지 구성 (실제 출력: ${_currentBook.totalPages}p)',
                Icons.collections,
              ),
              const SizedBox(height: 12),
              if (_currentBook.pages.isEmpty)
                _buildEmptyState()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _currentBook.pages.length,
                  itemBuilder: (context, i) =>
                      _buildPageItem(i, _currentBook.pages[i]),
                ),
              const SizedBox(height: 20),
              _buildAddPageButton(),
              const SizedBox(height: 100),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCoverSection() {
    final hasCover = _currentBook.coverTemplateId != null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasCover ? Colors.indigo.shade100 : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _currentBook.coverThumbnail != null
                  ? Image.network(
                      ImageUtils.getProxyUrl(_currentBook.coverThumbnail!),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print("Cover image load error: $error");
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              Text(
                                "Error",
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Icon(
                      hasCover ? Icons.style : Icons.style_outlined,
                      color: Colors.indigo,
                      size: 32,
                    ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCover ? '선택된 디자인 표지' : '아직 선택된 표지가 없습니다',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: hasCover ? Colors.black : Colors.grey,
                    ),
                  ),
                  Text(
                    hasCover
                        ? '표지 제목: ${_currentBook.title}'
                        : '책의 첫 인상을 결정하는 표지를 골라보세요',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _selectCover,
              child: Text(hasCover ? '변경' : '선택'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPageButton() {
    return ElevatedButton.icon(
      onPressed: _addPage,
      icon: const Icon(Icons.add_photo_alternate),
      label: const Text('새 페이지 추가하기'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        side: const BorderSide(color: Colors.indigo),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.note_add_outlined, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            '추가된 페이지가 없습니다.\n나만의 사진과 글을 채워보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPageItem(int index, BookPage page) {
    final params = jsonDecode(page.parameters);
    String summary = "";
    if (params.containsKey('title')) {
      summary = params['title'];
    } else if (params.containsKey('contents')) {
      summary = params['contents'];
    } else if (params.containsKey('location')) {
      summary = params['location'];
    } else if (params.isNotEmpty) {
      final firstVal = params.values.firstWhere(
        (v) => v is String,
        orElse: () => "",
      );
      summary = firstVal;
    }

    final thumbUrl = page.thumbnail;

    return GestureDetector(
      onTap: () => _editPage(page),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.grey[50],
              child: thumbUrl != null
                  ? Image.network(
                      ImageUtils.getProxyUrl(thumbUrl),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print("Main grid page image error: $error");
                        return const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.grey,
                            size: 20,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(Icons.image, color: Colors.grey, size: 24),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.3),
                    ],
                    stops: const [0.0, 0.4, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _editPage(page),
                  splashColor: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'P${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 28,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.isEmpty ? (page.templateName ?? '내지') : summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    page.templateName ?? '템플릿',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _deletePage(page.id),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '제작 불가',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Colors.indigo)),
          ),
        ],
      ),
    );
  }
}
