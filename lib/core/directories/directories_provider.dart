import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:roozaneh/core/model/directories.dart';
import 'package:roozaneh/core/model/environment.dart';
import 'package:roozaneh/utils/custom_loggers.dart';
import 'package:roozaneh/utils/platform_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'directories_provider.g.dart';

@Riverpod(keepAlive: true)
class AppDirectories extends _$AppDirectories with InfraLogger {
  final _methodChannel = const MethodChannel("com.hiddify.app/platform");

  @override
  Future<Directories> build() async {
    final Directories dirs;
    if (kIsWeb) {
      return (baseDir: Directory("."), workingDir: Directory("."), tempDir: Directory("."));
    }
    if (PlatformUtils.isIOS) {
      final paths = await _methodChannel.invokeMethod<Map>("get_paths");
      loggy.debug("paths: $paths");
      dirs = (
        baseDir: Directory(paths?["base"]! as String),
        workingDir: Directory(paths?["working"]! as String),
        tempDir: Directory(paths?["temp"]! as String),
      );
    } else if (PlatformUtils.isWindows &&
        Environment.isPortable &&
        await checkDirectoryAccess(getPortableDirectory())) {
      final portableDir = getPortableDirectory();
      dirs = (baseDir: portableDir, workingDir: portableDir, tempDir: await getTemporaryDirectory());
    } else {
      final baseDir = await getApplicationSupportDirectory();
      final workingDir = Platform.isAndroid ? await _getAndroidWorkingDirectory() : baseDir;
      final tempDir = await getTemporaryDirectory();
      dirs = (baseDir: baseDir, workingDir: workingDir, tempDir: tempDir);
    }

    if (!dirs.baseDir.existsSync()) {
      await dirs.baseDir.create(recursive: true);
    }
    if (!dirs.workingDir.existsSync()) {
      await dirs.workingDir.create(recursive: true);
    }

    final targetDirs = {
      Directory(p.join(dirs.workingDir.path, "data")),
      Directory(p.join(dirs.baseDir.path, "data")),
    };

    for (final dataDir in targetDirs) {
      if (!dataDir.existsSync()) {
        await dataDir.create(recursive: true);
      }

      for (final filename in ['geoip-ir.srs', 'geosite-ir.srs', 'clash.db']) {
        final targetFile = File(p.join(dataDir.path, filename));
        if (!targetFile.existsSync() || targetFile.lengthSync() < 1000) {
          try {
            final byteData = await rootBundle.load('assets/core/$filename');
            await targetFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
            loggy.info('Extracted $filename to ${dataDir.path}');
          } catch (e) {
            loggy.debug('Could not extract $filename to ${dataDir.path}: $e');
          }
        }
      }
    }

    return dirs;
  }

  static Future<Directory> _getAndroidWorkingDirectory() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return getApplicationDocumentsDirectory();
      if (extDir.existsSync()) return extDir;
      await extDir.create(recursive: true);
      return extDir;
    } catch (_) {}
    return getApplicationDocumentsDirectory();
  }

  static Future<Directory> getDatabaseDirectory() async {
    if (kIsWeb) {
      return Directory(".");
    }
    if (PlatformUtils.isIOS || PlatformUtils.isMacOS) {
      return await getLibraryDirectory();
    } else if (PlatformUtils.isWindows &&
        Environment.isPortable &&
        await checkDirectoryAccess(getPortableDirectory())) {
      final portableDir = getPortableDirectory();
      return portableDir;
    } else if (PlatformUtils.isWindows || PlatformUtils.isLinux) {
      return await getApplicationSupportDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  static Directory getPortableDirectory() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    return Directory(p.join(exeDir.path, 'hiddify_portable_data'));
  }

  static Future<bool> checkDirectoryAccess(Directory dir) async {
    final testFile = File(p.join(dir.path, 'access_test.txt'));

    try {
      if (!await dir.exists()) await dir.create(recursive: true);
      await testFile.writeAsString('Testing write permission...');
      await testFile.readAsString();
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
