// shaders/blackhole/disk_fragment.glsl
// Kerr accretion disk shader with frame dragging and Doppler beaming

precision highp float;

varying vec2 vUv;
varying vec3 vPosition;

uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uCamPos;

// Physics parameters
uniform float uMass;
uniform float uSpin; // Kerr spin parameter (0 = Schwarzschild, ~1 = extremal)

// Accretion disk parameters
uniform float uDiskInner;
uniform float uDiskOuter;
uniform float uDiskRotationSpeed;

// Visual parameters
uniform float uGlowIntensity;

const float PI = 3.14159265359;

// Hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Frame dragging angular velocity for Kerr black hole
// ω = 2Mar / (r³ + a²r + 2Ma²)
float frameDraggingOmega(float r) {
    float a = uSpin * uMass;
    float numerator = 2.0 * uMass * a * r;
    float denominator = r * r * r + a * a * r + 2.0 * uMass * a * a;
    return numerator / max(denominator, 0.001);
}

void main() {
    // Get position on disk (vPosition is in world space on the ring)
    vec3 diskPos = vPosition;
    float r = length(diskPos.xy);
    float angle = atan(diskPos.y, diskPos.x);

    // Temperature gradient (hotter = bluer closer to center)
    // For Kerr, inner disk is MUCH hotter due to closer ISCO
    float temp = smoothstep(uDiskOuter, uDiskInner, r);
    temp = pow(temp, 0.7); // More gradual falloff

    // === KERR EFFECTS ===

    // Frame dragging effect - spacetime itself rotates
    float frameDrag = frameDraggingOmega(r);

    // Orbital velocity (Keplerian + frame dragging)
    // For Kerr, velocity is higher than Schwarzschild
    float kerrBoost = 1.0 + uSpin * 0.5;
    float orbitalVel = kerrBoost / sqrt(max(r, 0.1));

    // Total rotation includes frame dragging
    float totalRotation = uTime * (uDiskRotationSpeed * orbitalVel + frameDrag * 2.0);
    float rotAngle = angle - totalRotation;

    // === DOPPLER SHIFT & BEAMING ===

    // Doppler factor: positive = approaching (blueshift), negative = receding (redshift)
    float dopplerFactor = sin(rotAngle);

    // Relativistic Doppler beaming - much stronger for fast-rotating Kerr
    // γ factor approximation
    float relativisticBoost = 1.0 + uSpin * 0.7;
    float beaming = 1.0 + dopplerFactor * 0.6 * relativisticBoost;

    // Color based on Doppler shift - more extreme for Kerr
    vec3 blueshifted = vec3(0.2, 0.5, 1.2);   // Intense blue (approaching)
    vec3 neutral = vec3(1.0, 0.85, 0.5);      // Yellow-orange
    vec3 redshifted = vec3(1.2, 0.2, 0.0);    // Deep red (receding)

    vec3 diskColor;
    float shiftStrength = abs(dopplerFactor) * (0.5 + uSpin * 0.5);
    if (dopplerFactor > 0.0) {
        diskColor = mix(neutral, blueshifted, shiftStrength);
    } else {
        diskColor = mix(neutral, redshifted, shiftStrength);
    }

    // Temperature contribution (hotter = whiter, especially near ISCO)
    vec3 hotWhite = vec3(1.5, 1.4, 1.2);
    diskColor = mix(diskColor, hotWhite, temp * 0.8);

    // Brightness with temperature and beaming
    // Inner regions are EXTREMELY bright for Kerr
    float brightness = (temp * 4.0 + 0.8) * beaming;
    diskColor *= brightness;

    // === TURBULENCE ===

    // Multi-scale turbulence
    float turb1 = noise(vec2(r * 6.0, angle * 3.0 + uTime * 0.4));
    float turb2 = noise(vec2(r * 15.0, angle * 8.0 - uTime * 0.6));
    float turbulence = turb1 * 0.6 + turb2 * 0.4;
    diskColor *= 0.5 + turbulence * 1.0;

    // === EDGE FALLOFF ===

    // Sharp inner edge (ISCO), softer outer edge
    float innerEdge = smoothstep(uDiskInner - 0.15, uDiskInner + 0.2, r);
    float outerEdge = 1.0 - smoothstep(uDiskOuter - 0.8, uDiskOuter + 0.2, r);
    float edgeFalloff = innerEdge * outerEdge;

    diskColor *= edgeFalloff;

    // === GLOW EFFECTS ===

    // Intense inner edge glow (ISCO region)
    float innerGlow = exp(-(r - uDiskInner) * 2.5) * uGlowIntensity * 1.5;
    diskColor += vec3(1.2, 0.9, 0.4) * innerGlow;

    // Subtle outer glow
    float outerGlow = exp(-(uDiskOuter - r) * 1.0) * uGlowIntensity * 0.3;
    diskColor += vec3(0.8, 0.6, 0.3) * outerGlow;

    // === VIEW ANGLE EFFECTS ===

    // Alpha based on edge falloff
    float alpha = edgeFalloff * 0.95;

    // Disk appears dimmer when viewed edge-on
    vec3 viewDir = normalize(uCamPos - diskPos);
    float viewAngleFade = abs(viewDir.z);
    viewAngleFade = smoothstep(0.0, 0.4, viewAngleFade);

    diskColor *= mix(0.2, 1.0, viewAngleFade);
    alpha *= mix(0.3, 1.0, viewAngleFade);

    // Gamma correction for more vibrant colors
    diskColor = pow(diskColor, vec3(0.9));

    gl_FragColor = vec4(diskColor, alpha);
}
