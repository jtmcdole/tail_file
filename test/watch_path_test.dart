import 'dart:io';

import 'package:tailf/tail_file.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const tiny = Duration(milliseconds: 400);

void main() {
  group('watching a path', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.current.createTemp('deleteme-test-');
    });

    tearDown(() {
      temp.delete(recursive: true);
    });

    createFile(Directory parent, String name) =>
        File(path.join(parent.path, name)).create();

    test('picks up pre-exiting files', () async {
      createFile(temp, 'foo-1234');
      await Future.delayed(tiny);
      createFile(temp, 'bar-1234');
      await Future.delayed(tiny);
      createFile(temp, 'foo-3245');
      await Future.delayed(tiny);

      final stream = WatchPath().forPattern(temp, RegExp(r'foo-.*'));
      final emitted = <FileEvent>[];
      stream.listen((data) => emitted.add(data));

      await Future.delayed(tiny);

      expect(emitted, hasLength(1));
      expect(emitted.first.existed, isTrue);
      expect(emitted.first.file.uri.pathSegments.last, 'foo-3245');
    });

    test('updates on new files created', () async {
      createFile(temp, 'foo-1234');
      createFile(temp, 'bar-1234');
      await Future.delayed(tiny);
      createFile(temp, 'foo-3245');
      await Future.delayed(tiny);

      final stream = WatchPath().forPattern(temp, RegExp(r'foo-.*'));
      final emitted = <FileEvent>[];
      stream.listen((data) => emitted.add(data));

      await Future.delayed(tiny);

      createFile(temp, 'foo-6789');

      await Future.delayed(tiny);

      expect(emitted, hasLength(2));
      expect(emitted.last.existed, isFalse);
      expect(emitted.last.file.uri.pathSegments.last, 'foo-6789');
    });
  });
}
