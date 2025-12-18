# Black Hole Visualization

A real-time Schwarzschild black hole renderer using Next.js, React Three Fiber, and GLSL shaders. This project implements physics-based gravitational lensing effects in the browser.

![Black Hole](https://img.shields.io/badge/physics-Schwarzschild-black)
![Next.js](https://img.shields.io/badge/Next.js-16-black)
![React Three Fiber](https://img.shields.io/badge/R3F-9.4-blue)

## Features

- **Schwarzschild Physics**: Accurate implementation of black hole metrics
  - Event horizon (r = 2M)
  - Photon sphere (r = 3M)
  - Critical impact parameter (b = 3√3M)

- **Gravitational Lensing**: Real-time shader-based light bending
  - Configurable lens strength and sharpness
  - Approximate deflection angle calculations

- **Accretion Disk**: Dynamic rotating disk visualization
  - Doppler shift effects
  - Gravitational redshift
  - Temperature gradients

- **Cinematic Camera**: Smooth orbital camera movement
  - Configurable orbit speed and distance
  - Vertical oscillation for dynamic views

- **Real-time Controls**: Interactive parameter tuning with lil-gui
  - Physics parameters (mass, shadow radius, photon sphere)
  - Disk parameters (inner/outer radius, rotation speed)
  - Visual effects (vignette, glow intensity)

## Getting Started

### Prerequisites

- Node.js 20+
- npm or yarn

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd blackhole

# Install dependencies
npm install

# Run development server
npm run dev
```

Visit [http://localhost:3000/blackhole](http://localhost:3000/blackhole) to see the visualization.

## Project Structure

```
blackhole/
├── app/
│   └── blackhole/
│       └── page.tsx           # Main demo page
├── components/
│   └── blackhole/
│       ├── BlackHoleScene.tsx      # R3F Canvas setup
│       ├── BlackHoleShaderPlane.tsx # Shader material component
│       ├── CameraRig.tsx           # Camera animation
│       └── BlackHoleControls.tsx   # GUI controls
├── lib/
│   └── blackhole/
│       ├── physics.ts         # Schwarzschild physics utilities
│       ├── config.ts          # Configuration presets
│       └── textures.ts        # Procedural texture generation
├── shaders/
│   └── blackhole/
│       ├── vertex.glsl        # Vertex shader
│       └── fragment.glsl      # Fragment shader (main lensing logic)
└── public/
    └── shaders/               # Shader files (copied for runtime loading)
```

## Physics Implementation

### Schwarzschild Metric

The visualization is based on the Schwarzschild solution to Einstein's field equations:

```
ds² = -(1 - 2M/r)dt² + (1 - 2M/r)⁻¹dr² + r²(dθ² + sin²θ dφ²)
```

### Key Radii

- **Schwarzschild radius**: `r_s = 2M` (event horizon)
- **Photon sphere**: `r_ph = 3M` (unstable photon orbit)
- **ISCO**: `r_isco = 6M` (innermost stable circular orbit)

### Gravitational Lensing

The shader approximates light bending using:

```glsl
float deflectionAngle(float b) {
    return (4.0 * M) / b;  // Weak field approximation
}
```

For strong-field effects near the photon sphere, a custom warp function is applied:

```glsl
float lensWarp(float r) {
    return r + k / pow(r + s, 2.0);
}
```

## Configuration

Three preset configurations are available in `lib/blackhole/config.ts`:

- `DEFAULT_CONFIG`: Balanced view for exploration
- `CINEMATIC_CONFIG`: Optimized for dramatic visuals
- `INTERSTELLAR_CONFIG`: Inspired by the Interstellar movie

You can switch configs in `BlackHoleShaderPlane.tsx` or use the GUI controls to tune parameters in real-time.

## Shader Details

### Fragment Shader Pipeline

1. **Ray Direction**: Calculate ray direction from camera to screen pixel
2. **Shadow Test**: Check if ray hits the event horizon shadow
3. **Gravitational Lensing**: Apply warp function to bend light path
4. **Accretion Disk Sampling**: Calculate disk contribution with Doppler/redshift
5. **Background Sampling**: Sample starfield texture with warped direction
6. **Photon Sphere Glow**: Add subtle glow at photon sphere radius
7. **Post-processing**: Apply vignette and tone mapping

### Performance

- Runs at 60 FPS on modern GPUs
- Procedural starfield generation (2048x1024)
- Optimized shader with early returns
- Full-screen quad rendering (2 triangles)

## Customization

### Adding Custom Backgrounds

Replace the procedural starfield with your own equirectangular HDR/image:

```typescript
// In BlackHoleShaderPlane.tsx
const textureLoader = new THREE.TextureLoader();
const bgTexture = textureLoader.load('/path/to/your/background.jpg');
uniforms.uBgTexture.value = bgTexture;
```

### Adjusting Physics

Modify constants in `lib/blackhole/physics.ts`:

```typescript
export const SCHWARZSCHILD_PHYSICS = {
  EVENT_HORIZON: 2.0,     // r_s = 2M
  PHOTON_SPHERE: 3.0,     // r_ph = 3M
  CRITICAL_IMPACT: 5.196, // 3√3 M
  ISCO: 6.0,              // r_isco = 6M
};
```

## Technical Stack

- **Next.js 16**: App Router with Turbopack
- **React Three Fiber**: React renderer for Three.js
- **Three.js**: WebGL 3D library
- **GLSL**: Fragment/vertex shaders for GPU rendering
- **lil-gui**: Real-time parameter controls
- **TypeScript**: Type-safe development

## References

- Schwarzschild, K. (1916). "On the Gravitational Field of a Mass Point"
- Chandrasekhar, S. (1983). "The Mathematical Theory of Black Holes"
- James, O. et al. (2015). "Gravitational lensing by spinning black holes in astrophysics, and in the movie Interstellar"

## License

MIT

## Author

Built with physics enthusiasm and computational creativity.

---

**Note**: This is a visualization tool using approximate methods for real-time performance. For scientifically accurate ray tracing, consider dedicated GR simulation software.