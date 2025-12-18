"use client";

import { Canvas } from "@react-three/fiber";
import { Suspense } from "react";
import { OrbitControls } from "@react-three/drei";
import BlackHoleShaderPlane from "./BlackHoleShaderPlane";
import CameraRig from "./CameraRig";

interface BlackHoleSceneProps {
  enableOrbitControls?: boolean;
  enableCameraRig?: boolean;
}

export default function BlackHoleScene({
  enableOrbitControls = true,
  enableCameraRig = false,
}: BlackHoleSceneProps) {
  return (
    <Canvas
      camera={{
        position: [0, 0, 8],
        fov: 50,
      }}
      gl={{ antialias: true }}
      dpr={typeof window !== "undefined" ? Math.min(window.devicePixelRatio, 2) : 1}
    >
      <color attach="background" args={["#000000"]} />

      <Suspense fallback={null}>
        {/* Camera animation */}
        {enableCameraRig && <CameraRig />}

        {/* Black hole with gravitational lensing - fullscreen shader */}
        <BlackHoleShaderPlane />

        {/* Manual camera controls - enabled by default */}
        {enableOrbitControls && (
          <OrbitControls
            enablePan={false}
            enableZoom={true}
            minDistance={3}
            maxDistance={50}
            enableDamping
            dampingFactor={0.05}
          />
        )}
      </Suspense>
    </Canvas>
  );
}
