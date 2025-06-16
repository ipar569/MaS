import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        // Primary colors
        primary: const Color(0xFFFFF957), // Bright yellow
        onPrimary: const Color(0xFF19191A), // Dark background
        primaryContainer: const Color(0xFFFFF957).withOpacity(0.2),
        onPrimaryContainer: const Color(0xFF19191A),
        
        // Secondary colors
        secondary: const Color(0xFFFFF957).withOpacity(0.7),
        onSecondary: const Color(0xFF19191A),
        secondaryContainer: const Color(0xFFFFF957).withOpacity(0.1),
        onSecondaryContainer: const Color(0xFF19191A),
        
        // Background colors
        background: const Color(0xFF19191A),
        onBackground: Colors.white,
        surface: const Color(0xFF2A2A2B),
        onSurface: Colors.white,
        
        // Error colors
        error: const Color(0xFFFF5252),
        onError: Colors.white,
        errorContainer: const Color(0xFFFF5252).withOpacity(0.2),
        onErrorContainer: Colors.white,
        
        // Additional colors
        surfaceVariant: const Color(0xFF3A3A3B),
        onSurfaceVariant: Colors.white.withOpacity(0.7),
        outline: const Color(0xFFFFF957).withOpacity(0.3),
        outlineVariant: const Color(0xFFFFF957).withOpacity(0.1),
        
        brightness: Brightness.dark,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2A2A2B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFFFFF957).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF19191A),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFFFF957)),
      ),
      scaffoldBackgroundColor: const Color(0xFF19191A),
      iconTheme: const IconThemeData(
        color: Color(0xFFFFF957),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFFF957),
        foregroundColor: Color(0xFF19191A),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF957),
          foregroundColor: const Color(0xFF19191A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFFF957),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        // Primary colors
        primary: Colors.amber[700]!, // More visible yellow for accents
        onPrimary: Colors.white,
        primaryContainer: Colors.amber[100]!,
        onPrimaryContainer: const Color(0xFF19191A),
        
        // Secondary colors
        secondary: Colors.amber[600]!,
        onSecondary: Colors.white,
        secondaryContainer: Colors.amber[50]!,
        onSecondaryContainer: const Color(0xFF19191A),
        
        // Background colors
        background: const Color(0xFFF7F7F7),
        onBackground: const Color(0xFF19191A),
        surface: const Color(0xFFF7F7F7),
        onSurface: const Color(0xFF19191A),
        
        // Error colors
        error: const Color(0xFFFF5252),
        onError: Colors.white,
        errorContainer: const Color(0xFFFF5252).withOpacity(0.2),
        onErrorContainer: const Color(0xFF19191A),
        
        // Additional colors
        surfaceVariant: Colors.grey[100]!,
        onSurfaceVariant: const Color(0xFF19191A).withOpacity(0.7),
        outline: Colors.amber[700]!.withOpacity(0.3),
        outlineVariant: Colors.amber[700]!.withOpacity(0.1),
        
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFF7F7F7),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.amber[700]!.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F7F7),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFFFC107)),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      iconTheme: IconThemeData(
        color: Colors.amber[700],
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.amber[700],
        foregroundColor: const Color(0xFF19191A),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber[700],
          foregroundColor: const Color(0xFF19191A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.amber[700],
        ),
      ),
    );
  }
} 