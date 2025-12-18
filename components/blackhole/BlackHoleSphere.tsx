"use client";

import { useFrame, useThree } from "@react-three/fiber";
import { useRef, useMemo, useState, useEffect } from "react";
import * as THREE from "three";
import { INTERSTELLAR_CONFIG } from "@/lib/blackhole/config";
import BlackHoleControls from "./BlackHoleControls";

interface BlackHoleSphereProps {
  showControls?: boolean;
}

export default function BlackHoleSphere({
  showControls = true,
}: BlackHoleSphereProps) {
  const meshRef = useRef<THREE.Mesh>(null);
  const { size, camera } = useThree();
  const [shaders, setShaders] = useState<{
    vertex: string;
    fragment: string;
  } | null>(null);

  const startTime = useRef<number>(performance.now());

  // Create shader uniforms
  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uResolution: { value: new THREE.Vector2(1, 1) },
      uCamPos: { value: new THREE.Vector3(0, 0, 5) },

      // Physics parameters
      uMass: { value: INTERSTELLAR_CONFIG.mass },
      uSpin: { value: INTERSTELLAR_CONFIG.spin }, // Kerr spin parameter
      uShadowRadius: { value: INTERSTELLAR_CONFIG.shadowRadius },
      uPhotonSphereRadius: { value: INTERSTELLAR_CONFIG.photonSphereRadius },

      // Accretion disk parameters
      uDiskInner: { value: INTERSTELLAR_CONFIG.diskInnerRadius },
      uDiskOuter: { value: INTERSTELLAR_CONFIG.diskOuterRadius },
      uDiskThickness: { value: INTERSTELLAR_CONFIG.diskThickness },
      uDiskRotationSpeed: { value: INTERSTELLAR_CONFIG.diskRotationSpeed },

      // Lensing parameters
      uLensStrength: { value: INTERSTELLAR_CONFIG.lensStrength },
      uLensSharpness: { value: INTERSTELLAR_CONFIG.lensSharpness },

      // Visual parameters
      uVignetteStrength: { value: INTERSTELLAR_CONFIG.vignetteStrength },
      uGlowIntensity: { value: INTERSTELLAR_CONFIG.glowIntensity },

      // Background texture
      uBgTexture: { value: null as THREE.Texture | null },
    }),
    []
  );

  // Load shaders
  useEffect(() => {
    Promise.all([
      fetch("/shaders/blackhole/vertex.glsl").then((r) => r.text()),
      fetch("/shaders/blackhole/disk_fragment.glsl").then((r) => r.text()),
    ]).then(([vertex, fragment]) => {
      setShaders({ vertex, fragment });
    });
  }, []);

  useFrame(() => {
    const mesh = meshRef.current;
    if (!mesh || !mesh.material) return;

    const now = performance.now();
    const t = (now - startTime.current) / 1000.0;

    const material = mesh.material as THREE.ShaderMaterial;
    material.uniforms.uTime.value = t;
    material.uniforms.uResolution.value.set(size.width, size.height);
    material.uniforms.uCamPos.value.copy(camera.position);
  });

  if (!shaders) return null;

  return (
    <>
      {showControls && <BlackHoleControls uniforms={uniforms} />}

      {/* Event horizon - pure black sphere */}
      <mesh position={[0, 0, 0]}>
        <sphereGeometry args={[uniforms.uShadowRadius.value, 32, 32]} />
        <meshBasicMaterial color="#000000" />
      </mesh>

      {/* Accretion disk - ring in XY plane */}
      <mesh ref={meshRef} rotation={[Math.PI / 2, 0, 0]} position={[0, 0, 0]}>
        <ringGeometry
          args={[
            uniforms.uDiskInner.value,
            uniforms.uDiskOuter.value,
            128,
            1
          ]}
        />
        <shaderMaterial
          fragmentShader={shaders.fragment}
          vertexShader={shaders.vertex}
          uniforms={uniforms}
          transparent
          side={THREE.DoubleSide}
          depthWrite={false}
        />
      </mesh>
    </>
  );
}
