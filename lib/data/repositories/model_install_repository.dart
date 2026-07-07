import '../../ai/model_loader/ai_model_loader.dart';
import '../../ai/model_loader/model_catalog.dart';
import '../local_database/local_database.dart';

class ModelInstallRecord {
  const ModelInstallRecord({
    required this.tier,
    required this.title,
    required this.internalModelId,
    required this.status,
    required this.progress,
    required this.isRealDownload,
    this.localPath,
    this.checksum,
  });

  final String tier;
  final String title;
  final String internalModelId;
  final ModelInstallStatus status;
  final double progress;
  final bool isRealDownload;
  final String? localPath;
  final String? checksum;
}

class ModelInstallRepository {
  ModelInstallRepository(this.database);

  final LocalDatabase database;

  Future<ModelInstallRecord?> latest() async {
    final db = await database.database;
    final rows = await db.query(
      'model_installations',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    return ModelInstallRecord(
      tier: row['tier'] as String,
      title: row['title'] as String,
      internalModelId: row['internal_model_id'] as String,
      status: ModelInstallStatus.values.byName(row['status'] as String),
      progress: row['progress'] as double,
      isRealDownload: row['is_real_download'] == 1,
      localPath: row['local_path'] as String?,
      checksum: row['checksum'] as String?,
    );
  }

  Future<void> saveSnapshot({
    required AiModelOption option,
    required ModelInstallSnapshot snapshot,
    required bool isRealDownload,
    String? localPath,
    String? checksum,
  }) async {
    final db = await database.database;
    await db.insert('model_installations', {
      'tier': option.tier.name,
      'title': option.title,
      'internal_model_id': option.internalModelId,
      'status': snapshot.status.name,
      'progress': snapshot.progress,
      'is_real_download': isRealDownload ? 1 : 0,
      'local_path': localPath,
      'checksum': checksum,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
