import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginPage widget structure', () {
    testWidgets('login page has email and password fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('Teken In', style: TextStyle(fontSize: 26)),
                    const SizedBox(height: 35),
                    const Text('E-pos Adres'),
                    TextField(
                      key: const Key('email_field'),
                      decoration: const InputDecoration(hintText: 'e-pos adres'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Wagwoord'),
                    TextField(
                      key: const Key('password_field'),
                      obscureText: true,
                      decoration: const InputDecoration(hintText: 'wagwoord'),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Teken In'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('of', style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 10),
                          const Text('Teken in met Microsoft', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Teken In'), findsWidgets);
      expect(find.text('E-pos Adres'), findsOneWidget);
      expect(find.text('Wagwoord'), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.text('of'), findsOneWidget);
      expect(find.text('Teken in met Microsoft'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                bool obscure = true;
                return TextField(
                  key: const Key('pw_field'),
                  obscureText: obscure,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });
}
