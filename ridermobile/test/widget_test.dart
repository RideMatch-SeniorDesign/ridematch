import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:ridermobile/main.dart";

void main() {
  testWidgets("shows bootstrap loading state", (WidgetTester tester) async {
    await tester.pumpWidget(const RiderMobileApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
