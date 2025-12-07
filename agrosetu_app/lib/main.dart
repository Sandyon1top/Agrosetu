import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const AgroSetuApp());
}

class AgroSetuApp extends StatelessWidget {
  const AgroSetuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroSetu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2E7D32),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF4CAF50),
        ),
        fontFamily: 'Poppins',
      ),
      home: const LoginScreen(),
    );
  }
}