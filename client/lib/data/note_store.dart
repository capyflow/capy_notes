import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'models/note.dart';

class NoteStore {
  NoteStore._();

  static final NoteStore instance = NoteStore._();

  Directory? _dir;

  Future<Directory> _notesDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/notes');
    await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<List<Note>> list() async {
    final dir = await _notesDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.map(_fileToNote).toList();
  }

  Future<Note> create(String title) async {
    final dir = await _notesDir();
    final fileName = _uniqueFileName(dir, title);
    final file = File('${dir.path}/$fileName');
    await file.writeAsString('');
    return _fileToNote(file);
  }

  Future<void> update(String fileName, String content) async {
    final dir = await _notesDir();
    await File('${dir.path}/$fileName').writeAsString(content);
  }

  Future<void> rename(String oldName, String newName) async {
    final dir = await _notesDir();
    final from = File('${dir.path}/$oldName');
    if (!from.existsSync()) return;
    final clean = _sanitize(newName);
    final target = _uniqueFileName(dir, clean.isEmpty ? 'untitled' : clean);
    await from.rename('${dir.path}/$target');
  }

  Future<void> delete(String fileName) async {
    final dir = await _notesDir();
    final file = File('${dir.path}/$fileName');
    if (file.existsSync()) await file.delete();
  }

  Future<Note?> importFrom(
    String sourceName, {
    Uint8List? bytes,
    String? sourcePath,
  }) async {
    final dir = await _notesDir();
    final base = sourceName.replaceAll(RegExp(r'\.md$'), '');
    final fileName = _uniqueFileName(dir, base.isEmpty ? 'imported' : base);
    final dest = File('${dir.path}/$fileName');
    if (bytes != null) {
      // 优先写入字节：不依赖文件选择器返回的临时路径，天然规避
      // Android 缓存路径/权限导致的源文件不可读问题。
      await dest.writeAsBytes(bytes);
    } else if (sourcePath != null && sourcePath.isNotEmpty) {
      final source = File(sourcePath);
      if (!source.existsSync()) return null;
      await source.copy(dest.path);
    } else {
      return null;
    }
    return _fileToNote(dest);
  }

  Note _fileToNote(File file) {
    return Note(
      fileName: file.uri.pathSegments.last,
      content: _decode(file.readAsBytesSync()),
      updatedAt: file.lastModifiedSync(),
    );
  }

  /// 兼容非 UTF-8 编码（如 GBK）的 Markdown 文件：
  /// 严格 UTF-8 解码失败时回退 Latin-1（永不抛错），保证导入/列表不崩溃。
  String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String _uniqueFileName(Directory dir, String title) {
    final base = _sanitize(title).isEmpty ? 'untitled' : _sanitize(title);
    var candidate = '$base.md';
    var i = 2;
    while (File('${dir.path}/$candidate').existsSync()) {
      candidate = '$base $i.md';
      i++;
    }
    return candidate;
  }

  String _sanitize(String title) {
    return title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
