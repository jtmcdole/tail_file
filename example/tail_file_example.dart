import 'dart:io';

import 'package:tail_file/tail_file.dart';

main() async {
  final tail = TailFile(File('/var/log/syslog'));
  await for (var line in tail.asLines) {
    print('system log: $line');
  }
}
