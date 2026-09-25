import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a very long message scrolls instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final long = List.generate(80, (i) => 'Line $i — A1 · Shelf 2 · P3').join('\n');
    var confirmed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => VerificationDialog(
                  title: 'Delete copies',
                  content: long,
                  confirmWord: 'DELETE',
                  onConfirm: () => confirmed = true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('I understand the consequences'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('I understand the consequences'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Initiate Deletion'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Initiate Deletion'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
