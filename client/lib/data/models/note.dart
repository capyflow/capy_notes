class Note {
  final String fileName;
  final String content;
  final DateTime updatedAt;

  const Note({
    required this.fileName,
    required this.content,
    required this.updatedAt,
  });

  String get title => fileName.replaceAll(RegExp(r'\.md$'), '');

  Note copyWith({String? fileName, String? content, DateTime? updatedAt}) {
    return Note(
      fileName: fileName ?? this.fileName,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
