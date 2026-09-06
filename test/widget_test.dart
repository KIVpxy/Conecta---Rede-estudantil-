import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_autoral/app/app.dart';

void main() {
  testWidgets('app abre na tela de login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProjetoAutoralApp()));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo de volta 👋'), findsOneWidget);
  });
}
