import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/note.dart';
import '../../data/note_store.dart';
import 'editor_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _store = NoteStore.instance;
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final notes = await _store.list();
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  Future<void> _createNote() async {
    final note = await _store.create('无标题');
    await _reload();
    if (mounted) _open(note);
  }

  Future<void> _importNote() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
    );
    final file = result?.files.single;
    if (file == null) return;
    final note = await _store.importFrom(file.path!, file.name);
    if (note == null) return;
    await _reload();
    if (mounted) _open(note);
  }

  void _open(Note note) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditorPage(note: note)),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            onNew: _createNote,
            onImport: _importNote,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? _EmptyState(onImport: _importNote, onCreate: _createNote)
                    : _NoteList(
                        notes: _notes,
                        onOpen: _open,
                        onReload: _reload,
                      ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.onNew, required this.onImport});

  final VoidCallback onNew;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: CapyColors.sidebar,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.notes_outlined, size: 20),
                SizedBox(width: 8),
                Text(
                  'Capy Notes',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            icon: Icons.home_outlined,
            label: '全部笔记',
            selected: true,
            onTap: () {},
          ),
          const Spacer(),
          _SidebarItem(
            icon: Icons.file_open_outlined,
            label: '导入 Markdown',
            onTap: onImport,
          ),
          _SidebarItem(
            icon: Icons.edit_note_outlined,
            label: '新建笔记',
            onTap: onNew,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: selected ? CapyColors.hover : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: CapyColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? CapyColors.text : CapyColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteList extends StatelessWidget {
  const _NoteList({
    required this.notes,
    required this.onOpen,
    required this.onReload,
  });

  final List<Note> notes;
  final ValueChanged<Note> onOpen;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            '全部笔记',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '共 ${0} 篇',
            style: TextStyle(fontSize: 13, color: CapyColors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: notes.length,
            itemBuilder: (context, i) => _NoteTile(
              note: notes[i],
              onTap: () => onOpen(notes[i]),
              onDelete: () async {
                await NoteStore.instance.delete(notes[i].fileName);
                onReload();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = note.content
        .replaceAll(RegExp(r'[#>*`~\-_\[\]()|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                size: 16, color: CapyColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CapyColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relativeTime(note.updatedAt),
              style: const TextStyle(
                fontSize: 12,
                color: CapyColors.textSecondary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: CapyColors.textSecondary),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport, required this.onCreate});

  final VoidCallback onImport;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notes_outlined, size: 56, color: CapyColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            '还没有笔记',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '新建一篇，或导入现有的 Markdown 文件',
            style: TextStyle(
              fontSize: 14,
              color: CapyColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: const Text('导入'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建笔记'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
