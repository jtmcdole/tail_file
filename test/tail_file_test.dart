import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:tail_file/src/extensions.dart';
import 'package:tail_file/tail_file.dart';
import 'package:test/test.dart';

void main() {
  group('tailing a file', () {
    late Directory temp;
    late TailFile tail;

    setUp(() async {
      temp = await Directory.current.createTemp('delete-me-test-');
    });

    tearDown(() async {
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
      final file = await File(path.join(temp.path, 'end_pos')).create();
      final sink = file.openWrite();
      sink.writeln('first line');
      await sink.flush();
      await sink.close();

      final emitted = <Uint8List>[];
      tail = TailFile(file);
      tail.stream.listen((data) => emitted.add(data));
      await Future.delayed(Duration(milliseconds: 100));

      expect(tail.position, equals(11));
    });

    test("only returns new additions when asked", () async {
      final file = await File(path.join(temp.path, 'new_additions')).create();
      final sink = file.openWrite();
      sink.writeln('first line');
      sink.writeln('second line');
      await sink.flush();
      await sink.close();

      final emitted = <Uint8List>[];
      tail = TailFile(file);
      tail.stream.listen((data) => emitted.add(data));

      final sink2 = file.openWrite(mode: FileMode.append);
      await Future.delayed(Duration(milliseconds: 100));

      sink2.write('1234');
      await sink2.flush();
      await sink2.close();

      await Future.delayed(Duration(milliseconds: 100));

      expect(emitted, [Uint8List.fromList('1234'.codeUnits)]);
    });

    test("from the beginning is possible", () async {
      final file = await File(path.join(temp.path, 'beginning')).create();
      final sink = file.openWrite();
      sink.write('first line\n');
      sink.write('second line\n');
      await sink.flush();
      await sink.close();

      final emitted = <Uint8List>[];
      tail = TailFile(file, seekToEnd: false);
      tail.stream.listen((data) => emitted.add(data));

      final sink2 = file.openWrite(mode: FileMode.append);
      await Future.delayed(Duration(milliseconds: 100));

      sink2.write('1234');
      await sink2.flush();
      await sink2.close();

      await Future.delayed(Duration(milliseconds: 100));

      expect(emitted,
          [Uint8List.fromList('first line\nsecond line\n1234'.codeUnits)]);
    });

    test('can return strings (extension)', () async {
      final file = await File(path.join(temp.path, 'strings')).create();
      final sink = file.openWrite();
      sink.write('first line\n');
      await sink.flush();
      await sink.close();

      final emitted = <String>[];
      tail = TailFile(file);
      tail.asStrings.listen((data) => emitted.add(data));

      final sink2 = file.openWrite(mode: FileMode.append);
      await Future.delayed(Duration(milliseconds: 100));

      sink2.write('1234\n5678');
      await sink2.flush();
      await sink2.close();

      await Future.delayed(Duration(milliseconds: 100));

      expect(emitted, ['1234\n5678']);
    });
    test('can return lines (extension)', () async {
      final file = await File(path.join(temp.path, 'lines')).create();
      final sink = file.openWrite();
      sink.write('first line\n');
      await sink.flush();
      await sink.close();

      final emitted = <String>[];
      tail = TailFile(file);
      tail.asLines.listen((data) => emitted.add(data));

      final sink2 = file.openWrite(mode: FileMode.append);
      await Future.delayed(Duration(milliseconds: 100));

      sink2.writeln('1234\n5678');
      await sink2.flush();
      await sink2.close();

      await Future.delayed(Duration(milliseconds: 100));

      expect(emitted, ['1234', '5678']);
    });
  });
}
