import 'package:capy_notes/features/notes/task_list_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskLineScanner', () {
    test('扫描无序任务列表，返回文档顺序与精确位置', () {
      final tasks = TaskLineScanner.scan('- [ ] 待办 A\n- [x] 待办 B');
      expect(tasks, hasLength(2));
      expect(tasks[0].checked, isFalse);
      expect(tasks[0].checkboxStart, 2);
      expect(tasks[0].checkboxEnd, 5);
      expect(tasks[1].checked, isTrue);
      expect(tasks[1].checkboxStart, 13);
      expect(tasks[1].checkboxEnd, 16);
    });

    test('支持 * + 与有序列表标记', () {
      final tasks = TaskLineScanner.scan('* [ ] a\n+ [x] b\n1. [ ] c');
      expect(tasks, hasLength(3));
      expect(tasks.map((t) => t.checked).toList(), [false, true, false]);
    });

    test('支持块引用内的任务列表', () {
      final tasks = TaskLineScanner.scan('> - [ ] 引用任务\n> - [x] 已完成');
      expect(tasks, hasLength(2));
      expect(tasks[0].checked, isFalse);
      expect(tasks[1].checked, isTrue);
    });

    test('支持嵌套缩进的任务列表', () {
      final tasks = TaskLineScanner.scan('- 父级\n  - [ ] 子任务');
      expect(tasks, hasLength(1));
      expect(tasks[0].checkboxStart, 9);
    });

    test('跳过围栏代码块中的伪任务行', () {
      final text = '```\n- [ ] 代码里的假任务\n```\n- [x] 真任务';
      final tasks = TaskLineScanner.scan(text);
      expect(tasks, hasLength(1));
      expect(tasks[0].checked, isTrue);
    });

    test('普通列表项不误判', () {
      final tasks = TaskLineScanner.scan('- 普通项\n- [ ] 任务');
      expect(tasks, hasLength(1));
    });

    test('缺少标记后空格的 `[ ]` 不是任务', () {
      expect(TaskLineScanner.scan('- [ ]'), isEmpty);
      expect(TaskLineScanner.scan('- [x]无空格'), isEmpty);
    });

    test('扫描数量与 AST 不一致时返回空（禁用交互，避免切错行）', () {
      // 顶层 4 空格缩进会被解析为代码块，扫描器误计数 → 触发保护
      final tasks = TaskLineScanner.scan('    - [ ] 缩进代码块');
      expect(tasks, isEmpty);
    });

    test('空文本返回空列表', () {
      expect(TaskLineScanner.scan(''), isEmpty);
    });
  });
}
