import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raahnuma/main.dart';

void main() {
  testWidgets('App launches and shows UserTypePage', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('राहनुमा'), findsWidgets);
    expect(find.text('"your guide to safer streets"'), findsOneWidget);
    expect(find.text('User Sign In'), findsOneWidget);
    expect(find.text('Administrator Sign In'), findsOneWidget);
  });

  testWidgets('User Sign In navigates to LoginPage', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('User Sign In'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Enter User ID'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Enter Password'), findsOneWidget);
  });

  testWidgets('Empty login shows error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('User Sign In'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid! Both fields are required.'), findsOneWidget);
  });

  testWidgets('Valid login goes to UserPage', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('User Sign In'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Enter User ID'), 'testuser');
    await tester.enterText(find.widgetWithText(TextField, 'Enter Password'), 'testpass');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('User Dashboard'), findsOneWidget);
  });

  testWidgets('Wrong admin credentials shows error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrator Sign In'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Enter Admin ID'), 'wrong');
    await tester.enterText(find.widgetWithText(TextField, 'Enter Password'), 'wrong');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid Admin ID or Password.'), findsOneWidget);
  });

  testWidgets('Correct admin login goes to AdminDashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrator Sign In'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Enter Admin ID'), 'admin');
    await tester.enterText(find.widgetWithText(TextField, 'Enter Password'), 'password');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Admin Dashboard'), findsOneWidget);
  });

  testWidgets('Back button returns to landing page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('User Sign In'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('← Back'));
    await tester.pumpAndSettle();
    expect(find.text('Who are you?'), findsOneWidget);
  });
}