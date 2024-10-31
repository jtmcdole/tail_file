import 'dart:io';
import 'dart:typed_data';

import 'src/tailf.dart';
import 'src/watch_path.dart';

export 'src/extensions.dart';

/// Read a stream of bytes from a file as it is written to.
abstract class TailFile {
  /// The current position in the tailed file.
  int get position;

  /// Setup tailing of [file] from the end of the file.
  ///
  /// Optionally specifiy [seekToEnd] as false to parse the entire file.
  factory TailFile(File file, {bool seekToEnd = true}) =>
      TailFileBase(file, seekToEnd: seekToEnd);

  /// Stream of bytes as the file is written to.
  Stream<Uint8List> get stream;

  /// Stops tailing the file and cleans up any resources.
  Future<void> close();
}

/// Record of file updates from [WatchPath].
///
/// If the latest version of the file [existed] or not.
typedef FileEvent = ({File file, bool existed});

/// Watches for changes on a path
abstract class WatchPath {
  /// Watches for changes on a path
  factory WatchPath() => WatchPathBase();

  /// Watches the [directory] for changes to files matching [pattern].
  Stream<FileEvent> forPattern(Directory directory, RegExp pattern);
}
