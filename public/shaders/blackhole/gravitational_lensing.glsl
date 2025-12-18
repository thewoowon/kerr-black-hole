// shaders/blackhole/gravitational_lensing.glsl
// Schwarzschild black hole with proper gravitational lensing
// Based on geodesic integration approach

precision highp float;

varying vec2 vUv;
varying vec3 vPosition;

uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uCamPos;

// Physics parameters
uniform float uMass;
uniform float uSpin;

// Accretion disk parameters
uniform float uDiskInner;
uniform float uDiskOuter;
uniform float uDiskThickness;
uniform float uDiskRotationSpeed;

// Visual parameters
uniform float uGlowIntensity;
uniform sampler2D uBgTexture;

const float PI = 3.14159265359;
const float SCHWARZSCHILD_RADIUS = 2.0; // r_s = 2M (M = 1)
const float PHOTON_SPHERE = 3.0; // r_ph = 3M

// Maximum integration steps for ray tracing
const int MAX_STEPS = 256;
const float STEP_SIZE = 0.1;
const float MIN_DISTANCE = 0.01;

// Hash for noise
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

// Schwarzschild metric coefficient
float metricCoeff(float r) {
    return 1.0 - SCHWARZSCHILD_RADIUS / r;
}

// Geodesic acceleration for light ray
// This is the key: d²x/dλ² = -Γ^μ_νρ (dx^ν/dλ)(dx^ρ/dλ)
vec3 geodesicAcceleration(vec3 pos, vec3 vel) {
    float r = length(pos);

    // Prevent division by zero near singularity
    if (r < SCHWARZSCHILD_RADIUS * 1.01) {
        return vec3(0.0);
    }

    vec3 rhat = pos / r;
    float vr = dot(vel, rhat);

    // Schwarzschild geodesic equation for photons
    // Simplified form: acceleration has radial and tangential components
    float factor = SCHWARZSCHILD_RADIUS / (r * r * metricCoeff(r));

    // Radial component
    vec3 accel_radial = -factor * (dot(vel, vel) - vr * vr) * rhat;

    // Tangential component (light bending)
    vec3 accel_tangential = -factor * 2.0 * vr * (vel - vr * rhat);

    return accel_radial + accel_tangential;
}

// Runge-Kutta 4th order integration step
void rk4Step(inout vec3 pos, inout vec3 vel, float dt) {
    // k1
    vec3 k1_v = geodesicAcceleration(pos, vel);
    vec3 k1_p = vel;

    // k2
    vec3 k2_v = geodesicAcceleration(pos + 0.5 * dt * k1_p, vel + 0.5 * dt * k1_v);
    vec3 k2_p = vel + 0.5 * dt * k1_v;

    // k3
    vec3 k3_v = geodesicAcceleration(pos + 0.5 * dt * k2_p, vel + 0.5 * dt * k2_v);
    vec3 k3_p = vel + 0.5 * dt * k2_v;

    // k4
    vec3 k4_v = geodesicAcceleration(pos + dt * k3_p, vel + dt * k3_v);
    vec3 k4_p = vel + dt * k3_v;

    // Update
    pos += (dt / 6.0) * (k1_p + 2.0 * k2_p + 2.0 * k3_p + k4_p);
    vel += (dt / 6.0) * (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v);

    // Normalize velocity (photons travel at c)
    vel = normalize(vel);
}

// Check if ray intersects accretion disk
bool intersectDisk(vec3 pos, out vec3 hitPoint) {
    // Disk is in XY plane (z ≈ 0)
    if (abs(pos.z) < uDiskThickness) {
        float r = length(pos.xy);
        if (r >= uDiskInner && r <= uDiskOuter) {
            hitPoint = pos;
            return true;
        }
    }
    return false;
}

// Get disk color at hit point
vec3 getDiskColor(vec3 hitPoint) {
    float r = length(hitPoint.xy);
    float angle = atan(hitPoint.y, hitPoint.x);

    // Temperature gradient
    float temp = smoothstep(uDiskOuter, uDiskInner, r);
    temp = pow(temp, 0.75);

    // Keplerian orbital velocity
    float orbitalVel = 1.0 / sqrt(max(r, 0.1));

    // Rotation
    float rotAngle = angle - uTime * uDiskRotationSpeed * orbitalVel;

    // Doppler shift
    float dopplerFactor = sin(rotAngle);

    // Relativistic beaming
    float beaming = 1.0 + dopplerFactor * 0.7;

    // Colors
    vec3 blueshifted = vec3(0.3, 0.6, 1.3);
    vec3 neutral = vec3(1.0, 0.9, 0.6);
    vec3 redshifted = vec3(1.3, 0.3, 0.05);

    vec3 diskColor;
    if (dopplerFactor > 0.0) {
        diskColor = mix(neutral, blueshifted, dopplerFactor * 0.9);
    } else {
        diskColor = mix(neutral, redshifted, -dopplerFactor * 0.9);
    }

    // Temperature
    diskColor = mix(diskColor, vec3(1.5, 1.4, 1.2), temp * 0.8);

    // Brightness
    float brightness = (temp * 5.0 + 0.5) * beaming;
    diskColor *= brightness;

    // Turbulence
    float turb = noise(vec2(r * 8.0, angle * 5.0 + uTime * 0.5));
    diskColor *= 0.6 + turb * 0.8;

    // Edge falloff
    float innerEdge = smoothstep(uDiskInner - 0.2, uDiskInner + 0.3, r);
    float outerEdge = 1.0 - smoothstep(uDiskOuter - 0.5, uDiskOuter + 0.1, r);
    diskColor *= innerEdge * outerEdge;

    // Inner glow
    float glow = exp(-(r - uDiskInner) * 2.0) * uGlowIntensity;
    diskColor += vec3(1.2, 0.9, 0.5) * glow;

    return diskColor;
}

// Sample background stars
vec3 sampleBackground(vec3 dir) {
    // Convert direction to spherical UV
    vec2 uv = vec2(
        atan(dir.z, dir.x) / (2.0 * PI) + 0.5,
        asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5
    );

    // Procedural stars
    float stars = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float scale = pow(2.0, i);
        vec2 coord = uv * 30.0 * scale;
        float n = noise(coord);
        stars += step(0.995 - i * 0.003, n) * (1.0 - i * 0.25);
    }

    return vec3(stars) * 0.9;
}

void main() {
    // Screen coordinates
    vec2 uv = (vUv * 2.0 - 1.0) * vec2(uResolution.x / uResolution.y, 1.0);

    // Camera setup
    vec3 rayOrigin = uCamPos;
    vec3 rayDir = normalize(vec3(uv, -1.5));

    // Initialize ray position and velocity
    vec3 pos = rayOrigin;
    vec3 vel = rayDir;

    vec3 finalColor = vec3(0.0);
    bool hitSomething = false;

    // Ray marching with geodesic integration
    for (int i = 0; i < MAX_STEPS; i++) {
        float r = length(pos);

        // Check if we hit the event horizon
        if (r < SCHWARZSCHILD_RADIUS * 1.05) {
            finalColor = vec3(0.0); // Pure black
            hitSomething = true;
            break;
        }

        // Check if we escaped to infinity
        if (r > 100.0) {
            // Sample background
            finalColor = sampleBackground(normalize(vel));
            hitSomething = true;
            break;
        }

        // Check disk intersection
        vec3 hitPoint;
        if (intersectDisk(pos, hitPoint)) {
            finalColor = getDiskColor(hitPoint);
            hitSomething = true;
            break;
        }

        // Integrate geodesic
        rk4Step(pos, vel, STEP_SIZE);
    }

    // If we didn't hit anything after max steps, sample background
    if (!hitSomething) {
        finalColor = sampleBackground(normalize(vel));
    }

    // Photon sphere glow
    float camR = length(uCamPos);
    float distToPhotonSphere = abs(camR - PHOTON_SPHERE);
    float photonGlow = exp(-distToPhotonSphere * 3.0) * 0.4 * uGlowIntensity;
    finalColor += vec3(0.3, 0.5, 1.0) * photonGlow;

    // Subtle vignette
    float vignette = 1.0 - length(uv) * 0.15;
    finalColor *= vignette;

    // Gamma correction
    finalColor = pow(finalColor, vec3(0.85));

    gl_FragColor = vec4(finalColor, 1.0);
}
