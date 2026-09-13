import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/pages/rooms/room_form_page.dart';
import 'package:fbs/models/user_session.dart';
import 'form_test_utils.dart';

void main() {
  group('RoomFormPage', () {
    testWidgets('skep-modus: titel, velde en STOOR', (tester) async {
      await pumpForm(tester, const RoomFormPage());

      expect(find.text("Nuwe Lokaal"), findsOneWidget);
      expect(find.text("Gebou"), findsOneWidget);
      expect(find.text("Tipe"), findsOneWidget);
      expect(find.text("Kapasiteit"), findsOneWidget);
      expect(find.text("STOOR"), findsOneWidget);
      expect(find.text("Kanselleer"), findsOneWidget);
      expect(find.text("VERWYDER LOKAAL"), findsNothing);
    });

    testWidgets('skep-modus: leë naam toon "Vereis"', (tester) async {
      await pumpForm(tester, const RoomFormPage());

      await tester.tap(find.text("STOOR"));
      await tester.pumpAndSettle();

      expect(find.text("Vereis"), findsWidgets);
    });

    testWidgets('wysig-modus: voorafvul, kyk-modus, potlood, verwyder',
        (tester) async {
      await pumpForm(tester, RoomFormPage(room: sampleRoom()));

      expect(find.text("R101"), findsWidgets);
      expect(find.text("KLAAR"), findsOneWidget);
      expect(fieldIgnoring(tester), isTrue);
      expect(find.text("VERWYDER LOKAAL"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text("Wysig Lokaal"), findsOneWidget);
      expect(find.text("OPDATEER"), findsOneWidget);
      expect(fieldIgnoring(tester), isFalse);
      expect(find.text("VERWYDER LOKAAL"), findsOneWidget);
    });

    testWidgets('wysig-modus: mislukte stoor toon foutboodskap',
        (tester) async {
      await pumpForm(tester, RoomFormPage(room: sampleRoom()));

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.text("OPDATEER"));
      await tester.pumpAndSettle();

      expect(find.text("Kon nie opdateer nie."), findsOneWidget);
    });

    testWidgets('sonder rooms.manage-reg is verwyder-knoppie weg',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      seedLocationData();
      UserSession.rights = [];
      await tester.pumpWidget(wrap(RoomFormPage(room: sampleRoom())));
      await tester.pumpAndSettle();

      expect(find.text("VERWYDER LOKAAL"), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });
  });
}
