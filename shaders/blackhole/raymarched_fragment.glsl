// shaders/blackhole/raymarched_fragment.glsl
// Proper raymarched black hole with gravitational lensing

precision highp float;

varying vec2 vUv;
varying vec3 vPosition;

uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uCamPos;

// Physics
uniform float uMass;
uniform float uShadowRadius;
uniform float uPhotonSphereRadius;

// Accretion disk
uniform float uDiskInner;
uniform float uDiskOuter;
uniform float uDiskThickness;
uniform float uDiskRotationSpeed;

// Lensing
uniform float uLensStrength;
uniform float uLensSharpness;

// Visual
uniform float uVignetteStrength;
uniform float uGlowIntensity;

uniform sampler2D uBgTexture;

const float PI = 3.14159265359;
const float SCHWARZSCHILD_RADIUS = 2.0;
const float PHOTON_SPHERE = 3.0;

// Hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1,0)), f.x),
        mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x),
        f.y
    );
}

// Procedural starfield
vec3 starfield(vec3 dir) {
    vec2 uv = vec2(
        atan(dir.z, dir.x) / (2.0 * PI) + 0.5,
        asin(dir.y) / PI + 0.5
    );

    float stars = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float scale = pow(2.0, i);
        vec2 coord = uv * 50.0 * scale;
        float n = noise(coord);
        float threshold = 0.995 - i * 0.002;
        stars += step(threshold, n) * (1.0 - i * 0.25);
    }

    return vec3(stars);
}

// Ray-disk intersection
float intersectDisk(vec3 ro, vec3 rd) {
    // Disk is in XY plane at z = 0
    float t = -ro.z / rd.z;

    if (t < 0.0) return -1.0;

    vec3 p = ro + rd * t;
    float r = length(p.xy);

    // Check if within disk bounds
    if (r >= uDiskInner && r <= uDiskOuter) {
        return t;
    }

    return -1.0;
}

// Accretion disk color with Doppler shift
vec3 getDiskColor(vec3 p) {
    float r = length(p.xy);
    float angle = atan(p.y, p.x);

    // Temperature gradient (hotter = bluer closer to center)
    float temp = smoothstep(uDiskOuter, uDiskInner, r);

    // Orbital velocity (Keplerian: v ∝ 1/√r)
    float orbitalVel = 1.0 / sqrt(r);

    // Doppler shift
    // Approaching side (moving toward camera) = blueshifted
    // Receding side (moving away) = redshifted
    float rotAngle = angle - uTime * uDiskRotationSpeed * orbitalVel;
    float dopplerFactor = sin(rotAngle);

    // Doppler beaming (relativistic effect)
    // Approaching side appears brighter
    float beaming = 1.0 + dopplerFactor * 0.3;

    // Color based on Doppler shift
    vec3 blueshifted = vec3(0.5, 0.7, 1.0);  // Blue (approaching)
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

    // Brightness falloff with distance
    float brightness = temp * 2.0 + 0.5;
    diskColor *= brightness * beaming;

    // Turbulence
    float turbulence = noise(vec2(r * 10.0, angle * 5.0 + uTime));
    diskColor *= 0.7 + turbulence * 0.6;

    // Radial falloff
    float falloff = smoothstep(uDiskInner - 0.2, uDiskInner, r) *
                    (1.0 - smoothstep(uDiskOuter, uDiskOuter + 0.5, r));
    diskColor *= falloff;

    return diskColor;
}

// Simplified gravitational lensing
vec3 applyLensing(vec3 rayDir, vec3 bhPos) {
    // Impact parameter
    vec3 perpDir = cross(rayDir, vec3(0, 0, 1));
    float b = length(perpDir);

    // Deflection angle (simplified)
    float deflection = (4.0 * uMass) / max(b, 0.1);
    deflection *= uLensStrength;

    // Rotate ray direction
    float angle = deflection * 0.1;
    mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    rayDir.xy = rot * rayDir.xy;

    return normalize(rayDir);
}

void main() {
    // Get ray direction from camera
    vec2 uv = vUv * 2.0 - 1.0;
    uv.x *= uResolution.x / uResolution.y;

    // Camera setup
    vec3 ro = uCamPos;  // Ray origin
    vec3 rd = normalize(vec3(uv, -1.0));  // Ray direction

    // Black hole at origin
    vec3 bhPos = vec3(0.0);
    float distToBH = length(ro - bhPos);

    // === GRAVITATIONAL LENSING ===
    rd = applyLensing(rd, bhPos);

    // === CHECK FOR EVENT HORIZON ===
    // Ray-sphere intersection with event horizon
    vec3 oc = ro - bhPos;
    float a = dot(rd, rd);
    float b = 2.0 * dot(oc, rd);
    float c = dot(oc, oc) - SCHWARZSCHILD_RADIUS * SCHWARZSCHILD_RADIUS;
    float discriminant = b * b - 4.0 * a * c;

    if (discriminant >= 0.0) {
        // Hit event horizon - pure black
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // === ACCRETION DISK INTERSECTION ===
    float diskT = intersectDisk(ro, rd);
    vec3 diskColor = vec3(0.0);

    if (diskT > 0.0) {
        vec3 diskPoint = ro + rd * diskT;
        diskColor = getDiskColor(diskPoint);
    }

    // === BACKGROUND STARS ===
    vec3 bgColor = starfield(rd);

    // === PHOTON SPHERE GLOW ===
    float photonDist = abs(distToBH - PHOTON_SPHERE);
    float photonGlow = exp(-photonDist * 2.0) * 0.4 * uGlowIntensity;
    vec3 glowColor = vec3(0.3, 0.5, 1.0) * photonGlow;

    // === COMBINE ===
    vec3 finalColor = bgColor + diskColor + glowColor;

    // Vignette
    float dist = length(uv);
    float vignette = smoothstep(1.5, 0.3, dist);
    vignette = mix(1.0, vignette, uVignetteStrength);
    finalColor *= vignette;

    gl_FragColor = vec4(finalColor, 1.0);
}
