import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final directory = Directory('data_source');
  var checked = 0;
  await for (final entity in directory.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    jsonDecode(await entity.readAsString());
    checked++;
  }
  stdout.writeln('Validated $checked JSON files.');
}
