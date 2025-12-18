"use client";

import dynamic from "next/dynamic";

const BlackHoleScene = dynamic(
  () => import("@/components/blackhole/BlackHoleScene"),
  { ssr: false }
);

export default function BlackHolePage() {
  return (
    <main style={{ width: "100vw", height: "100vh", background: "black" }}>
      <BlackHoleScene />
    </main>
  );
}
