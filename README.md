# Tail File

So you want to continuously read from a file like `tail -f` on Linux, but you
want to stay in dart. This is the package for you.

Why does this package exist? I wanted to parse structured log lines from a
running service. I also wanted to watch for new files being created; so bonus:
you can use `WatchPath`.

Run into a problem? File a bug or send a PR.

## Bytes?

```dart
final tail = TailFile(File('/var/log/syslog'));
await for (var line in tail.stream) {
  print('system log: $line');
}
```

## Strings?

```dart
final tail = TailFile(File('/var/log/syslog'));
await for (var line in tail.asStrings) {
  print('system log: $line');
}
```

## Lines?

```dart
final tail = TailFile(File('/var/log/syslog'));
await for (var line in tail.asLines) {
  print('system log: $line');
}
```

## Watch files for changes?

```dart
for (var record in WatchPath()
    .forPattern(Directory('/path/to/folder', RegExp(r'file-.*')))) {
  print('new file detected: $record');
}
```

## Coverage

Tested on Windows, Linux, and MacOS.

```shell
dart pub global activate coverde
flutter test --coverage
coverde check -i coverage/lcov.info 100

lib/src/extensions.dart (100.00% - 2/2)
lib/tail_file.dart (100.00% - 3/3)
lib/src/tail_file.dart (100.00% - 33/33)
lib/src/watch_path.dart (100.00% - 22/22)

GLOBAL:
100.00% - 60/60
```
