// En lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'dashboard_mobile.dart';
import 'dashboard_desktop.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si el ancho de la pantalla es mayor a 800px (Modo PC/Monitor)
        if (constraints.maxWidth > 800) {
          return const DashboardDesktop(); 
        }
        // Si es un celular o una ventana chica
        return const DashboardMobile();
      },
    );
  }
}