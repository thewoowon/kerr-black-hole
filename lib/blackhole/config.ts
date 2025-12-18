// lib/blackhole/config.ts
// Configurable parameters for black hole visualization

import { SCHWARZSCHILD_PHYSICS } from "./physics";

export interface BlackHoleConfig {
  // Physical parameters
  mass: number; // Black hole mass (M)
  spin: number; // Kerr spin parameter (0 = Schwarzschild, ~1 = extremal Kerr)
  observerDistance: number; // Camera distance from black hole (in units of M)

  // Visual parameters
  shadowRadius: number; // Normalized radius of the black hole shadow
  photonSphereRadius: number; // Normalized radius of photon sphere effect

  // Accretion disk parameters
  diskInnerRadius: number; // Inner edge of accretion disk (ISCO for Kerr)
  diskOuterRadius: number; // Outer edge of accretion disk
  diskThickness: number; // Vertical thickness of the disk
  diskTemperature: number; // Temperature parameter for disk coloring

  // Lensing effect parameters
  lensStrength: number; // Overall strength of gravitational lensing (0-1)
  lensSharpness: number; // Sharpness of lensing near photon sphere (0-2)

  // Rendering parameters
  vignetteStrength: number; // Vignette effect strength (0-1)
  glowIntensity: number; // Glow/bloom intensity around disk (0-2)

  // Animation parameters
  diskRotationSpeed: number; // Rotation speed of accretion disk
  cameraOrbitSpeed: number; // Speed of camera orbit
}

export const DEFAULT_CONFIG: BlackHoleConfig = {
  // Physical
  mass: 1.0,
  spin: 0.0, // Schwarzschild (non-rotating)
  observerDistance: 15.0, // Far enough to see the whole structure

  // Visual
  shadowRadius: 1.0, // Normalized to critical impact parameter
  photonSphereRadius: 1.3,

  // Accretion disk (realistic placement)
  diskInnerRadius: SCHWARZSCHILD_PHYSICS.PHOTON_SPHERE, // Start just outside photon sphere
  diskOuterRadius: SCHWARZSCHILD_PHYSICS.ISCO * 1.5, // Extend to ~9M
  diskThickness: 0.3,
  diskTemperature: 1.0,

  // Lensing
  lensStrength: 0.7,
  lensSharpness: 0.9,

  // Rendering
  vignetteStrength: 0.4,
  glowIntensity: 1.2,

  // Animation
  diskRotationSpeed: 0.1,
  cameraOrbitSpeed: 0.15,
};

export const CINEMATIC_CONFIG: BlackHoleConfig = {
  ...DEFAULT_CONFIG,
  spin: 0.5,
  observerDistance: 12.0,
  lensStrength: 0.85,
  glowIntensity: 1.5,
  vignetteStrength: 0.6,
  cameraOrbitSpeed: 0.08,
};

// Gargantua from Interstellar: rapidly rotating Kerr black hole
export const INTERSTELLAR_CONFIG: BlackHoleConfig = {
  ...DEFAULT_CONFIG,
  mass: 1.0,
  spin: 0.998, // Near-extremal Kerr (ultra-fast rotation like Gargantua)
  observerDistance: 15.0, // Match Gargantua reference
  shadowRadius: 1.0,
  photonSphereRadius: 1.5,
  diskInnerRadius: 2.6, // ISCO for Kerr with high spin
  diskOuterRadius: 12.0, // Extended disk
  diskThickness: 0.2, // Match Gargantua adiskHeight
  diskTemperature: 1.0,
  lensStrength: 0.98,
  lensSharpness: 1.4,
  glowIntensity: 2.2,
  vignetteStrength: 0.3,
  diskRotationSpeed: 0.5, // Match Gargantua adiskSpeed default
  cameraOrbitSpeed: 0.1,
};
