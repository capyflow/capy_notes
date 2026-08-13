import 'package:markdown/markdown.dart' as md;

/// GFM 任务列表中的单个复选框在源码中的位置。
class TaskLine {
  final bool checked;
  final int checkboxStart;
  final int checkboxEnd;

  const TaskLine({
    required this.checked,
    required this.checkboxStart,
    required this.checkboxEnd,
  });
}

/// 扫描 Markdown 源码中的任务列表复选框（`- [ ]` / `- [x]`），
/// 返回按文档顺序排列的复选框位置，供预览点击后回写源码。
///
/// 为了保证「渲染出的复选框」与「源码位置」严格一一对应，扫描结果会用
/// 与预览相同的解析扩展集（gitHubFlavored）解析 AST 做数量校验：
/// 两者不一致时返回空列表（预览退化为静态复选框，但绝不切错行）。
class TaskLineScanner {
  TaskLineScanner._();

  /// 与 markdown 包 list_syntax 的复选框规则保持一致：
  /// 列表标记后允许最多 3 个空格，再是 `[ ]`/`[x]`/`[X]`，之后必须跟空格/制表符。
  /// 兼容块引用前缀（`>`）与嵌套缩进。
  static final RegExp _taskItemRegex = RegExp(
    r'^[ \t]*(?:>[ \t]*)*(?:[-*+]|\d+[.)])[ \t]+ {0,3}\[([ xX])\][ \t]',
    multiLine: true,
  );

  static final RegExp _fenceRegex = RegExp(r'^(```+|~~~+)');

  /// 返回文档中的任务复选框位置；无法与渲染结果对齐时返回空列表。
  static List<TaskLine> scan(String text) {
    if (text.isEmpty) return const [];
    final tasks = _scanLines(text);
    if (tasks.length != _countAstCheckboxes(text)) return const [];
    return tasks;
  }

  static List<TaskLine> _scanLines(String text) {
    final tasks = <TaskLine>[];
    var inFence = false;
    String fenceChar = '';
    var offset = 0;
    for (final line in text.split('\n')) {
      final trimmed = line.trimLeft();
      final fenceMatch = _fenceRegex.firstMatch(trimmed);
      if (fenceMatch != null) {
        final marker = fenceMatch.group(1)!;
        if (!inFence) {
          inFence = true;
          fenceChar = marker[0];
        } else if (marker.startsWith(fenceChar)) {
          inFence = false;
        }
        offset += line.length + 1;
        continue;
      }
      if (inFence) {
        offset += line.length + 1;
        continue;
      }
      final m = _taskItemRegex.firstMatch(line);
      if (m != null) {
        // 复选框 `[` 只出现在匹配文本中一次，用整体匹配定位其偏移。
        final bracketOffset = m[0]!.indexOf('[');
        final start = offset + m.start + bracketOffset;
        tasks.add(TaskLine(
          checked: m.group(1) != ' ',
          checkboxStart: start,
          checkboxEnd: start + 3,
        ));
      }
      offset += line.length + 1;
    }
    return tasks;
  }

  static int _countAstCheckboxes(String text) {
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
    ).parse(text);
    var count = 0;
    for (final node in nodes) {
      node.accept(_CheckboxCounter((_) => count++));
    }
    return count;
  }
}

class _CheckboxCounter implements md.NodeVisitor {
  final void Function(md.Element element) onCheckbox;

  _CheckboxCounter(this.onCheckbox);

  @override
  void visitText(md.Text text) {}

  @override
  bool visitElementBefore(md.Element element) {
    if (element.tag == 'input' && element.attributes['type'] == 'checkbox') {
      onCheckbox(element);
    }
    return true;
  }

  @override
  void visitElementAfter(md.Element element) {}
}
