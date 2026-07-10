import 'dart:io';

Future<void> main() async {
  final database = File('assets/database/content.db');
  final checksum = File('assets/database/content.db.sha256');
  if (!database.existsSync() || !checksum.existsSync()) {
    stderr.writeln('Missing content.db or content.db.sha256. Run tools/build_database.dart.');
    exit(1);
  }
  stdout.writeln('Content database artifacts exist.');
}
