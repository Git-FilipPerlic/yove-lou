import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yove_lou/src/deck.dart';
import 'package:yove_lou/src/store.dart';

void main() {
  test('saved sets round-trip and drop missing files', () async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    final dir = Directory.systemTemp.createTempSync('sets_test');
    final real = File('${dir.path}/one.mp3')..writeAsStringSync('x');

    Store.saveSet('Friday', [
      Track(real.path, 'one.mp3'),
      const Track('/nope/gone.mp3', 'gone.mp3'),
    ], [
      Track(real.path, 'one.mp3'),
    ]);
    Store.saveSet('alpha', const [], const []);

    expect(Store.setNames(), ['alpha', 'Friday']);
    expect(Store.setCounts('Friday'), (2, 1));

    final loaded = Store.loadSet('Friday')!;
    expect(loaded.$1.map((t) => t.name), ['one.mp3']); // missing one dropped
    expect(loaded.$2.length, 1);

    Store.deleteSet('Friday');
    expect(Store.setNames(), ['alpha']);
    expect(Store.loadSet('Friday'), isNull);
    dir.deleteSync(recursive: true);
  });
}
