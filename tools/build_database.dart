import 'dart:io';

Future<void> main() async {
  final python = Platform.environment['PYTHON'] ?? 'python';
  final result = await Process.start(python, ['tools/build_content_database.py']);
  await stdout.addStream(result.stdout);
  await stderr.addStream(result.stderr);
  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    exit(exitCode);
  }
}
