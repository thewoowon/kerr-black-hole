// lib/blackhole/physics.ts
// Black Hole Physics Constants and Utilities
// Units: G = c = 1 (geometrized units)

/**
 * Schwarzschild metric fundamental constants
 * All radii are expressed in units of M (black hole mass)
 */
export const SCHWARZSCHILD_PHYSICS = {
  // Event horizon radius: r_s = 2M
  EVENT_HORIZON: 2.0,

  // Photon sphere radius: r_ph = 3M
  // (unstable circular orbit for photons)
  PHOTON_SPHERE: 3.0,

  // Critical impact parameter: b_crit = 3√3 M ≈ 5.196M
  // (photons with b < b_crit get captured)
  CRITICAL_IMPACT: 3.0 * Math.sqrt(3),

  // Innermost stable circular orbit (ISCO): r_isco = 6M
  ISCO: 6.0,
} as const;

/**
 * Kerr metric constants (rotating black hole)
 * Spin parameter a = J/M (angular momentum per unit mass)
 * a = 0: Schwarzschild (non-rotating)
 * a = 1: Extremal Kerr (maximum rotation)
 */
export const KERR_PHYSICS = {
  // For extremal Kerr (a = M):
  // Event horizon: r+ = M
  EVENT_HORIZON_EXTREMAL: 1.0,

  // ISCO (prograde orbit, a ≈ 1): r_isco ≈ M
  ISCO_PROGRADE_EXTREMAL: 1.0,

  // ISCO (retrograde orbit, a ≈ 1): r_isco ≈ 9M
  ISCO_RETROGRADE_EXTREMAL: 9.0,
} as const;

/**
 * Calculate the Schwarzschild radius for a given mass
 * r_s = 2GM/c² (in SI units)
 * r_s = 2M (in geometrized units)
 */
export function schwarzschildRadius(mass: number): number {
  return 2.0 * mass;
}

/**
 * Calculate the photon sphere radius for a given mass
 * r_ph = 3M
 */
export function photonSphereRadius(mass: number): number {
  return 3.0 * mass;
}

/**
 * Calculate the critical impact parameter for a given mass
 * b_crit = 3√3 M
 */
export function criticalImpactParameter(mass: number): number {
  return 3.0 * Math.sqrt(3) * mass;
}

/**
 * Gravitational redshift factor at radius r
 * z = 1/√(1 - 2M/r) - 1
 * Returns the frequency ratio f_observed / f_emitted
 */
export function gravitationalRedshift(r: number, mass: number): number {
  const rs = schwarzschildRadius(mass);
  if (r <= rs) return 0; // Inside event horizon, no light escapes
  return Math.sqrt(1.0 - rs / r);
}

/**
 * Approximate deflection angle for light passing at impact parameter b
 * α ≈ 4M/b (weak field approximation)
 * Valid for b >> M
 */
export function deflectionAngle(b: number, mass: number): number {
  if (b < 0.01) return Math.PI; // Strong deflection, approximate
  return (4.0 * mass) / b;
}

/**
 * Check if a photon with impact parameter b will be captured
 */
export function isPhotonCaptured(b: number, mass: number): boolean {
  return b < criticalImpactParameter(mass);
}

/**
 * Normalize radius to Schwarzschild radius units
 */
export function normalizeRadius(r: number, mass: number): number {
  return r / schwarzschildRadius(mass);
}

/**
 * Calculate Kerr event horizon radius
 * r+ = M + √(M² - a²)
 * For a = 0 (Schwarzschild): r+ = 2M
 * For a → M (extremal): r+ → M
 */
export function kerrEventHorizon(mass: number, spin: number): number {
  const a = spin * mass;
  return mass + Math.sqrt(mass * mass - a * a);
}

/**
 * Calculate Kerr ISCO radius (prograde orbit)
 * Approximate formula for prograde orbits
 */
export function kerrISCOPrograde(mass: number, spin: number): number {
  const a = spin * mass;
  const z1 = 1 + Math.pow(1 - a * a / (mass * mass), 1 / 3) *
    (Math.pow(1 + a / mass, 1 / 3) + Math.pow(1 - a / mass, 1 / 3));
  const z2 = Math.sqrt(3 * a * a / (mass * mass) + z1 * z1);
  return mass * (3 + z2 - Math.sqrt((3 - z1) * (3 + z1 + 2 * z2)));
}

/**
 * Frame dragging angular velocity at radius r
 * ω = 2Mar / (r³ + a²r + 2Ma²)
 */
export function frameDraggingOmega(r: number, mass: number, spin: number): number {
  const a = spin * mass;
  const numerator = 2 * mass * a * r;
  const denominator = r * r * r + a * a * r + 2 * mass * a * a;
  return numerator / denominator;
}
