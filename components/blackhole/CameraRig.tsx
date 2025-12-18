"use client";

import { useFrame, useThree } from "@react-three/fiber";
import { useRef } from "react";
import { DEFAULT_CONFIG } from "@/lib/blackhole/config";

interface CameraRigProps {
  orbitSpeed?: number;
  distance?: number;
  verticalAmplitude?: number;
}

export default function CameraRig({
  orbitSpeed = DEFAULT_CONFIG.cameraOrbitSpeed,
  distance = DEFAULT_CONFIG.observerDistance,
  verticalAmplitude = 2.5,
}: CameraRigProps) {
  const { camera } = useThree();
  const tRef = useRef(0);

  useFrame((state, delta) => {
    tRef.current += delta * orbitSpeed;

    const angle = tRef.current;

    // Orbital motion in XZ plane
    const x = distance * Math.cos(angle);
    const z = distance * Math.sin(angle);

    // Gentle vertical oscillation
    const y = verticalAmplitude * Math.sin(angle * 0.4);

    camera.position.set(x, y, z);
    camera.lookAt(0, 0, 0);
  });

  return null;
}
