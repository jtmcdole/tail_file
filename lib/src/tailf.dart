import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../tailf.dart';

class TailFileBase implements TailFile {
  final File file;
  final bool seekToEnd;
  final _controller = StreamController<Uint8List>();
  StreamSubscription<FileSystemEvent>? _updates;

  RandomAccessFile? _randomAccessFile;

  @override
  int get position => _position;
  int _position = 0;

  TailFileBase(this.file, {this.seekToEnd = true});

  @override
  Stream<Uint8List> get stream {
    if (!_controller.hasListener) {
      _start();
    }
    _controller.onCancel = () {
      _randomAccessFile?.close();
    };
    return _controller.stream;
  }

  @override
  Future<void> close() async {
    await _controller.close();
    await _updates?.cancel();
  }

  _start() async {
    if (await file.exists() != true) {
      _controller.addError(ArgumentError('file does not exist'));
      return;
    }
    final raf = _randomAccessFile = await file.open();
    if (seekToEnd) {
      _position = await raf.length();
      await raf.setPosition(_position);
    }

    final stream = file.parent.watch(events: FileSystemEvent.modify);

    final ctl = StreamController<FileSystemEvent>();

    // Windows only supports watching directories. Fun.
    // Also; stream listen so we can cancel... which leads to async errors
    //       while trying to handle reading / size. Fun!
    _updates = stream.listen((event) {
      ctl.add(event);
    });

    try {
      await for (var event in ctl.stream) {
        if (event is! FileSystemModifyEvent ||
            event.path != file.path ||
            !event.contentChanged) return;
        int length = await File(event.path).length();
        if (length <= _position) {
          // truncation?
          _position = length;
          return;
        }

        final bytes = await raf.read(length - _position);
        _position = length;
        _controller.add(bytes);
      }
    } catch (e, s) {
      // I'm not going to simulate a filesystem error for coverage sake...
      // coverage:ignore-start
      if (!_controller.isClosed) {
        _controller.addError(e, s);
        _controller.close();
      }
      _updates?.cancel();
      _updates = null;
      _randomAccessFile?.close();
      _randomAccessFile = null;
      // coverage:ignore-end
    }
  }
}
