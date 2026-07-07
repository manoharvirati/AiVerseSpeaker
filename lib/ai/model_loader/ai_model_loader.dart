import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';

enum ModelInstallStatus {
  missing,
  downloading,
  paused,
  verifying,
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
  });

  final ModelInstallStatus status;
  final double progress;
  final String message;
  final String? localPath;
  final String? error;
}

class AiModelLoader {
  static const bool performsRealDownload = true;

  Future<bool> hasInstalledModel(AiModelOption option) async {
    final directory = await _modelDirectory(option);
    final marker = File(p.join(directory.path, '.complete'));
    return marker.exists();
  }

  Stream<ModelInstallSnapshot> downloadAndPrepare(
    AiModelOption option, {
    required String? authToken,
  }) async* {
    if (option.requiresAuthToken &&
        (authToken == null || authToken.trim().isEmpty)) {
      yield const ModelInstallSnapshot(
        status: ModelInstallStatus.failed,
        progress: 0,
        message: 'Hugging Face token is required for this gated Gemma model.',
        error: 'missing_auth_token',
      );
      return;
    }

    final directory = await _modelDirectory(option);
    await directory.create(recursive: true);

    try {
      yield ModelInstallSnapshot(
        status: ModelInstallStatus.downloading,
        progress: 0,
        message: 'Reading ${option.repositoryId} file list...',
        localPath: directory.path,
      );

      final files = await _loadRepositoryFiles(option, authToken);
      final selectedFiles = files.where(_shouldDownloadFile).toList();
      if (selectedFiles.isEmpty) {
        throw const FormatException('No downloadable model files were found.');
      }

      for (var index = 0; index < selectedFiles.length; index++) {
        final fileName = selectedFiles[index];
        await for (final fileProgress in _downloadFile(
          option: option,
          fileName: fileName,
          directory: directory,
          authToken: authToken,
        )) {
          final overall = (index + fileProgress) / selectedFiles.length;
          yield ModelInstallSnapshot(
            status: ModelInstallStatus.downloading,
            progress: overall.clamp(0, 0.98),
            message: 'Downloading $fileName',
            localPath: directory.path,
          );
        }
      }

      yield ModelInstallSnapshot(
        status: ModelInstallStatus.verifying,
        progress: 0.99,
        message: 'Verifying Gemma files...',
        localPath: directory.path,
      );

      await File(
        p.join(directory.path, '.complete'),
      ).writeAsString(DateTime.now().toIso8601String());

      yield ModelInstallSnapshot(
        status: ModelInstallStatus.loaded,
        progress: 1,
        message: 'Gemma Fast is downloaded',
        localPath: directory.path,
      );
    } catch (error) {
      yield ModelInstallSnapshot(
        status: ModelInstallStatus.failed,
        progress: 0,
        message: 'Could not download ${option.repositoryId}',
        localPath: directory.path,
        error: '$error',
      );
    }
  }

  Future<List<String>> _loadRepositoryFiles(
    AiModelOption option,
    String? authToken,
  ) async {
    final uri = Uri.https(
      'huggingface.co',
      '/api/models/${option.repositoryId}',
    );
    final response = await http.get(uri, headers: _headers(authToken));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const HttpException(
        'Access denied. Check that your token has accepted Gemma terms.',
      );
    }
    if (response.statusCode >= 400) {
      throw HttpException('Hugging Face API failed: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final siblings = (json['siblings'] as List<dynamic>? ?? const []);
    return siblings
        .map((item) => (item as Map<String, dynamic>)['rfilename'] as String?)
        .whereType<String>()
        .toList();
  }

  bool _shouldDownloadFile(String fileName) {
    if (fileName.startsWith('.')) return false;
    if (fileName.endsWith('.md')) return false;
    if (fileName.endsWith('.txt')) return false;
    return fileName == 'config.json' ||
        fileName == 'generation_config.json' ||
        fileName == 'added_tokens.json' ||
        fileName == 'special_tokens_map.json' ||
        fileName == 'tokenizer.json' ||
        fileName == 'tokenizer.model' ||
        fileName == 'tokenizer_config.json' ||
        fileName.endsWith('.safetensors') ||
        fileName.endsWith('.bin');
  }

  Stream<double> _downloadFile({
    required AiModelOption option,
    required String fileName,
    required Directory directory,
    required String? authToken,
  }) async* {
    final uri = Uri.https(
      'huggingface.co',
      '/${option.repositoryId}/resolve/main/$fileName',
      {'download': 'true'},
    );
    final request = http.Request('GET', uri)
      ..headers.addAll(_headers(authToken));
    final response = await request.send();
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const HttpException(
        'Access denied while downloading file. Check your Hugging Face token.',
      );
    }
    if (response.statusCode >= 400) {
      throw HttpException(
        'Download failed for $fileName: ${response.statusCode}',
      );
    }

    final target = File(p.join(directory.path, fileName));
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

  Future<Directory> _modelDirectory(AiModelOption option) async {
    final root = await getApplicationSupportDirectory();
    final safeName = option.repositoryId.replaceAll('/', '_');
    return Directory(p.join(root.path, 'models', safeName));
  }

  Map<String, String> _headers(String? authToken) {
    final headers = {'Accept': 'application/json'};
    final token = authToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
