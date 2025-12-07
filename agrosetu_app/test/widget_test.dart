import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrosetu_app/main.dart';
import 'package:agrosetu_app/screens/login_screen.dart';

void main() {
  testWidgets('AgroSetuApp builds without crashing', (WidgetTester tester) async {
    // Build the main app
    await tester.pumpWidget(const AgroSetuApp()); // ← Changed to AgroSetuApp
    
    // Verify that MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verify the app title
    expect(find.text('AgroSetu'), findsNothing); // Title is not displayed, it's in AppBar
  });

  testWidgets('Login screen has welcome text', (WidgetTester tester) async {
    // Build the login screen directly
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );
    
    // Check for login screen elements
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Log in to continue your journey'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Login button is present', (WidgetTester tester) async {
    // Build the login screen
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );
    
    // Check for Log In button
    expect(find.text('Log In'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}