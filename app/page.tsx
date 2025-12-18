"use client";

import Link from "next/link";
import styled from "@emotion/styled";
import { keyframes } from "@emotion/react";
import StarfieldCanvas from "@/components/StarfieldCanvas";

const gradientAnimation = keyframes`
  0%, 100% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
`;

const GradientText = styled.span`
  background: linear-gradient(to right, rgb(96, 165, 250), rgb(192, 132, 252), rgb(244, 114, 182));
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-size: 200% 200%;
  animation: ${gradientAnimation} 3s ease infinite;
`;

const GradientOverlay = styled.div`
  background: radial-gradient(
    circle at 50% 50%,
    rgba(59, 130, 246, 0.2),
    rgba(147, 51, 234, 0.1),
    rgba(0, 0, 0, 1)
  );
`;

export default function Home() {
  return (
    <div className="relative min-h-screen w-full overflow-hidden bg-black">
      {/* Animated starfield background */}
      <div className="absolute inset-0 z-0">
        <StarfieldCanvas />
      </div>

      {/* Gradient overlay */}
      <GradientOverlay className="absolute inset-0 z-10" />

      {/* Main content */}
      <main className="relative z-20 flex min-h-screen flex-col items-center justify-center px-6 py-12">
        {/* Hero section */}
        <div className="max-w-4xl text-center space-y-8">
          {/* Title with glow effect */}
          <h1 className="text-7xl md:text-9xl font-bold tracking-tighter">
            <GradientText>BLACK HOLE</GradientText>
          </h1>

          {/* Subtitle */}
          <p className="text-xl md:text-2xl text-gray-300 max-w-2xl mx-auto leading-relaxed">
            Experience the gravitational lensing of a{" "}
            <span className="text-blue-400 font-semibold">Kerr black hole</span>
            <br />
            Real-time ray tracing with physically accurate relativistic effects
          </p>

          {/* Features */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12 text-left">
            <div className="bg-white/5 backdrop-blur-sm border border-white/10 rounded-2xl p-6 hover:bg-white/10 transition-all duration-300 hover:scale-105">
              <div className="text-3xl mb-3">🌀</div>
              <h3 className="text-lg font-semibold text-white mb-2">
                Geodesic Ray Tracing
              </h3>
              <p className="text-sm text-gray-400">
                Accurate photon paths through curved spacetime
              </p>
            </div>

            <div className="bg-white/5 backdrop-blur-sm border border-white/10 rounded-2xl p-6 hover:bg-white/10 transition-all duration-300 hover:scale-105">
              <div className="text-3xl mb-3">⚡</div>
              <h3 className="text-lg font-semibold text-white mb-2">
                Relativistic Effects
              </h3>
              <p className="text-sm text-gray-400">
                Doppler shift, beaming, and gravitational lensing
              </p>
            </div>

            <div className="bg-white/5 backdrop-blur-sm border border-white/10 rounded-2xl p-6 hover:bg-white/10 transition-all duration-300 hover:scale-105">
              <div className="text-3xl mb-3">🔥</div>
              <h3 className="text-lg font-semibold text-white mb-2">
                Accretion Disk
              </h3>
              <p className="text-sm text-gray-400">
                Volumetric rendering with turbulence and temperature gradients
              </p>
            </div>
          </div>

          {/* CTA Button */}
          <div className="flex flex-col sm:flex-row gap-4 justify-center mt-12">
            <Link
              href="/blackhole"
              className="group relative px-8 py-4 bg-gradient-to-r from-blue-600 to-purple-600 rounded-full font-semibold text-white text-lg overflow-hidden transition-all duration-300 hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/50"
            >
              <span className="relative z-10">Explore Black Hole</span>
              <div className="absolute inset-0 bg-gradient-to-r from-purple-600 to-pink-600 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
            </Link>

            <a
              href="https://github.com"
              target="_blank"
              rel="noopener noreferrer"
              className="px-8 py-4 border-2 border-white/20 rounded-full font-semibold text-white text-lg hover:bg-white/10 hover:border-white/40 transition-all duration-300 hover:scale-105"
            >
              View Source Code
            </a>
          </div>

          {/* Tech stack */}
          <div className="mt-16 pt-8 border-t border-white/10">
            <p className="text-sm text-gray-500 mb-4">Built with</p>
            <div className="flex flex-wrap justify-center gap-4 text-sm text-gray-400">
              <span className="px-4 py-2 bg-white/5 rounded-full border border-white/10">
                Next.js 16
              </span>
              <span className="px-4 py-2 bg-white/5 rounded-full border border-white/10">
                React Three Fiber
              </span>
              <span className="px-4 py-2 bg-white/5 rounded-full border border-white/10">
                GLSL Shaders
              </span>
              <span className="px-4 py-2 bg-white/5 rounded-full border border-white/10">
                WebGL 2.0
              </span>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
