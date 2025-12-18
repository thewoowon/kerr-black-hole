"use client";

import { useEffect } from "react";
import GUI from "lil-gui";
import * as THREE from "three";

interface BlackHoleControlsProps {
  uniforms: {
    [key: string]: { value: any };
  };
}

export default function BlackHoleControls({
  uniforms,
}: BlackHoleControlsProps) {
  useEffect(() => {
    const gui = new GUI();
    gui.title("Black Hole Parameters");

    // Physics folder
    const physicsFolder = gui.addFolder("Physics");
    physicsFolder
      .add(uniforms.uMass, "value", 0.5, 2.0, 0.01)
      .name("Mass (M)");
    physicsFolder
      .add(uniforms.uShadowRadius, "value", 0.5, 2.0, 0.01)
      .name("Shadow Radius");
    physicsFolder
      .add(uniforms.uPhotonSphereRadius, "value", 1.0, 2.5, 0.01)
      .name("Photon Sphere");

    // Accretion disk folder
    const diskFolder = gui.addFolder("Accretion Disk");
    diskFolder
      .add(uniforms.uDiskInner, "value", 2.0, 5.0, 0.1)
      .name("Inner Radius");
    diskFolder
      .add(uniforms.uDiskOuter, "value", 5.0, 12.0, 0.1)
      .name("Outer Radius");
    diskFolder
      .add(uniforms.uDiskRotationSpeed, "value", 0.0, 0.5, 0.01)
      .name("Rotation Speed");

    // Lensing folder
    const lensingFolder = gui.addFolder("Gravitational Lensing");
    lensingFolder
      .add(uniforms.uLensStrength, "value", 0.0, 1.5, 0.01)
      .name("Strength");
    lensingFolder
      .add(uniforms.uLensSharpness, "value", 0.0, 2.0, 0.01)
      .name("Sharpness");

    // Visual effects folder
    const visualFolder = gui.addFolder("Visual Effects");
    visualFolder
      .add(uniforms.uVignetteStrength, "value", 0.0, 1.0, 0.01)
      .name("Vignette");
    visualFolder
      .add(uniforms.uGlowIntensity, "value", 0.0, 3.0, 0.1)
      .name("Glow Intensity");

    // Position GUI (left side)
    gui.domElement.style.position = "absolute";
    gui.domElement.style.top = "20px";
    gui.domElement.style.left = "20px";
    gui.domElement.style.zIndex = "1000";

    return () => gui.destroy();
  }, [uniforms]);

  return null;
}
