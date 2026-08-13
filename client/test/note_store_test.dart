import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:capy_notes/data/note_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'helpers/fake_path_provider.dart';

void main() {
  late Directory root;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('capy_notes_store_test');
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  setUp(() {
    PathProviderPlatform.instance = FakePathProvider(root);
  });

  test('importFrom 写入字节后可经 list() 读回', () async {
    final note = await NoteStore.instance.importFrom(
      '导入测试.md',
      bytes: utf8.encode('# 标题\n\n- [ ] 待办'),
    );
    expect(note, isNotNull);
    expect(note!.fileName, '导入测试.md');
    expect(note.content, '# 标题\n\n- [ ] 待办');

    final listed = await NoteStore.instance.list();
    expect(listed.any((n) => n.fileName == note.fileName), isTrue);
  });

  test('importFrom 重复文件名自动追加序号', () async {
    await NoteStore.instance.importFrom('重名.md', bytes: utf8.encode('a'));
    final second =
        await NoteStore.instance.importFrom('重名.md', bytes: utf8.encode('b'));
    expect(second!.fileName, '重名 2.md');
  });

  test('importFrom 无数据且无路径时返回 null', () async {
    final note = await NoteStore.instance.importFrom('空.md');
    expect(note, isNull);
  });

  test('importFrom 非 UTF-8（GBK）内容不崩溃', () async {
    // GBK 编码的「你好」
    final gbkBytes = Uint8List.fromList([0xC4, 0xE3, 0xBA, 0xC3]);
    final note = await NoteStore.instance.importFrom('gbk.md', bytes: gbkBytes);
    expect(note, isNotNull);
    expect(note!.content, isNotEmpty);
  });

  test('create + update + delete 生命周期正常', () async {
    final note = await NoteStore.instance.create('生命周期');
    await NoteStore.instance.update(note.fileName, '新内容');
    final listed = await NoteStore.instance.list();
    final updated =
        listed.firstWhere((n) => n.fileName == note.fileName);
    expect(updated.content, '新内容');
    await NoteStore.instance.delete(note.fileName);
    final after = await NoteStore.instance.list();
    expect(after.any((n) => n.fileName == note.fileName), isFalse);
  });
}
