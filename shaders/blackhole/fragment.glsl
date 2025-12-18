// shaders/blackhole/fragment.glsl
// Schwarzschild Black Hole Gravitational Lensing Shader

precision highp float;

// Varyings from vertex shader
varying vec2 vUv;
varying vec3 vPosition;

// Time and resolution
uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uCamPos;

// Schwarzschild physics parameters
uniform float uMass;
uniform float uShadowRadius;
uniform float uPhotonSphereRadius;

// Accretion disk parameters
uniform float uDiskInner;
uniform float uDiskOuter;
uniform float uDiskThickness;
uniform float uDiskRotationSpeed;

// Lensing parameters
uniform float uLensStrength;
uniform float uLensSharpness;

// Visual parameters
uniform float uVignetteStrength;
uniform float uGlowIntensity;

// Background texture
uniform sampler2D uBgTexture;

// Constants
const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;
const float CRITICAL_IMPACT = 5.196152422706632; // 3 * sqrt(3)

// ===== UTILITY FUNCTIONS =====

// Convert fragment coordinates to NDC [-1, 1]
vec2 toNDC(vec2 fragCoord) {
    vec2 ndc = fragCoord / uResolution;
    ndc = ndc * 2.0 - 1.0;
    ndc.x *= uResolution.x / uResolution.y; // Aspect ratio correction
    return ndc;
}

// Hash function for pseudo-random noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Simple 2D noise
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

// ===== GRAVITATIONAL LENSING =====

// Approximate gravitational lensing warp function
// Models the bending of light near the black hole
float lensWarp(float r) {
    float eps = 0.0001;
    float x = max(r, eps);

    // Strong warp near photon sphere
    float k = uLensStrength;
    float s = uLensSharpness;

    // Inverse square falloff with configurable sharpness
    float warp = k / pow(x + s, 2.0);

    return r + warp;
}

// Deflection angle based on impact parameter
float deflectionAngle(float b) {
    if (b < 0.01) return PI;
    return (4.0 * uMass) / b;
}

// ===== BACKGROUND SAMPLING =====

// Sample background texture with spherical mapping
vec3 sampleBackground(vec2 dir) {
    float r = length(dir);
    float theta = atan(dir.y, dir.x);
    float phi = r * PI * 0.5;

    // Convert to UV coordinates for equirectangular mapping
    float u = (theta + PI) / TWO_PI;
    float v = phi / PI;

    // Sample background texture
    vec3 col = texture2D(uBgTexture, vec2(u, v)).rgb;

    return col;
}

// Procedural starfield for when no texture is available
vec3 proceduralStarfield(vec2 dir) {
    vec2 starCoord = dir * 10.0;
    float stars = 0.0;

    // Multiple layers of stars with different sizes
    for (float i = 0.0; i < 3.0; i++) {
        float scale = pow(2.0, i);
        vec2 coord = starCoord * scale;
        float n = noise(coord);
        stars += step(0.99 - i * 0.005, n) * (1.0 - i * 0.3);
    }

    return vec3(stars);
}

// ===== ACCRETION DISK =====

// Gravitational redshift factor
float gravitationalRedshift(float r) {
    float rs = 2.0 * uMass;
    if (r <= rs) return 0.0;
    return sqrt(1.0 - rs / r);
}

// Sample accretion disk with Doppler shift and temperature gradient
vec3 sampleDisk(float r, float angle) {
    // Check if we're in the disk range
    if (r < uDiskInner || r > uDiskOuter) {
        return vec3(0.0);
    }

    // Smooth falloff at disk edges
    float innerFalloff = smoothstep(uDiskInner, uDiskInner + 0.5, r);
    float outerFalloff = 1.0 - smoothstep(uDiskOuter - 0.5, uDiskOuter, r);
    float radialMask = innerFalloff * outerFalloff;

    if (radialMask < 0.01) return vec3(0.0);

    // Temperature gradient (hotter closer to black hole)
    float temp = 1.0 - smoothstep(uDiskInner, uDiskOuter, r);

    // Doppler shift due to orbital motion
    // Disk rotates counter-clockwise, one side approaches, one recedes
    float rotationAngle = angle - uTime * uDiskRotationSpeed;
    float dopplerShift = cos(rotationAngle) * 0.5 + 0.5;

    // Gravitational redshift (stronger closer to black hole)
    float redshift = gravitationalRedshift(r);

    // Combine temperature and Doppler effect
    float combinedShift = mix(temp, dopplerShift, 0.4) * redshift;

    // Color gradient: blue (hot, approaching) -> orange (cool, receding)
    vec3 hotColor = vec3(0.4, 0.6, 1.0);    // Blue-white (approaching side)
    vec3 coolColor = vec3(1.0, 0.4, 0.1);   // Orange-red (receding side)
    vec3 diskColor = mix(coolColor, hotColor, combinedShift);

    // Add some turbulence
    float turbulence = noise(vec2(r * 5.0, angle * 3.0 + uTime * 0.5));
    diskColor *= 0.8 + turbulence * 0.4;

    // Add intensity variation
    float intensity = temp * 1.5 + 0.5;
    diskColor *= intensity;

    // Apply radial mask
    diskColor *= radialMask;

    // Add glow effect
    float glow = exp(-abs(r - (uDiskInner + uDiskOuter) * 0.5) * 0.5) * uGlowIntensity;
    diskColor += vec3(1.0, 0.7, 0.3) * glow * 0.3;

    return diskColor;
}

// ===== MAIN SHADER =====

void main() {
    // Get fragment coordinates
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 ndc = toNDC(fragCoord);

    // Calculate radial distance and angle from center
    float r = length(ndc);
    float angle = atan(ndc.y, ndc.x);

    // Normalize to impact parameter scale
    float rNorm = r / (CRITICAL_IMPACT * 0.2); // Scale factor for visual appeal

    // === 1. EVENT HORIZON / BLACK HOLE SHADOW ===
    if (rNorm < uShadowRadius) {
        // Pure black - event horizon shadow
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // === 2. GRAVITATIONAL LENSING ===
    float warpedR = lensWarp(rNorm);

    // Calculate deflection angle
    float deflection = deflectionAngle(rNorm);
    float bentAngle = angle + deflection * 0.1; // Scale deflection for visual effect

    // Warped direction for background sampling
    vec2 warpedDir = vec2(cos(bentAngle), sin(bentAngle)) * warpedR;

    // === 3. ACCRETION DISK CONTRIBUTION ===
    vec3 diskColor = sampleDisk(warpedR * 3.0, angle); // Scale for disk radius

    // === 4. BACKGROUND SAMPLING ===
    vec3 bgColor = sampleBackground(warpedDir);

    // If background texture is not loaded, use procedural starfield
    if (length(bgColor) < 0.01) {
        bgColor = proceduralStarfield(warpedDir);
    }

    // === 5. COMBINE LAYERS ===
    vec3 color = bgColor + diskColor;

    // === 6. PHOTON SPHERE GLOW ===
    // Add a subtle glow ring at the photon sphere
    float photonDist = abs(rNorm - uPhotonSphereRadius);
    float photonGlow = exp(-photonDist * 8.0) * 0.3;
    color += vec3(0.3, 0.5, 1.0) * photonGlow;

    // === 7. VIGNETTE ===
    float vignette = smoothstep(2.0, 0.5, r);
    vignette = mix(1.0, vignette, uVignetteStrength);
    color *= vignette;

    // === 8. FINAL COLOR OUTPUT ===
    gl_FragColor = vec4(color, 1.0);
}
