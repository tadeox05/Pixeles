import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/dashboard_screen.dart';

void main() {
  // Asegura que los bindings de Flutter estén listos antes de ejecutar código asíncrono
  WidgetsFlutterBinding.ensureInitialized();
  
  
  runApp(const PixelesApp());
}

class PixelesApp extends StatelessWidget {
  const PixelesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixeles Ventas',
      debugShowCheckedModeBanner: false,
      
      theme: ThemeData(
        useMaterial3: true,
        
        scaffoldBackgroundColor: const Color(0xFF0F172A), 
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,       
        
          surface: const Color(0xFF1E293B),  
        ),
        
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme, 
        ),
        
       
        cardTheme: const CardThemeData(
          elevation: 4,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const DashboardScreen(), 
    );
  }
}

