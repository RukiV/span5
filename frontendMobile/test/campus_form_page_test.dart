import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/pages/campus/campus_form_page.dart';
import 'form_test_utils.dart';

void main() {
  group('CampusFormPage', () {
    testWidgets('skep-modus: titel, velde en STOOR', (tester) async {
      await pumpForm(tester, const CampusFormPage());

      expect(find.text("Nuwe Terrein"), findsOneWidget);
      expect(find.text("Naam"), findsOneWidget);
      expect(find.text("Tipe"), findsOneWidget);
      expect(find.text("Tipe / Kode"), findsNothing);
      expect(find.text("Toegelate Radius (meter)"), findsOneWidget);
      expect(find.text("Kanselleer"), findsOneWidget);
      expect(find.text("STOOR"), findsOneWidget);
      expect(find.text("KI Voorstelle"), findsOneWidget);
    });

    testWidgets('skep-modus: radius begin by 110', (tester) async {
      await pumpForm(tester, const CampusFormPage());

      expect(find.text("110"), findsOneWidget);
    });

    testWidgets('skep-modus: leë naam toon "Vereis"', (tester) async {
      await pumpForm(tester, const CampusFormPage());

      await tester.ensureVisible(find.text("STOOR"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("STOOR"));
      await tester.pumpAndSettle();

      expect(find.text("Vereis"), findsWidgets);
    });

    testWidgets('wysig-modus: voorafvul, Tipe / Kode, potlood na OPDATEER',
        (tester) async {
      await pumpForm(tester, CampusFormPage(campus: sampleCampus()));

      expect(find.text("Sterland"), findsWidgets);
      expect(find.text("Tipe / Kode"), findsOneWidget);
      expect(find.text("KAMPUS"), findsOneWidget);
      expect(find.text("KLAAR"), findsOneWidget);
      expect(fieldIgnoring(tester), isTrue);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text("Wysig Terrein"), findsOneWidget);
      expect(find.text("OPDATEER"), findsOneWidget);
      expect(fieldIgnoring(tester), isFalse);
    });

    testWidgets('wysig-modus: mislukte stoor toon foutboodskap',
        (tester) async {
      await pumpForm(tester, CampusFormPage(campus: sampleCampus()));

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text("OPDATEER"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("OPDATEER"));
      await tester.pumpAndSettle();

      expect(find.text("Kon nie opdateer nie. Probeer weer."), findsOneWidget);
    });
  });
}
