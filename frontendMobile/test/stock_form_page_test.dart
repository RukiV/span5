import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/pages/stock/stock_form_page.dart';
import 'package:fbs/models/user_session.dart';
import 'form_test_utils.dart';

void main() {
  group('StockFormPage', () {
    testWidgets('skep-modus: titel, velde, Kanselleer, STOOR', (tester) async {
      await pumpForm(tester, const StockFormPage());

      expect(find.text("Nuwe Voorraad"), findsOneWidget);
      expect(find.text("STOOR VOORRAAD"), findsOneWidget);
      expect(find.text("OPDATEER VOORRAAD"), findsNothing);
      expect(find.text("Kanselleer"), findsNothing);
      expect(find.text("Naam"), findsOneWidget);
      expect(find.text("Handelsmerk"), findsOneWidget);
      expect(find.text("Tipe"), findsOneWidget);
      expect(find.text("Hoeveelheid"), findsOneWidget);
      expect(find.text("Minimum Voorraad"), findsOneWidget);
      expect(find.text("Boks Totaal"), findsOneWidget);
      expect(find.text("Beskrywing"), findsOneWidget);
    });

    testWidgets('skep-modus: leë ligging toon foutboodskap', (tester) async {
      await pumpForm(tester, const StockFormPage());

      await tester.ensureVisible(find.text("STOOR VOORRAAD"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("STOOR VOORRAAD"));
      await tester.pumpAndSettle();

      expect(find.text("Kies 'n volledige ligging"), findsOneWidget);
    });

    testWidgets('wysig-modus: voorafvul, OPDATEER, Kanselleer, Verwyder',
        (tester) async {
      await pumpForm(tester, StockFormPage(stock: sampleStock()));

      expect(find.text("Wysig Voorraad"), findsOneWidget);
      expect(find.text("OPDATEER VOORRAAD"), findsOneWidget);
      expect(find.text("STOOR VOORRAAD"), findsNothing);
      expect(find.text("Kanselleer"), findsNothing);
      expect(find.text("VERWYDER VOORRAAD"), findsOneWidget);
      expect(find.text("Projektorlamp"), findsOneWidget);
      expect(find.text("4"), findsWidgets);
    });

    testWidgets('sonder stock.manage-reg is verwyder weg', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      seedLocationData();
      UserSession.rights = <String>[];
      await tester.pumpWidget(wrap(StockFormPage(stock: sampleStock())));
      await tester.pumpAndSettle();

      expect(find.text("VERWYDER VOORRAAD"), findsNothing);
    });

    testWidgets('wysig-modus: mislukte stoor bly staan', (tester) async {
      await pumpForm(tester, StockFormPage(stock: sampleStock()));

      await tester.ensureVisible(find.text("OPDATEER VOORRAAD"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("OPDATEER VOORRAAD"));
      await tester.pumpAndSettle();

      expect(find.text("Wysig Voorraad"), findsOneWidget);
    });
  });
}
