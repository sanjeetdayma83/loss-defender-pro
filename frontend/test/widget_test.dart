import 'package:flutter_test/flutter_test.dart';
import 'package:loss_defender_pro/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Loss Defender Pro app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LossDefenderApp()));
    await tester.pumpAndSettle();
    expect(find.byType(LossDefenderApp), findsOneWidget);
  });
}
