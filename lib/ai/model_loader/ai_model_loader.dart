import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';

enum ModelInstallStatus {
  missing,
  downloading,
  paused,
  verifying,
  extracting,
  loaded,
  failed,
}

class ModelInstallSnapshot {
  const ModelInstallSnapshot({
    required this.status,
    required this.progress,
    required this.message,
    this.localPath,
    this.error,
    this.downloadProgress,
    this.extractProgress,
  });

  final ModelInstallStatus status;
  final double progress;
  final String message;
  final String? localPath;
  final String? error;
  final double? downloadProgress;
  final double? extractProgress;
}

class AiModelLoader {
  static const bool performsRealDownload = true;
  static const _r2BaseUrl = String.fromEnvironment('AIVERSE_R2_BASE_URL');

  Future<bool> hasInstalledModel(AiModelOption option) async {
    final directory = await _modelDirectory(option);
    final marker = File(p.join(directory.path, '.complete'));
    return marker.exists();
  }

  Stream<ModelInstallSnapshot> downloadAndPrepare(
    AiModelOption option, {
    required String? authToken,
  }) async* {
    final directory = await _modelDirectory(option);
    await directory.create(recursive: true);

    try {
      final archiveUri = _archiveUri(option);
      final archiveFile = File(p.join(directory.path, 'model.zip'));

      yield ModelInstallSnapshot(
        status: ModelInstallStatus.downloading,
        progress: 0,
        message: 'Downloading ${option.title} AI package...',
        localPath: directory.path,
        downloadProgress: 0,
        extractProgress: 0,
      );

      await for (final downloadProgress in _downloadArchive(
        archiveUri: archiveUri,
        target: archiveFile,
      )) {
        yield ModelInstallSnapshot(
          status: ModelInstallStatus.downloading,
          progress: (downloadProgress * 0.72).clamp(0, 0.72),
          message: 'Downloading model ZIP',
          localPath: directory.path,
          downloadProgress: downloadProgress,
          extractProgress: 0,
        );
      }

      yield ModelInstallSnapshot(
        status: ModelInstallStatus.extracting,
        progress: 0.74,
        message: 'Extracting model files...',
        localPath: directory.path,
        downloadProgress: 1,
        extractProgress: 0,
      );

      await for (final extractProgress in _extractArchive(
        archiveFile: archiveFile,
        targetDirectory: directory,
      )) {
        yield ModelInstallSnapshot(
          status: ModelInstallStatus.extracting,
          progress: (0.74 + extractProgress * 0.24).clamp(0.74, 0.98),
          message: 'Extracting model files',
          localPath: directory.path,
          downloadProgress: 1,
          extractProgress: extractProgress,
        );
      }

      yield ModelInstallSnapshot(
        status: ModelInstallStatus.verifying,
        progress: 0.99,
        message: 'Verifying model package...',
        localPath: directory.path,
        downloadProgress: 1,
        extractProgress: 1,
      );

      await File(
        p.join(directory.path, '.complete'),
      ).writeAsString(DateTime.now().toIso8601String());

      yield ModelInstallSnapshot(
        status: ModelInstallStatus.loaded,
        progress: 1,
        message: '${option.title} AI is ready',
        localPath: directory.path,
        downloadProgress: 1,
        extractProgress: 1,
      );
    } catch (error) {
      yield ModelInstallSnapshot(
        status: ModelInstallStatus.failed,
        progress: 0,
        message: 'Could not download ${option.title} AI',
        localPath: directory.path,
        error: '$error',
      );
    }
  }

  Uri _archiveUri(AiModelOption option) {
    if (option.archivePath.startsWith('http://') ||
        option.archivePath.startsWith('https://')) {
      return Uri.parse(option.archivePath);
    }

    final base = _r2BaseUrl.trim();
    if (base.isEmpty) {
      throw const FormatException(
        'Missing AIVERSE_R2_BASE_URL. Build with --dart-define=AIVERSE_R2_BASE_URL=https://your-r2-domain',
      );
    }

    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = option.archivePath.startsWith('/')
        ? option.archivePath.substring(1)
        : option.archivePath;
    return Uri.parse('$normalizedBase/$normalizedPath');
  }

  Stream<double> _downloadArchive({
    required Uri archiveUri,
    required File target,
  }) async* {
    final request = http.Request('GET', archiveUri);
    final response = await request.send();
    if (response.statusCode == 404) {
      throw HttpException(
        'Cloudflare R2 object not found: ${archiveUri.path}. Check the bucket key and filename.',
      );
    }
    if (response.statusCode >= 400) {
      throw HttpException(
        'R2 download failed: ${response.statusCode} for $archiveUri',
      );
    }

    await target.parent.create(recursive: true);

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          yield received / total;
        }
      }
    } finally {
      await sink.close();
    }
    yield 1;
  }

  Stream<double> _extractArchive({
    required File archiveFile,
    required Directory targetDirectory,
  }) async* {
    final inputStream = InputFileStream(archiveFile.path);
    final archive = ZipDecoder().decodeStream(inputStream);
    final files = archive.files.where((file) => file.isFile).toList();
    if (files.isEmpty) {
      throw const FormatException('Model ZIP did not contain any files.');
    }

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final targetPath = _safeExtractPath(targetDirectory, file.name);
      await Directory(p.dirname(targetPath)).create(recursive: true);

      final outputStream = OutputFileStream(targetPath);
      try {
        file.writeContent(outputStream);
      } finally {
        await outputStream.close();
      }

      yield (index + 1) / files.length;
    }
  }

  String _safeExtractPath(Directory targetDirectory, String archivePath) {
    final normalizedName = p.normalize(archivePath).replaceAll('\\', '/');
    if (normalizedName.startsWith('../') ||
        normalizedName == '..' ||
        p.isAbsolute(normalizedName)) {
      throw FormatException('Unsafe ZIP entry path: $archivePath');
    }

    final targetPath = p.normalize(p.join(targetDirectory.path, normalizedName));
    final root = p.normalize(targetDirectory.path);
    if (!p.isWithin(root, targetPath) && targetPath != root) {
      throw FormatException('Unsafe ZIP entry path: $archivePath');
    }
    return targetPath;
  }

  Future<Directory> _modelDirectory(AiModelOption option) async {
    final root = await getApplicationSupportDirectory();
    final safeName = option.internalModelId.replaceAll('/', '_');
    return Directory(p.join(root.path, 'models', safeName));
  }
}
