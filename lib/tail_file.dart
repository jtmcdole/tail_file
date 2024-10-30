library TailFile;

import 'dart:io';
import 'dart:typed_data';

import 'src/tail_file.dart';
import 'src/watch_path.dart';

/// Read a stream of bytes from a file as it is written to.
abstract class TailFile {
  int get position;

  factory TailFile(File file, {bool seekToEnd = true}) =>
      TailFileBase(file, seekToEnd: seekToEnd);

  /// Stream of bytes as the file is written to.
  Stream<Uint8List> get stream;

  Future<void> close();
}

typedef FileEvent = ({File file, bool existed});

/// Watches for changes on a path
abstract class WatchPath {
  factory WatchPath() => WatchPathBase();

  /// Watches the [directory] for changes to files matching [pattern].
  Stream<FileEvent> forPattern(Directory directory, RegExp pattern);
}
