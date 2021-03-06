import 'dart:io';

import 'package:dio_http_cache/dio_http_cache.dart';
import 'package:fehviewer/common/global.dart';
import 'package:fehviewer/utils/logger.dart';
import 'package:fehviewer/utils/toast.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:path/path.dart' as path;

import '../service/dns_service.dart';

class CacheController extends GetxController with StateMixin<String> {
  final DnsService _dnsConfigController = Get.find<DnsService>();

  @override
  void onInit() {
    super.onInit();
    getTotCacheSize()
        .then((String value) => change(value, status: RxStatus.success()));
  }

  Future<void> clearAllCache() async {
    DioCacheManager(CacheConfig(databasePath: Global.appSupportPath))
        .clearAll();
    DefaultCacheManager().emptyCache();
    _dnsConfigController.dohCache.clear();

    await _clearCache();

    Future<void>.delayed(const Duration(seconds: 1)).then((_) =>
        getTotCacheSize()
            .then((String value) => change(value, status: RxStatus.success())));

    showToast('Clear cache successfully');
  }

  Future<String> getTotCacheSize() async {
    final int _cachesize = await _loadCache();
    logger.d('tot cacheSize  ${renderSize(_cachesize)}');
    return renderSize(_cachesize);
  }

  Future<int> _getDioCacheSize() async {
    const String _dioCacheName = 'DioCache.db';
    final String _dioCachePath =
        path.join(Global.appSupportPath, _dioCacheName);
    try {
      final File _dioCacheFile = File(_dioCachePath);
      final int _dioCacheLength = await _dioCacheFile.length();
      logger.d('_dioCacheFile size ${_dioCacheLength - 20480}');
      return _dioCacheLength - 20480;
    } catch (e) {
      logger.e(e.toString());
      return 0;
    }
  }

  ///加载缓存
  Future<int> _loadCache() async {
    try {
      final Directory tempDir = Directory(Global.tempPath);
      final int value = await _getTotalSizeOfFilesInDir(tempDir);
      /*tempDir.list(followLinks: false, recursive: true).listen((file) {
        //打印每个缓存文件的路径
        print(file.path);
      });*/
      logger.d('临时目录大小: ' + value.toString());
      return value;
    } catch (err) {
      print(err);
      return 0;
    }
  }

  /// 递归方式 计算文件的大小
  Future<int> _getTotalSizeOfFilesInDir(final FileSystemEntity file) async {
    try {
      if (file is File) {
        return await file.length();
      }
      if (file is Directory) {
        final List<FileSystemEntity> children = file.listSync();
        int total = 0;
        if (children != null)
          for (final FileSystemEntity child in children)
            total += await _getTotalSizeOfFilesInDir(child);
        return total;
      }
      return 0;
    } catch (e) {
      print(e);
      return 0;
    }
  }

  Future<void> _clearCache() async {
    //此处展示加载loading
    try {
      final Directory tempDir = Directory(Global.tempPath);
      //删除缓存目录
      await delDir(tempDir);
    } catch (e) {
      print(e);
    }
  }

  ///递归方式删除目录
  Future<void> delDir(FileSystemEntity file) async {
    try {
      if (file is Directory) {
        final List<FileSystemEntity> children = file.listSync();
        for (final FileSystemEntity child in children) {
          await delDir(child);
        }
      }
      if (file is File) {
        await file.delete();
      }
    } catch (e) {
      print(e);
    }
  }
}

///格式化文件大小
String renderSize(int inValue) {
  double value = inValue.toDouble();
  if (null == value) {
    return '0';
  }
  final List<String> unitArr = <String>['B', 'K', 'M', 'G'];
  int index = 0;
  while (value > 1024) {
    index++;
    value = value / 1024;
  }
  final String size = value.toStringAsFixed(2);
  return '$size ${unitArr[index]}';
}
