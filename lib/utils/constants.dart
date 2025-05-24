import 'package:flutter/material.dart';

// Colores principales
const Color kPrimaryColor = Color(0xFFB1103C); // Rojo oscuro/granate del diseño
const Color kBackgroundColor = Colors.white;
const Color kSecondaryColor = Color(0xFFf44336); // Rojo más claro para el bottom nav bar

// Decoraciones comunes
BoxDecoration backgroundDecoration = const BoxDecoration(
  image: DecorationImage(
    image: AssetImage('assets/images/Fondo blanco.png'),
    fit: BoxFit.cover,
  ),
);

// Estilos de texto
const TextStyle kTitleStyle = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.bold,
  color: kPrimaryColor,
);

const TextStyle kSubtitleStyle = TextStyle(
  fontSize: 18,
  color: Colors.black54,
);

const TextStyle kButtonTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
);

// Estilos de botones
ButtonStyle kPrimaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: kPrimaryColor,
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(30),
  ),
  padding: const EdgeInsets.symmetric(vertical: 16),
  minimumSize: const Size(double.infinity, 56),
);

ButtonStyle kOutlinedButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: kPrimaryColor,
  side: const BorderSide(color: kPrimaryColor),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(30),
  ),
  padding: const EdgeInsets.symmetric(vertical: 16),
  minimumSize: const Size(double.infinity, 56),
);