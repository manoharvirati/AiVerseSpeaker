import '../local_database/local_database.dart';

class SetupRepository {
  SetupRepository(this.database);

  final LocalDatabase database;

  Future<bool> isSetupCompleted() async {
    return await database.readSetting('setup_completed') == 'true';
  }

  Future<void> markSetupCompleted() {
    return database.writeSetting('setup_completed', 'true');
  }
}
