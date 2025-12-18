// shaders/blackhole/sphere_fragment.glsl
// Fragment shader for 3D black hole sphere

precision highp float;

// Varyings from vertex shader
varying vec2 vUv;
varying vec3 vPosition;

// Time and uniforms
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

// ===== UTILITY FUNCTIONS =====

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

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

// ===== MAIN SHADER =====

// Ray-disk intersection helper
float intersectDiskPlane(vec3 rayOrigin, vec3 rayDir) {
    // Disk is in XY plane at z = 0
    float t = -rayOrigin.z / rayDir.z;

    if (t < 0.0) return -1.0;

    vec3 hitPoint = rayOrigin + rayDir * t;
    float r = length(hitPoint.xy);

    // Check if within disk bounds
    if (r >= uDiskInner && r <= uDiskOuter) {
        return t;
    }

    return -1.0;
}

// Get disk color with Doppler beaming
vec3 getDiskColor(vec3 hitPoint) {
    float r = length(hitPoint.xy);
    float angle = atan(hitPoint.y, hitPoint.x);

    // Temperature gradient (hotter = bluer closer to center)
    float temp = smoothstep(uDiskOuter, uDiskInner, r);

    // Orbital velocity (Keplerian: v ∝ 1/√r)
    float orbitalVel = 1.0 / sqrt(r);

    // Rotation angle with time
    float rotAngle = angle - uTime * uDiskRotationSpeed * orbitalVel;

    // Doppler factor: positive = approaching (blueshift), negative = receding (redshift)
    float dopplerFactor = sin(rotAngle);

    // Doppler beaming (relativistic effect - approaching side brighter)
    float beaming = 1.0 + dopplerFactor * 0.4;

    // Color based on Doppler shift
    vec3 blueshifted = vec3(0.4, 0.7, 1.0);  // Blue (approaching)
    vec3 neutral = vec3(1.0, 0.9, 0.6);      // Yellow-white
    vec3 redshifted = vec3(1.0, 0.3, 0.1);   // Red (receding)

    vec3 diskColor;
    if (dopplerFactor > 0.0) {
        diskColor = mix(neutral, blueshifted, dopplerFactor);
    } else {
        diskColor = mix(neutral, redshifted, -dopplerFactor);
    }

    // Temperature contribution
    diskColor = mix(diskColor, vec3(1.0, 1.0, 1.0), temp * 0.5);

    // Brightness with temperature and beaming
    float brightness = (temp * 2.5 + 0.8) * beaming;
    diskColor *= brightness;

    // Turbulence
    float turbulence = noise(vec2(r * 10.0, angle * 5.0 + uTime * 0.5));
    diskColor *= 0.7 + turbulence * 0.6;

    // Radial falloff at edges
    float falloff = smoothstep(uDiskInner - 0.3, uDiskInner + 0.2, r) *
                    (1.0 - smoothstep(uDiskOuter - 0.5, uDiskOuter + 0.3, r));
    diskColor *= falloff;

    return diskColor;
}

void main() {
    // Calculate ray direction from camera through this sphere surface point
    vec3 spherePos = vPosition;  // World space position on sphere surface
    vec3 rayOrigin = uCamPos;
    vec3 rayDir = normalize(spherePos - rayOrigin);

    // Use sphere surface position for polar coordinates
    vec3 pos = normalize(spherePos);
    float theta = atan(pos.y, pos.x);
    float phi = acos(pos.z);

    // Distance from camera to sphere surface
    float distToSurface = length(spherePos - rayOrigin);

    // === BLACK HOLE SHADOW ===
    // Center area should be pure black (event horizon)
    float distFromCenter = length(spherePos);
    if (distFromCenter < uShadowRadius) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // === ACCRETION DISK ===
    vec3 diskColor = vec3(0.0);

    // Cast ray from camera through sphere surface to find disk intersection
    float diskT = intersectDiskPlane(rayOrigin, rayDir);

    if (diskT > 0.0 && diskT < distToSurface) {
        // Ray hits disk before reaching sphere surface
        vec3 diskHitPoint = rayOrigin + rayDir * diskT;
        diskColor = getDiskColor(diskHitPoint);
    }

    // === BACKGROUND STARS ===
    vec2 bgUV = vec2(
        (theta + PI) / (2.0 * PI),
        phi / PI
    );

    vec3 bgColor = vec3(0.0);

    // Procedural stars
    float stars = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float scale = pow(2.0, i);
        vec2 coord = bgUV * 20.0 * scale;
        float n = noise(coord);
        stars += step(0.99 - i * 0.005, n) * (1.0 - i * 0.3);
    }
    bgColor = vec3(stars) * 0.8;

    // === PHOTON SPHERE GLOW ===
    float photonDist = abs(distFromCenter - uPhotonSphereRadius);
    float photonGlow = exp(-photonDist * 4.0) * 0.6 * uGlowIntensity;
    vec3 glowColor = vec3(0.3, 0.5, 1.0) * photonGlow;

    // === COMBINE ===
    vec3 color = bgColor + diskColor + glowColor;

    // Vignette based on viewing angle
    float vignette = smoothstep(2.0, 0.3, length(pos.xy));
    vignette = mix(1.0, vignette, uVignetteStrength * 0.5);
    color *= vignette;

    gl_FragColor = vec4(color, 1.0);
}
