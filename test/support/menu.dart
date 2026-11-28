import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ouvre le menu « Plus » de l'écran des capteurs et choisit une ligne.
Future<void> openMenuEntry(WidgetTester pTester, String pLabel) async {
  await pTester.tap(find.byTooltip('Plus d\'options'));
  await pTester.pumpAndSettle();
  final vEntry = find.widgetWithText(PopupMenuItem<int>, pLabel);
  await pTester.ensureVisible(vEntry);
  await pTester.pumpAndSettle();
  await pTester.tap(vEntry);
  await pTester.pumpAndSettle();
}

/// Ouvre le menu « Plus » et dit si une ligne y figure ; le menu est refermé ensuite.
Future<bool> menuHas(WidgetTester pTester, String pLabel) async {
  await pTester.tap(find.byTooltip('Plus d\'options'));
  await pTester.pumpAndSettle();
  final vFound = find.widgetWithText(PopupMenuItem<int>, pLabel).evaluate().isNotEmpty;
  await pTester.tapAt(const Offset(1, 1));
  await pTester.pumpAndSettle();

  return vFound;
}
