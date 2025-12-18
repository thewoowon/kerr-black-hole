// shaders/blackhole/vertex.glsl
// Simple passthrough vertex shader

varying vec2 vUv;
varying vec3 vPosition;

void main() {
    vUv = uv;
    vPosition = position;

    // Use standard camera transformation for zoom/orbit
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
