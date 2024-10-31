import 'dart:convert';
import '../tailf.dart';

/// Convert the stream of bytes to utf8 strings.
extension TailString on TailFile {
  /// Convert the stream of bytes to utf8 strings.
  Stream<String> get asStrings => utf8.decoder.bind(stream);
}

/// Convert the stream of bytes to utf8 lines.
extension TailLines on TailFile {
  /// Convert the stream of bytes to utf8 lines.
  Stream<String> get asLines => asStrings.transform(LineSplitter());
}
