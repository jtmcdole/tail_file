import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:tailf/tailf.dart';

final parser = ArgParser()
  ..addFlag('debug-time', abbr: 't', help: 'print timestamps on lines')
  ..addFlag('help', abbr: 'h', help: 'this help')
  ..addFlag('debug-file', abbr: 'f', help: 'print filename on lines');

main(List<String> arguments) async {
  final args = parser.parse(arguments);
  if (args.rest.isEmpty) {
    stderr.writeln('error; file argument missing');
    stderr.writeln('   tailf <file>');
    exit(1);
  }

  if (args.wasParsed('help')) {
    stderr.writeln('tailf <commands> <files...>');
    stderr.writeln(parser.usage);
    exit(0);
  }

  final debugTime = args.wasParsed('debug-time');
  final debugFile = args.wasParsed('debug-file');

  logFile(String filePath) async {
    final tail = TailFile(File(filePath));
    final filename = path.basename(filePath);
    final writers = {
      (true, true): (String line) => stdout
          .writeln('[${DateTime.now().toIso8601String()} $filename]: $line'),
      (true, false): (String line) =>
          stdout.writeln('[${DateTime.now().toIso8601String()}]: $line'),
      (false, true): (String line) => stdout.writeln('[$filename]: $line'),
      (false, false): (String line) => stdout.writeln(line),
    };
    final writer = writers[(debugTime, debugFile)]!;
    await for (var line in tail.asLines) {
      writer(line);
    }
  }
  
  for (var file in args.rest) {
    logFile(file);
  }
}
