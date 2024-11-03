import 'dart:convert';
import 'dart:io';

main(List<String> args) async {
  File? file;
  IOSink? sink;

  sendStatus(String status) {
    stdout.writeln(json.encode({'status': status}));
  }

  sendStatus('ready');
  await for (var line in utf8.decoder.bind(stdin).transform(LineSplitter())) {
    final cmd = json.decode(line);
    switch (cmd['cmd']) {
      case 'open':
        file = await File(cmd['data']).create();
        sink = file.openWrite(
            mode: cmd['flag'] == 'truncate' ? FileMode.write : FileMode.append);
        sendStatus('opened file $file');

      case 'close':
        await sink?.close();
        sink = null;
        sendStatus('closed sink');

      case 'flush':
        await sink?.flush();
        sendStatus('flushed sink');

      case 'delete':
        final xFile = File(cmd['data']);
        await xFile.delete();
        sendStatus('deleted $xFile');

      case 'sleep':
        final time = Duration(milliseconds: cmd['data']);
        await Future.delayed(time);
        sendStatus('slept $time');

      case 'write64':
        if (file == null) throw "must open a file first";
        sink ??= file.openWrite(mode: FileMode.append);
        final data = base64Decode(cmd['data']);
        sink.add(data);
        sendStatus('wrote(binary): $data');

      case 'quit':
        if (sink != null) await sink.close();
        sendStatus('quitting');
        exit(0);

      default:
        sendStatus('command not found: $cmd');
    }
  }
  if (sink != null) await sink.close();
}
