import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/app/app.dart';

void main() {
  testWidgets('AstroManager application starts', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AstroManagerApp()));

    expect(find.text('Architecture ready'), findsOneWidget);
  });
}
