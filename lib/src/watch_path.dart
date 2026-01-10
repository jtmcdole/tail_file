import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';

import '../tailf.dart';

class WatchPathBase implements WatchPath {
  @override
  Stream<FileEvent> forPattern(Directory dir, RegExp pattern) {
    late StreamController<FileEvent> controller;
    StreamSubscription<FileSystemEvent>? subscription;

    controller = StreamController<FileEvent>(
      onListen: () {
        bool signaled = false;
        subscription =
            dir.watch(events: FileSystemEvent.create).listen((event) {
          if (event is! FileSystemCreateEvent) return;
          if (pattern.firstMatch(event.path) != null) {
            signaled = true;
            controller.add((file: File(event.path), existed: false));
          }
        }, onError: (e, s) {
          if (!controller.isClosed) controller.addError(e, s);
        });

        () async {
          try {
            final initFiles = (await dir.list().where((entity) {
              if (entity is! File) return false;
              return pattern.firstMatch(entity.uri.path) != null;
            }).toList());

            var records = <(File, DateTime)>[];
            for (var file in initFiles) {
              if (controller.isClosed) return;
              try {
                records.add(((file as File), await file.lastModified()));
              } catch (_) {}
            }

            if (controller.isClosed) return;

            mergeSort(records,
                compare: (l, r) => r.$2.difference(l.$2).inMilliseconds);

            if (records.isNotEmpty && signaled == false) {
              controller.add((file: records.first.$1, existed: true));
            }
          } catch (e, s) {
            if (!controller.isClosed) controller.addError(e, s);
          }
        }();
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
