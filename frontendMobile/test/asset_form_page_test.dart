import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/pages/asset/asset_form_page.dart';
import 'form_test_utils.dart';

void main() {
  group('AssetFormPage', () {
    testWidgets('skep-modus: titel, velde, KANS-president vorm knoppie',
        (tester) async {
      await pumpForm(tester, const AssetFormPage());

      expect(find.text("Nuwe Bate"), findsOneWidget);
      expect(find.text("STOOR BATE"), findsOneWidget);
      expect(find.text("OPDATEER BATE"), findsNothing);
      expect(find.text("Kanselleer"), findsNothing);
      expect(find.text("Naam"), findsOneWidget);
      expect(find.text("Serienommer"), findsOneWidget);
      expect(find.text("Handelsmerk"), findsOneWidget);
      expect(find.text("Bate Tipe"), findsOneWidget);
      expect(find.text("Buite"), findsOneWidget);
      expect(find.text("Status"), findsOneWidget);
    });

    testWidgets('skep-modus: leë ligging toon foutboodskap', (tester) async {
      await pumpForm(tester, const AssetFormPage());

      await tester.tap(find.text("STOOR BATE"));
      await tester.pumpAndSettle();

      expect(find.text("Kies 'n volledige ligging"), findsOneWidget);
    });

    testWidgets('wysig-modus: voorafvul, OPDATEER, geen Kanselleer',
        (tester) async {
      await pumpForm(tester, AssetFormPage(asset: sampleAsset()));

      expect(find.text("Wysig Bate"), findsOneWidget);
      expect(find.text("OPDATEER BATE"), findsOneWidget);
      expect(find.text("Nuwe Bate"), findsNothing);
      expect(find.text("Kanselleer"), findsNothing);
      expect(find.text("Projektor"), findsWidgets);
      expect(find.text("SR123"), findsOneWidget);
    });

    testWidgets('wysig-modus: stoor misluk — vorm bly staan sonder fout',
        (tester) async {
      await pumpForm(tester, AssetFormPage(asset: sampleAsset()));

      await tester.tap(find.text("OPDATEER BATE"));
      await tester.pumpAndSettle();

      expect(find.text("Wysig Bate"), findsOneWidget);
    });
  });
}
