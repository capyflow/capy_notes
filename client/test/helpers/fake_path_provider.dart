import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// 将 path_provider 的文档目录指向临时目录，供测试进行真实文件读写。
class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
}
