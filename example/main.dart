import 'dart:io';
import 'package:tailf/tailf.dart';

void main() async {
  final tail = TailFile(File('example/main.dart'), seekToEnd: false);
  await for (var line in tail.asLines) {
    print(line);
  }
}
