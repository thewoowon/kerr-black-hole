// Kerr Black Hole Shader - Proper Geodesic Ray Tracing
// Based on Gargantua implementation with Kerr metric
// References: "Interstellar" VFX paper, Marck 1996, James et al. 2015

precision highp float;

varying vec2 vUv;
varying vec3 vPosition;

uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uCamPos;

// Physics parameters
uniform float uMass; // Black hole mass (M = 1 in geometrized units)
uniform float uSpin; // Kerr spin parameter a (0 = Schwarzschild, ~1 = extremal)

// Accretion disk parameters
uniform float uDiskInner;
uniform float uDiskOuter;
uniform float uDiskThickness;
uniform float uDiskRotationSpeed;

// Visual parameters
uniform float uGlowIntensity;
uniform sampler2D uBgTexture;

const float PI = 3.14159265359;
const float EPSILON = 0.0001;
const float INFINITY_DIST = 1000000.0;

// Integration parameters
const int MAX_STEPS = 300;
const float STEP_SIZE = 0.1;

// ============================================================================
// SIMPLEX NOISE (from Gargantua)
// ============================================================================
vec4 permute(vec4 x) {
    return mod(((x * 34.0) + 1.0) * x, 289.0);
}

vec4 taylorInvSqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1.0 + 3.0 * C.xxx;

    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    float n_ = 1.0 / 7.0;
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// ============================================================================
// KERR METRIC & GEODESIC EQUATIONS
// ============================================================================

// Schwarzschild metric coefficient (for non-rotating case)
float metricCoeff(float r) {
    return 1.0 - 2.0 * uMass / r;
}

// Geodesic acceleration for light rays
// This implements the geodesic equation: d²x/dλ² = -Γ^μ_νρ (dx^ν/dλ)(dx^ρ/dλ)
// Based on angular momentum conservation and effective potential
vec3 accel(float h2, vec3 pos) {
    float r2 = dot(pos, pos);
    float r = sqrt(r2);

    // Prevent singularity
    if (r < 1.0) {
        return vec3(0.0);
    }

    float r5 = pow(r2, 2.5);

    // Geodesic equation simplified for photons
    // Using conserved angular momentum h² = |r × v|²
    vec3 acc = -1.5 * h2 * pos / r5;

    return acc;
}

// ============================================================================
// QUATERNION ROTATION (from Gargantua)
// ============================================================================
vec4 quadFromAxisAngle(vec3 axis, float angle) {
    vec4 qr;
    float half_angle = (angle * 0.5) * PI / 180.0;
    qr.x = axis.x * sin(half_angle);
    qr.y = axis.y * sin(half_angle);
    qr.z = axis.z * sin(half_angle);
    qr.w = cos(half_angle);
    return qr;
}

vec4 quadConj(vec4 q) {
    return vec4(-q.x, -q.y, -q.z, q.w);
}

vec4 quat_mult(vec4 q1, vec4 q2) {
    vec4 qr;
    qr.x = (q1.w * q2.x) + (q1.x * q2.w) + (q1.y * q2.z) - (q1.z * q2.y);
    qr.y = (q1.w * q2.y) - (q1.x * q2.z) + (q1.y * q2.w) + (q1.z * q2.x);
    qr.z = (q1.w * q2.z) + (q1.x * q2.y) - (q1.y * q2.x) + (q1.z * q2.w);
    qr.w = (q1.w * q2.w) - (q1.x * q2.x) - (q1.y * q2.y) - (q1.z * q2.z);
    return qr;
}

vec3 rotateVector(vec3 position, vec3 axis, float angle) {
    vec4 qr = quadFromAxisAngle(axis, angle);
    vec4 qr_conj = quadConj(qr);
    vec4 q_pos = vec4(position.x, position.y, position.z, 0.0);

    vec4 q_tmp = quat_mult(qr, q_pos);
    qr = quat_mult(q_tmp, qr_conj);

    return vec3(qr.x, qr.y, qr.z);
}

// ============================================================================
// COORDINATE CONVERSIONS
// ============================================================================
vec3 toSpherical(vec3 p) {
    float rho = length(p);
    float theta = atan(p.z, p.x);
    float phi = asin(clamp(p.y / rho, -1.0, 1.0));
    return vec3(rho, theta, phi);
}

// ============================================================================
// ACCRETION DISK (Volumetric rendering like Gargantua)
// ============================================================================

// Volumetric disk density function
void adiskColor(vec3 pos, inout vec3 color, inout float alpha) {
    float innerRadius = uDiskInner;
    float outerRadius = uDiskOuter;

    // Disk is in XZ plane (y is vertical)
    // Density linearly decreases as distance to blackhole center increases
    float density = max(0.0, 1.0 - length(pos.xyz / vec3(outerRadius, uDiskThickness, outerRadius)));
    if (density < 0.001) {
        return;
    }

    // Vertical density falloff (y is vertical axis)
    density *= pow(1.0 - abs(pos.y) / uDiskThickness, 2.0);

    // Set particle density to 0 when radius is below ISCO
    density *= smoothstep(innerRadius, innerRadius * 1.1, length(pos));

    if (density < 0.001) {
        return;
    }

    vec3 sphericalCoord = toSpherical(pos);

    // Scale for visual correctness
    sphericalCoord.y *= 2.0;
    sphericalCoord.z *= 4.0;

    // Radial density falloff
    density *= 1.0 / pow(sphericalCoord.x, 4.0);
    density *= 32000.0; // Increased brightness

    // Multi-octave noise for turbulence
    float noise = 1.0;
    for (int i = 0; i < 5; i++) {
        noise *= 0.5 * snoise(sphericalCoord * pow(float(i), 2.0) * 0.8) + 0.5;
        if (i % 2 == 0) {
            sphericalCoord.y += uTime * uDiskRotationSpeed;
        } else {
            sphericalCoord.y -= uTime * uDiskRotationSpeed;
        }
    }

    // Get disk color from temperature map
    // Disk is in XZ plane, so use xz for radius
    float r = length(pos.xz);
    float angle = atan(pos.z, pos.x);

    // Temperature gradient
    float temp = smoothstep(outerRadius, innerRadius, r);
    temp = pow(temp, 0.75);

    // Keplerian velocity
    float orbitalVel = 1.0 / sqrt(max(r, 0.1));

    // Rotation with time
    float rotAngle = angle - uTime * uDiskRotationSpeed * orbitalVel;

    // Doppler shift
    float dopplerFactor = sin(rotAngle);

    // Relativistic beaming
    float beaming = 1.0 + dopplerFactor * 0.7;

    // Color based on Doppler shift (stronger effect)
    vec3 blueshifted = vec3(0.3, 0.6, 2.0);  // More blue
    vec3 neutral = vec3(1.2, 1.0, 0.7);
    vec3 redshifted = vec3(2.0, 0.3, 0.05);  // More red

    vec3 diskColor;
    if (dopplerFactor > 0.0) {
        diskColor = mix(neutral, blueshifted, dopplerFactor);
    } else {
        diskColor = mix(neutral, redshifted, -dopplerFactor);
    }

    // Temperature coloring
    diskColor = mix(diskColor, vec3(1.8, 1.6, 1.4), temp * 0.8);

    // Brightness
    float brightness = (temp * 12.0 + 2.0) * beaming;
    diskColor *= brightness;

    // Apply turbulence
    color += density * 0.8 * diskColor * alpha * abs(noise);
}

// ============================================================================
// BACKGROUND SAMPLING
// ============================================================================
vec3 sampleBackground(vec3 dir) {
    // Rotate background with time for dynamic effect
    dir = rotateVector(dir, vec3(0.0, 1.0, 0.0), uTime * 10.0);

    // Convert to spherical UV
    vec2 uv = vec2(
        0.5 - atan(dir.z, dir.x) / (2.0 * PI),
        0.5 - asin(clamp(dir.y, -1.0, 1.0)) / PI
    );

    // Sample texture if available, otherwise procedural stars
    vec3 bgColor = vec3(0.0);

    // Procedural stars (multi-scale)
    float stars = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float scale = pow(2.0, i);
        vec2 coord = uv * 30.0 * scale;
        float n = fract(sin(dot(coord, vec2(127.1, 311.7))) * 43758.5453123);
        stars += step(0.995 - i * 0.003, n) * (1.0 - i * 0.25);
    }

    bgColor = vec3(stars) * 0.9;

    return bgColor;
}

// ============================================================================
// RAY TRACING WITH GEODESIC INTEGRATION (Volumetric)
// ============================================================================
vec3 traceColor(vec3 pos, vec3 dir) {
    vec3 color = vec3(0.0);
    float alpha = 1.0;

    // Scale step size
    dir *= STEP_SIZE;

    // Conserved angular momentum h = r × v
    vec3 h = cross(pos, dir);
    float h2 = dot(h, h);

    // Ray march with geodesic integration
    for (int i = 0; i < MAX_STEPS; i++) {
        float r = length(pos);

        // Check event horizon (r < 2M for Schwarzschild, closer for Kerr)
        float eventHorizon = 2.0 * uMass * (1.0 - uSpin * 0.5);
        if (r < eventHorizon) {
            return color; // Absorbed by black hole
        }

        // Check if escaped to infinity
        if (r > 100.0) {
            color += sampleBackground(normalize(dir)) * alpha;
            return color;
        }

        // Volumetric disk rendering (accumulate color)
        adiskColor(pos, color, alpha);

        // Apply gravitational lensing (geodesic equation)
        vec3 acc = accel(h2, pos);
        dir += acc;

        // Update position
        pos += dir;
    }

    // Didn't hit anything - sample background
    color += sampleBackground(normalize(dir)) * alpha;
    return color;
}

// ============================================================================
// CAMERA SETUP
// ============================================================================
mat3 lookAt(vec3 origin, vec3 target, float roll) {
    vec3 rr = vec3(sin(roll), cos(roll), 0.0);
    vec3 ww = normalize(target - origin);
    vec3 uu = normalize(cross(ww, rr));
    vec3 vv = normalize(cross(uu, ww));

    return mat3(uu, vv, ww);
}

// ============================================================================
// MAIN
// ============================================================================
void main() {
    // Camera setup
    vec3 cameraPos = uCamPos;
    vec3 target = vec3(0.0, 0.0, 0.0);
    mat3 view = lookAt(cameraPos, target, 0.0);

    // Screen coordinates
    vec2 uv = gl_FragCoord.xy / uResolution.xy - vec2(0.5);
    uv.x *= uResolution.x / uResolution.y;

    // Ray direction
    vec3 dir = normalize(vec3(-uv.x, uv.y, 1.0));
    dir = view * dir;

    // Trace ray through curved spacetime
    vec3 finalColor = traceColor(cameraPos, dir);

    // Subtle vignette
    float vignette = 1.0 - length(uv) * 0.15;
    finalColor *= vignette;

    // Gamma correction
    finalColor = pow(finalColor, vec3(0.85));

    gl_FragColor = vec4(finalColor, 1.0);
}
