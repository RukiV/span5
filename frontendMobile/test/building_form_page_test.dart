import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/pages/building/building_form_page.dart';
import 'package:fbs/models/building.dart';
import 'form_test_utils.dart';

void main() {
  group('BuildingFormPage', () {
    testWidgets('skep-modus: titel, velde en STOOR-save', (tester) async {
      await pumpForm(tester, const BuildingFormPage());

      expect(find.text("Nuwe Gebou"), findsOneWidget);
      expect(find.text("Terrein"), findsOneWidget);
      expect(find.text("Naam"), findsOneWidget);
      expect(find.text("Tipes"), findsOneWidget);
      expect(find.text("STOOR"), findsOneWidget);
      expect(find.text("Kanselleer"), findsNothing);
      expect(find.text("KI Voorstelle"), findsOneWidget);
    });

    testWidgets('skep-modus: leë naam toon "Vereis"', (tester) async {
      await pumpForm(tester, const BuildingFormPage());

      await tester.tap(find.text("STOOR"));
      await tester.pumpAndSettle();

      expect(find.text("Vereis"), findsWidgets);
    });

    testWidgets('wysig-modus: titel, naam-voorafvul, potlood na OPDATEER',
        (tester) async {
      final building = Building(
        id: 2,
        name: "Regsgebou",
        types: const ['admin'],
        locationId: 1,
      );
      await pumpForm(tester, BuildingFormPage(building: building));

      expect(find.text("Regsgebou"), findsWidgets);
      expect(find.text("OPDATEER"), findsNothing);
      expect(find.text("KLAAR"), findsOneWidget);
      expect(fieldIgnoring(tester), isTrue);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text("Wysig Gebou"), findsOneWidget);
      expect(find.text("OPDATEER"), findsOneWidget);
      expect(find.text("KLAAR"), findsNothing);
      expect(fieldIgnoring(tester), isFalse);
    });

    testWidgets('wysig-modus: mislukte stoor toon foutboodskap',
        (tester) async {
      final building = Building(
        id: 2,
        name: "Regsgebou",
        types: const ['admin'],
        locationId: 1,
      );
      await pumpForm(tester, BuildingFormPage(building: building));

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.text("OPDATEER"));
      await tester.pumpAndSettle();

      expect(find.text("Kon nie opdateer nie."), findsOneWidget);
    });
  });
}
