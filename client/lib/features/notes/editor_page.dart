import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../data/models/note.dart';
import '../../data/note_store.dart';
import 'task_list_scanner.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.note});

  final Note note;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  bool _preview = false;
  bool _dirty = false;

  Note get _note => widget.note;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _note.title);
    _bodyController = TextEditingController(text: _note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _markDirty() {
    _dirty = true;
  }

  Future<void> _save({bool notify = true}) async {
    final store = NoteStore.instance;
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != _note.title) {
      await store.rename(_note.fileName, '$newTitle.md');
    }
    await store.update(
      newTitle.isNotEmpty && newTitle != _note.title
          ? '$newTitle.md'
          : _note.fileName,
      _bodyController.text,
    );
    _dirty = false;
    if (mounted && notify) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  /// 预览中点击任务复选框：翻转对应源码行的 `[ ]` ↔ `[x]` 并落盘。
  void _toggleTaskLine(int index) {
    final tasks = TaskLineScanner.scan(_bodyController.text);
    if (index >= tasks.length) return;
    final task = tasks[index];
    _bodyController.text = _bodyController.text.replaceRange(
      task.checkboxStart,
      task.checkboxEnd,
      task.checked ? '[ ]' : '[x]',
    );
    _markDirty();
    setState(() {});
    _save(notify: false);
  }

  Future<void> _export() async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/${_titleController.text.trim()}.md');
    await file.writeAsString(_bodyController.text);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/markdown')],
      subject: _titleController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 18),
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (_dirty) await _save();
            if (!mounted) return;
            navigator.pop(true);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined, size: 20),
            tooltip: '导出',
            onPressed: _export,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton(
              onPressed: _dirty ? _save : null,
              child: const Text('保存'),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              controller: _titleController,
              onChanged: (_) => _markDirty(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '无标题',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: CapyColors.hover,
                    selectedForegroundColor: CapyColors.text,
                    foregroundColor: CapyColors.textSecondary,
                    side: const BorderSide(color: CapyColors.divider),
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('编辑')),
                    ButtonSegment(value: true, label: Text('预览')),
                  ],
                  selected: {_preview},
                  onSelectionChanged: (sel) {
                    setState(() => _preview = sel.first);
                  },
                ),
                const Spacer(),
                Text(
                  '${_bodyController.text.length} 字',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CapyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _preview
                ? _buildPreview()
                : TextField(
                    controller: _bodyController,
                    onChanged: (_) {
                      _markDirty();
                      setState(() {});
                    },
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      hintText: '开始写作…支持 Markdown 语法',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.all(20),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final tasks = TaskLineScanner.scan(_bodyController.text);
    var checkboxIndex = 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: MarkdownBody(
        data: _bodyController.text.isEmpty ? '_暂无内容_' : _bodyController.text,
        selectable: true,
        styleSheet: _capyMarkdownStyle(),
        extensionSet: md.ExtensionSet.gitHubFlavored,
        checkboxBuilder: (checked) {
          final index = checkboxIndex++;
          final task = index < tasks.length ? tasks[index] : null;
          final enabled = task != null && task.checked == checked;
          return _PreviewCheckbox(
            checked: checked,
            enabled: enabled,
            onTap: enabled ? () => _toggleTaskLine(index) : null,
          );
        },
      ),
    );
  }

  MarkdownStyleSheet _capyMarkdownStyle() {
    return MarkdownStyleSheet(
      h1: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      h2: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      p: const TextStyle(fontSize: 16, height: 1.7),
      code: const TextStyle(
        fontSize: 14,
        fontFamily: 'monospace',
        backgroundColor: CapyColors.codeBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: CapyColors.codeBg,
        borderRadius: BorderRadius.circular(4),
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: CapyColors.quoteBar, width: 3),
        ),
      ),
      blockquote: const TextStyle(
        fontSize: 16,
        height: 1.7,
        color: CapyColors.textSecondary,
      ),
      listBullet: const TextStyle(fontSize: 16),
      tableBorder: TableBorder.all(color: CapyColors.divider),
      tableHead: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}

/// 预览中的任务复选框：点击可翻转 `[ ]` ↔ `[x]` 并写回源码。
class _PreviewCheckbox extends StatelessWidget {
  const _PreviewCheckbox({
    required this.checked,
    required this.enabled,
    this.onTap,
  });

  final bool checked;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      checked ? Icons.check_box : Icons.check_box_outline_blank,
      size: 18,
      color: enabled && !checked ? CapyColors.accent : CapyColors.textSecondary,
    );
    if (!enabled || onTap == null) {
      return Padding(padding: const EdgeInsets.only(right: 4), child: icon);
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: checked ? '标记为未完成' : '标记为已完成',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: icon,
        ),
      ),
    );
  }
}
