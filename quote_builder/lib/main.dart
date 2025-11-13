import 'package:flutter/material.dart';
import 'package:quote_builder/screens/quote_builder_page.dart';

// Main function to run the app
void main() {
  runApp(const QuoteBuilderApp());
}

// MaterialApp widget: The root of your app
class QuoteBuilderApp extends StatelessWidget {
  const QuoteBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Quote Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // Define a modern, clean theme
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
        //
        // ----------------- THIS IS THE FIX -----------------
        //
        // It should be 'CardThemeData', not 'CardTheme'
        //
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A2530),
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF334155),
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF475569),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ),
      // The home page is now loaded from its own file
      home: const QuoteBuilderPage(),
    );
  }
}