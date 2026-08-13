import 'dart:io';

import 'package:capy_notes/data/models/note.dart';
import 'package:capy_notes/features/notes/editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'helpers/fake_path_provider.dart';

void main() {
  late Directory root;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('capy_notes_editor_test');
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  setUp(() {
    PathProviderPlatform.instance = FakePathProvider(root);
  });

  Future<void> pumpEditor(WidgetTester tester, Note note) async {
    await tester.pumpWidget(MaterialApp(home: EditorPage(note: note)));
    await tester.pumpAndSettle();
  }

  testWidgets('预览中点击复选框翻转源码并落盘', (tester) async {
    final note = Note(
      fileName: 'todo.md',
      content: '- [ ] 待办 A\n- [x] 待办 B',
      updatedAt: DateTime.now(),
    );
    await pumpEditor(tester, note);

    // 切换到预览
    await tester.tap(find.text('预览'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    // 点击未完成复选框 → 源码翻转并保存
    await tester.tap(find.byIcon(Icons.check_box_outline_blank));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_box), findsNWidgets(2));
    expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);

    // 切回编辑，源码已更新
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    final bodyField = tester.widget<TextField>(find.byType(TextField).last);
    expect(bodyField.controller!.text, '- [x] 待办 A\n- [x] 待办 B');
  });

  testWidgets('非任务列表的普通列表不渲染可点击复选框', (tester) async {
    final note = Note(
      fileName: 'plain.md',
      content: '- 普通项\n- [ ] 任务',
      updatedAt: DateTime.now(),
    );
    await pumpEditor(tester, note);

    await tester.tap(find.text('预览'));
    await tester.pumpAndSettle();

    // 只有 1 个可交互复选框
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNothing);
  });
}
