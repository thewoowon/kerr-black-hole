"use client";

import { useFrame, useThree } from "@react-three/fiber";
import { useRef, useMemo, useState, useEffect } from "react";
import * as THREE from "three";
import { EffectComposer } from "@react-three/postprocessing";
import { Effect } from "postprocessing";
import { INTERSTELLAR_CONFIG } from "@/lib/blackhole/config";
import BlackHoleControls from "./BlackHoleControls";
import { BlackHoleEffect } from "./BlackHoleEffect";

interface BlackHoleShaderPlaneProps {
  showControls?: boolean;
}

export default function BlackHoleShaderPlane({
  showControls = true,
}: BlackHoleShaderPlaneProps) {
  const { camera } = useThree();
  const [fragmentShader, setFragmentShader] = useState<string | null>(null);
  const effectRef = useRef<Effect | null>(null);

  const startTime = useRef<number>(0);

  useEffect(() => {
    startTime.current = performance.now();
  }, []);

  // Create shader uniforms
  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uResolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
      uCamPos: { value: new THREE.Vector3(0, 0, 5) },

      // Physics parameters
      uMass: { value: INTERSTELLAR_CONFIG.mass },
      uSpin: { value: INTERSTELLAR_CONFIG.spin },
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
    }),
    []
  );

  // Load shader
  useEffect(() => {
    fetch("/shaders/blackhole/kerr_postprocess.glsl")
      .then((r) => r.text())
      .then(setFragmentShader);
  }, []);

  useFrame(() => {
    const effect = effectRef.current;
    if (!effect) return;

    const now = performance.now();
    const t = (now - startTime.current) / 1000.0;

    const uTime = effect.uniforms.get("uTime");
    const uResolution = effect.uniforms.get("uResolution");
    const uCamPos = effect.uniforms.get("uCamPos");

    if (uTime) uTime.value = t;
    if (uResolution) uResolution.value.set(window.innerWidth, window.innerHeight);
    if (uCamPos) uCamPos.value.copy(camera.position);
  });

  if (!fragmentShader) return null;

  return (
    <>
      {showControls && <BlackHoleControls uniforms={uniforms} />}
      <EffectComposer>
        <BlackHoleEffect
          ref={effectRef}
          fragmentShader={fragmentShader}
          uniforms={uniforms}
        />
      </EffectComposer>
    </>
  );
}
