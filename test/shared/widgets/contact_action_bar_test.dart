import 'package:attendix/shared/widgets/contact/contact_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows Anrufen, WhatsApp, Telegram and E-Mail', (tester) async {
    await tester.pumpWidget(_wrap(const ContactActionBar(
      phone: '0176 1234567',
      email: 'lena@example.org',
    )));

    expect(find.text('Anrufen'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('E-Mail'), findsOneWidget);
    expect(find.bySemanticsLabel('Per WhatsApp schreiben'), findsOneWidget);
  });

  testWidgets('without a usable number only E-Mail is offered',
      (tester) async {
    await tester.pumpWidget(_wrap(const ContactActionBar(
      phone: 'keine',
      email: 'lena@example.org',
    )));

    expect(find.text('E-Mail'), findsOneWidget);
    expect(find.text('Anrufen'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Telegram'), findsNothing);
  });

  testWidgets('takes no space without contact data', (tester) async {
    await tester.pumpWidget(_wrap(const ContactActionBar(phone: null)));

    expect(find.byType(InkWell), findsNothing);
    expect(tester.getSize(find.byType(ContactActionBar)), Size.zero);
  });

  testWidgets('tiles are at least 44 px high', (tester) async {
    await tester.pumpWidget(_wrap(const ContactActionBar(phone: '0176 1234567')));

    for (final tile in tester.widgetList<InkWell>(find.byType(InkWell))) {
      expect(tester.getSize(find.byWidget(tile)).height,
          greaterThanOrEqualTo(44));
    }
  });
}
