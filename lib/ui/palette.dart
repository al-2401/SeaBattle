import 'package:flutter/material.dart';

/// Colours of a cold dusk seen through coated periscope glass.
class Palette {
  const Palette._();

  static const Color skyHigh = Color(0xFF0A1A22);
  static const Color skyMid = Color(0xFF16333B);
  static const Color skyLow = Color(0xFF3C6462);
  static const Color haze = Color(0xFF6E9A8C);

  static const Color seaFar = Color(0xFF2A565C);
  static const Color seaMid = Color(0xFF0D242B);
  static const Color seaNear = Color(0xFF04131A);
  static const Color foam = Color(0xFFBFE8DC);

  static const Color hull = Color(0xFF020609);
  static const Color hullRim = Color(0xFF6D958C);

  static const Color glassTint = Color(0xFF39D9A2);
  static const Color reticle = Color(0xFF9CF7C8);
  static const Color reticleDim = Color(0xFF3C7F68);

  static const Color bezel = Color(0xFF0D1113);
  static const Color bezelEdge = Color(0xFF2A3236);
  static const Color rubber = Color(0xFF121618);

  static const Color lamp = Color(0xFFFFB347);
  static const Color lampOff = Color(0xFF3A2E1C);
  static const Color alarm = Color(0xFFE2503A);
  static const Color steel = Color(0xFF7B8A90);

  static const Color fire = Color(0xFFFFC46B);
  static const Color smoke = Color(0xFF1A2124);

  // Free-standing instruments around the eyepiece: olive enamel on dark
  // steel, brass fittings, cream lettering, green phosphor on the radar.
  static const Color enamel = Color(0xFF3F4A38);
  static const Color enamelDark = Color(0xFF262D23);
  static const Color plateSteel = Color(0xFF2B302F);
  static const Color brass = Color(0xFFB8914A);
  static const Color brassDark = Color(0xFF6B5327);
  static const Color cream = Color(0xFFE9DDBF);
  static const Color readoutWindow = Color(0xFF0B0D0C);
  static const Color phosphor = Color(0xFF5CFF8A);
  static const Color phosphorDim = Color(0xFF0E3A1E);
  static const Color readyGreen = Color(0xFF52E36A);
}

/// Stencilled cabinet lettering.
const TextStyle kStencil = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Courier New', 'DejaVu Sans Mono'],
  letterSpacing: 2,
  fontWeight: FontWeight.w700,
);
