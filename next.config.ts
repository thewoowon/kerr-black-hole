import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Empty turbopack config to silence the warning
  // GLSL files will be handled by default loaders
  turbopack: {},
};

export default nextConfig;
