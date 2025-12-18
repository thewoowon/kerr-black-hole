// lib/blackhole/textures.ts
// Utilities for generating procedural textures

import * as THREE from "three";

/**
 * Generate a procedural starfield texture
 */
export function generateStarfieldTexture(
  width: number = 2048,
  height: number = 1024
): THREE.Texture {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;

  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Could not get 2D context");
  }

  // Background - deep space
  const gradient = ctx.createRadialGradient(
    width / 2,
    height / 2,
    0,
    width / 2,
    height / 2,
    width / 2
  );
  gradient.addColorStop(0, "#0a0a1a");
  gradient.addColorStop(0.5, "#050510");
  gradient.addColorStop(1, "#000000");

  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  // Add stars
  const starCount = 8000;

  for (let i = 0; i < starCount; i++) {
    const x = Math.random() * width;
    const y = Math.random() * height;

    // Star size and brightness
    const size = Math.random() * Math.random() * 2; // Power distribution for more small stars
    const brightness = Math.random();

    // Star color variation
    let color: string;
    const temp = Math.random();

    if (temp > 0.9) {
      // Blue stars (hot)
      color = `rgba(150, 180, 255, ${brightness})`;
    } else if (temp > 0.7) {
      // White stars
      color = `rgba(255, 255, 255, ${brightness})`;
    } else if (temp > 0.3) {
      // Yellow-white stars
      color = `rgba(255, 250, 220, ${brightness})`;
    } else {
      // Orange-red stars (cool)
      color = `rgba(255, 200, 150, ${brightness})`;
    }

    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(x, y, size, 0, Math.PI * 2);
    ctx.fill();

    // Add glow for brighter stars
    if (brightness > 0.7 && size > 1) {
      const glowGradient = ctx.createRadialGradient(x, y, 0, x, y, size * 3);
      glowGradient.addColorStop(0, `rgba(255, 255, 255, ${brightness * 0.3})`);
      glowGradient.addColorStop(1, "rgba(255, 255, 255, 0)");

      ctx.fillStyle = glowGradient;
      ctx.beginPath();
      ctx.arc(x, y, size * 3, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Add some nebula-like clouds
  for (let i = 0; i < 15; i++) {
    const x = Math.random() * width;
    const y = Math.random() * height;
    const radius = 50 + Math.random() * 150;

    const nebulaGradient = ctx.createRadialGradient(x, y, 0, x, y, radius);

    const hue = Math.random() * 360;
    nebulaGradient.addColorStop(
      0,
      `hsla(${hue}, 70%, 50%, ${0.05 + Math.random() * 0.1})`
    );
    nebulaGradient.addColorStop(0.5, `hsla(${hue}, 60%, 40%, 0.02)`);
    nebulaGradient.addColorStop(1, "rgba(0, 0, 0, 0)");

    ctx.fillStyle = nebulaGradient;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;

  return texture;
}

/**
 * Generate a simple gradient background
 */
export function generateGradientBackground(
  width: number = 1024,
  height: number = 512
): THREE.Texture {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;

  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Could not get 2D context");
  }

  const gradient = ctx.createLinearGradient(0, 0, 0, height);
  gradient.addColorStop(0, "#000428"); // Deep blue-black
  gradient.addColorStop(0.5, "#001a33"); // Dark blue
  gradient.addColorStop(1, "#000000"); // Black

  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;

  return texture;
}
