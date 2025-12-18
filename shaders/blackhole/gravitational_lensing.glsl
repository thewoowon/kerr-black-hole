// shaders/blackhole/gravitational_lensing.glsl
// Kerr-inspired black hole shader with asymmetric lensing (Gargantua style)

precision highp float;

varying vec2 vUv;
varying vec3 vPosition;

uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uCamPos;

// Physics parameters
uniform float uMass;
uniform float uSpin;
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
uniform sampler2D uBgTexture;

const float PI = 3.14159265359;
const int MAX_STEPS = 320;
const float STEP_SIZE = 0.08;

// ---- Math helpers --------------------------------------------------------
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

float schwarzschildRadius() {
    return 2.0 * uMass;
}

float kerrEventHorizon() {
    float a = clamp(uSpin, 0.0, 0.999);
    float m = max(uMass, 0.0001);
    return m + sqrt(max(m * m - (a * m) * (a * m), 0.0));
}

float kerrPhotonSphere() {
    // Prograde photon sphere approximation (valid for our visual range)
    float a = clamp(uSpin, 0.0, 0.999);
    float m = max(uMass, 0.0001);
    float cosTerm = cos((2.0 / 3.0) * acos(-a));
    return 2.0 * m * (1.0 + cosTerm);
}

float metricCoeff(float r) {
    return 1.0 - schwarzschildRadius() / r;
}

// ---- Geodesic integration -----------------------------------------------
vec3 geodesicAcceleration(vec3 pos, vec3 vel) {
    float r = length(pos);
    if (r < kerrEventHorizon() * 1.01) return vec3(0.0);

    vec3 rhat = pos / r;
    float vr = dot(vel, rhat);

    // Baseline Schwarzschild bending scaled by user lens controls
    float lensBoost = mix(0.65, 1.6, clamp(uLensStrength, 0.0, 1.0));
    float factor = (schwarzschildRadius() * lensBoost) / (r * r * metricCoeff(r) + 0.001);

    vec3 accel_radial = -factor * (dot(vel, vel) - vr * vr) * rhat;
    vec3 accel_tangential = -factor * 2.0 * vr * (vel - vr * rhat);

    // Frame dragging (Lense-Thirring) approximation around spin axis (Y)
    float a = clamp(uSpin, 0.0, 0.999);
    vec3 spinAxis = vec3(0.0, 1.0, 0.0);
    float omega = (a * uMass) / pow(max(r, 0.2), 3.0);
    vec3 frameDrag = omega * cross(vel, spinAxis) * (0.5 + uLensSharpness * 0.35);

    return accel_radial + accel_tangential + frameDrag;
}

void rk4Step(inout vec3 pos, inout vec3 vel, float dt) {
    vec3 k1_v = geodesicAcceleration(pos, vel);
    vec3 k1_p = vel;

    vec3 k2_v = geodesicAcceleration(pos + 0.5 * dt * k1_p, vel + 0.5 * dt * k1_v);
    vec3 k2_p = vel + 0.5 * dt * k1_v;

    vec3 k3_v = geodesicAcceleration(pos + 0.5 * dt * k2_p, vel + 0.5 * dt * k2_v);
    vec3 k3_p = vel + 0.5 * dt * k2_v;

    vec3 k4_v = geodesicAcceleration(pos + dt * k3_p, vel + dt * k3_v);
    vec3 k4_p = vel + dt * k3_v;

    pos += (dt / 6.0) * (k1_p + 2.0 * k2_p + 2.0 * k3_p + k4_p);
    vel += (dt / 6.0) * (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v);
    vel = normalize(vel);
}

// ---- Scene helpers -------------------------------------------------------
bool intersectDisk(vec3 pos, out vec3 hitPoint) {
    if (abs(pos.z) < uDiskThickness * 1.6 + 0.03) {
        float r = length(pos.xy);
        if (r >= uDiskInner && r <= uDiskOuter) {
            hitPoint = pos;
            return true;
        }
    }
    return false;
}

vec3 getDiskColor(vec3 hitPoint) {
    float r = length(hitPoint.xy);
    float angle = atan(hitPoint.y, hitPoint.x);

    float temp = smoothstep(uDiskOuter, uDiskInner, r);
    temp = pow(temp, 0.75);

    float orbitalVel = 1.0 / sqrt(max(r, 0.1));
    float rotAngle = angle - uTime * uDiskRotationSpeed * orbitalVel;

    float dopplerFactor = sin(rotAngle) * (1.0 + uSpin * 0.35);
    float beaming = 1.0 + dopplerFactor * (0.7 + uSpin * 0.25);

    vec3 blueshifted = vec3(0.3, 0.6, 1.3);
    vec3 neutral = vec3(1.0, 0.9, 0.6);
    vec3 redshifted = vec3(1.3, 0.3, 0.05);

    vec3 diskColor = dopplerFactor > 0.0
        ? mix(neutral, blueshifted, dopplerFactor * 0.9)
        : mix(neutral, redshifted, -dopplerFactor * 0.9);

    diskColor = mix(diskColor, vec3(1.5, 1.4, 1.2), temp * 0.8);

    float brightness = (temp * 5.0 + 0.5) * beaming;
    diskColor *= brightness;
    diskColor = max(diskColor, vec3(0.01)); // Keep disk visible even when redshifted

    float turb = noise(vec2(r * 8.0, angle * 5.0 + uTime * 0.5));
    diskColor *= 0.6 + turb * 0.8;

    float innerEdge = smoothstep(uDiskInner - 0.2, uDiskInner + 0.3, r);
    float outerEdge = 1.0 - smoothstep(uDiskOuter - 0.5, uDiskOuter + 0.1, r);
    diskColor *= innerEdge * outerEdge;

    float glow = exp(-(r - uDiskInner) * 2.0) * uGlowIntensity;
    diskColor += vec3(1.2, 0.9, 0.5) * glow;

    return diskColor;
}

vec3 sampleBackground(vec3 dir) {
    vec2 uv = vec2(
        atan(dir.z, dir.x) / (2.0 * PI) + 0.5,
        asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5
    );
    return texture2D(uBgTexture, uv).rgb;
}

vec3 proceduralStars(vec3 dir) {
    vec2 uv = vec2(
        atan(dir.z, dir.x) / (2.0 * PI) + 0.5,
        asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5
    );

    float stars = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float scale = pow(2.0, i);
        vec2 coord = uv * 30.0 * scale;
        float n = noise(coord);
        stars += step(0.995 - i * 0.003, n) * (1.0 - i * 0.25);
    }

    return vec3(stars) * 0.9;
}

vec3 sampleSky(vec3 dir) {
    vec3 tex = sampleBackground(dir);
    vec3 stars = proceduralStars(dir);
    return max(tex, stars);
}

// ---- Main ---------------------------------------------------------------
void main() {
    vec2 uv = (vUv * 2.0 - 1.0) * vec2(uResolution.x / uResolution.y, 1.0);

    // Slight asymmetry in view frustum to emphasize Kerr distortion
    vec3 rayOrigin = uCamPos;
    vec3 rayDir = normalize(vec3(uv * (1.0 + uSpin * 0.04), -1.4));

    vec3 pos = rayOrigin;
    vec3 vel = rayDir;

    vec3 finalColor = vec3(0.0);
    bool hitSomething = false;

    float shadowScale = max(0.75, uShadowRadius);
    float horizon = kerrEventHorizon() * shadowScale;

    for (int i = 0; i < MAX_STEPS; i++) {
        float r = length(pos);

        if (r < horizon * 1.02) {
            finalColor = vec3(0.0);
            hitSomething = true;
            break;
        }

        if (r > 120.0) {
            finalColor = sampleSky(normalize(vel));
            hitSomething = true;
            break;
        }

        vec3 hitPoint;
        if (intersectDisk(pos, hitPoint)) {
            float gravDim = clamp(metricCoeff(max(length(hitPoint), horizon + 0.05)), 0.2, 1.0);
            finalColor = getDiskColor(hitPoint) * gravDim;
            hitSomething = true;
            break;
        }

        rk4Step(pos, vel, STEP_SIZE);
    }

    if (!hitSomething) {
        finalColor = sampleSky(normalize(vel));
    }

    // Lens-warped fallback for disk visibility (prevents disappearing ring on-axis)
    float approxR = length(uv * 3.0);
    if (approxR > uDiskInner * 0.6 && approxR < uDiskOuter * 0.4) {
        vec3 approxDisk = getDiskColor(vec3(uv * 4.0, 0.0));
        finalColor = mix(finalColor, approxDisk, 0.35);
    }

    float photonSphere = max(kerrPhotonSphere(), uPhotonSphereRadius);
    float distToPhotonSphere = abs(length(uCamPos) - photonSphere);
    float photonGlow = exp(-distToPhotonSphere * (3.0 + uLensSharpness * 1.5)) * 0.45 * uGlowIntensity;
    finalColor += vec3(0.3, 0.5, 1.0) * photonGlow;

    float vignette = 1.0 - length(uv) * mix(0.05, 0.2, uVignetteStrength);
    finalColor *= vignette;

    finalColor = pow(finalColor, vec3(0.85)); // Gamma-ish correction
    gl_FragColor = vec4(finalColor, 1.0);
}
