import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:tailf/tailf.dart';
import 'package:test/test.dart';

void main() {
  group('tailing a file', () {
    late Directory temp;
    late TailFile tail;
    late LoneWriter writer;

    setUp(() async {
      temp = await Directory.current.createTemp('delete-me-test-');
      writer = LoneWriter();
      writer.logging = true;
      await writer.start();
    });

    tearDown(() async {
      await writer.quit();
      await tail.close();
      await Future.delayed(Duration(milliseconds: 100));
      await temp.delete(recursive: true);
    });

    test("which doesn't exist puts an error on the stream", () {
      tail = TailFile(File(path.join(temp.path, 'missing')));
      expect(
        tail.stream,
        emitsError(isArgumentError),
      );
    });

    test("records end position of file", () async {
      final filePath = path.join(temp.path, 'end_pos');
      await writer.open(filePath);
      await writer.write('first line\n');
      await writer.flush();
      await writer.close();

      final emitted = <Uint8List>[];
      tail = TailFile(File(filePath));
      tail.stream.listen((data) => emitted.add(data));
      await Future.delayed(Duration(milliseconds: 50));

      expect(tail.position, equals(11));
    });

    test("only returns new additions when asked", () async {
      final filePath = path.join(temp.path, 'new_additions');
      await writer.open(filePath);
      await writer.write('first line\n');
      await writer.write('second line\n');
      await writer.flush();
      await writer.close();

      final emitted = <Uint8List>[];
      tail = TailFile(File(filePath));
      tail.stream.listen((data) => emitted.add(data));

      await Future.delayed(Duration(milliseconds: 100));

      await writer.open(filePath);
      await writer.write('1234');
      await writer.flush();
      await writer.close();
      await writer.quit();

      await Future.delayed(Duration(milliseconds: 100));

      expect(emitted, [Uint8List.fromList('1234'.codeUnits)]);
    });

    test("handles non-closed file writes", () async {
      // This test exists becausae "file modified" doesn't happen on parent
      // directories (for me) on Linux.

      final filePath = path.join(temp.path, 'new_additions_sync');
      writer.logging = true;

      print(
          '[${DateTime.now().millisecondsSinceEpoch} test]: launching external process writer');
      await writer.start();
      await writer.open(filePath);
      await writer.write('first line\n');
      await writer.write('second line\n');
      await writer.flush();

      await Future.delayed(Duration(milliseconds: 100));

      print(
          '[${DateTime.now().millisecondsSinceEpoch} test]: starting TailFile');

      final emitted = <Uint8List>[];
      tail = TailFile(File(filePath));
      tail.stream.listen((data) => emitted.add(data));

      await Future.delayed(Duration(milliseconds: 100));

      await writer.write('1234');
      await writer.flush();
      await writer.close();

      print(
          '[${DateTime.now().millisecondsSinceEpoch} test]: waiting writer exit');
      await writer.quit();
      expect(await writer.exitCode, 0);

      // Delay for macos (sigh)
      await Future.delayed(Duration(milliseconds: 200));

      expect(emitted, [Uint8List.fromList('1234'.codeUnits)]);
    });

    test("handles truncations", () async {
      final filePath = path.join(temp.path, 'truncations');
      await writer.open(filePath);
      await writer.write('first line\n');
      await writer.write('second line\n');
      await writer.flush();
      await writer.close();

      final emitted = <Uint8List>[];
      tail = TailFile(File(filePath));
      tail.stream.listen((data) => emitted.add(data));

      await Future.delayed(Duration(milliseconds: 100));

      await writer.open(filePath, flag: 'truncate');
      await writer.write('1234');
      await writer.flush();
      await writer.close();
      await writer.quit();

      // Delay for macos (sigh)
      await Future.delayed(Duration(milliseconds:500));

      expect(emitted, [Uint8List.fromList('1234'.codeUnits)]);
      expect(await File(filePath).readAsString(), '1234');
    });

    test("from the beginning is possible", () async {
      final filePath = path.join(temp.path, 'beginning');
      await writer.open(filePath);
      await writer.write('first line\n');
      await writer.write('second line\n');
      await writer.flush();
      await writer.close();

      final emitted = <Uint8List>[];
      tail = TailFile(File(filePath), seekToEnd: false);
      tail.stream.listen((data) => emitted.add(data));

      await writer.open(filePath);
      await writer.write('1234');
      await writer.flush();
      await writer.close();
      await writer.quit();

      // Delay for macos (sigh)
      await Future.delayed(Duration(milliseconds: 200));


      expect(emitted, [
        Uint8List.fromList('first line\nsecond line\n'.codeUnits),
        Uint8List.fromList('1234'.codeUnits)
      ]);
    });

    test('can return strings (extension)', () async {
      final filePath = path.join(temp.path, 'strings');
      writer.logging = true;
      await writer.open(filePath);
      await writer.write('first line\n');
      await writer.flush();
      await writer.close();

      final emitted = <String>[];
      tail = TailFile(File(filePath));
      tail.asStrings.listen((data) => emitted.add(data));

      await writer.open(filePath);
      await writer.write('1234\n5678');
      await writer.flush();
      await writer.close();
      await writer.quit();

            // Delay for macos (sigh)
      await Future.delayed(Duration(milliseconds: 200));


      expect(emitted, ['1234\n5678']);
    });
    test('can return lines (extension)', () async {
      final filePath = path.join(temp.path, 'lines');
      await writer.open(filePath);
      await writer.write('first line\n');
      await writer.flush();
      await writer.close();

      final emitted = <String>[];
      tail = TailFile(File(filePath));
      tail.asLines.listen((data) => emitted.add(data));

      await writer.open(filePath);
      await Future.delayed(Duration(milliseconds: 100));

      await writer.write('1234\n5678\n');
      await writer.flush();
      await writer.close();
      await writer.quit();

      // Delay for macos (sigh)
      await Future.delayed(Duration(milliseconds: 200));

      expect(emitted, ['1234', '5678']);
    });
  });
}

/// Integration test: don't rely on dart:io to get events while under test.
class LoneWriter {
  bool logging = false;
  LoneWriter();

  Process? _process;

  final processLines = <String>[];

  Future<String> get nextLine async {
    if (_consumedLines < processLines.length) {
      return processLines[_consumedLines++];
    }
    // Wait for the next one, thanks.
    _nextLine = Completer<String>();
    return _nextLine.future;
  }

  int _consumedLines = 0;
  var _nextLine = Completer<String>();

  Future<int> get exitCode => _process!.exitCode;

  Future<String> start() async {
    _process = await Process.start(
        'dart', [path.join('test', 'utils', 'writer.dart')]);
    utf8.decoder
        .bind(_process!.stdout)
        .transform(LineSplitter())
        .listen((line) {
      if (line.isEmpty) return;
      processLines.add(line);
      if (!_nextLine.isCompleted) {
        _consumedLines++;
        _nextLine.complete(line);
      }
    });
    return nextLine;
  }

  _send(String data) {
    _process!.stdin.writeln(data);
  }

  Future<String> _logWriter(Future<String> future) async {
    final string = await future;
    if (logging) {
      final decode = json.decode(string);
      print(
          '[${DateTime.now().millisecondsSinceEpoch} writer.dart]: ${decode['status']}');
    }
    return string;
  }

  Future<String> open(String file, {String? flag}) {
    _send(json
        .encode({'cmd': 'open', 'data': file, if (flag != null) 'flag': flag}));
    return _logWriter(nextLine);
  }

  Future<String> close() {
    _send(json.encode({'cmd': 'close'}));
    return _logWriter(nextLine);
  }

  Future<String> flush() {
    _send(json.encode({'cmd': 'flush'}));
    return _logWriter(nextLine);
  }

  Future<String> delete(String file) {
    _send(json.encode({'cmd': 'delete', 'data': file}));
    return _logWriter(nextLine);
  }

  Future<String> sleep(int milliseconds) {
    _send(json.encode({'cmd': 'sleep', 'data': milliseconds}));
    return _logWriter(nextLine);
  }

  Future<String> write(String string) {
    _send(json.encode(
        {'cmd': 'write64', 'data': base64.encode(utf8.encode(string))}));
    return _logWriter(nextLine);
  }

  bool _hasQuit = false;

  Future<String> quit() async {
    if (_hasQuit) return 'already quit';
    _send(json.encode({'cmd': 'quit'}));
    _hasQuit = true;
    return _logWriter(nextLine);
  }
}
