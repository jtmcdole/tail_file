import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';

import '../tailf.dart';

class WatchPathBase implements WatchPath {
  @override
  Stream<FileEvent> forPattern(Directory dir, RegExp pattern) {
    final controller = StreamController<FileEvent>();

    bool signaled = false;
    () async {
      // imediatly start watching for files in case there's a ton to process
      await for (final event in dir.watch(events: FileSystemEvent.create)) {
        if (event is! FileSystemCreateEvent) continue;
        if (pattern.firstMatch(event.path) != null) {
          signaled = true;
          controller.add((file: File(event.path), existed: false));
        }
      }
    }();
    () async {
      final initFiles = (await dir.list().where((entity) {
        if (entity is! File) return false;
        return pattern.firstMatch(entity.uri.path) != null;
      }).toList());

      var records = <(File, DateTime)>[];
      for (var file in initFiles) {
        records.add(((file as File), await file.lastModified()));
      }
      mergeSort(records,
          compare: (l, r) => r.$2.difference(l.$2).inMilliseconds);

      if (records.isNotEmpty && signaled == false) {
        controller.add((file: records.first.$1, existed: true));
      }
    }();
    return controller.stream;
  }
}
