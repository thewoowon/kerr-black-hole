"use client";

import { forwardRef, useMemo, useEffect } from "react";
import { Effect } from "postprocessing";
import { Uniform } from "three";

// Custom shader effect for black hole
class BlackHoleEffectImpl extends Effect {
  constructor({ fragmentShader, vertexShader, uniforms }: any) {
    super("BlackHoleEffect", fragmentShader, {
      vertexShader,
      uniforms: new Map(
        Object.entries(uniforms).map(([key, value]) => [
          key,
          new Uniform((value as any).value),
        ])
      ),
    });
  }

  update(renderer: any, inputBuffer: any, deltaTime: number) {
    // Update uniforms if needed
  }
}

export const BlackHoleEffect = forwardRef(
  ({ fragmentShader, vertexShader, uniforms }: any, ref) => {
    const effect = useMemo(
      () =>
        new BlackHoleEffectImpl({
          fragmentShader,
          vertexShader,
          uniforms,
        }),
      [fragmentShader, vertexShader, uniforms]
    );

    return <primitive ref={ref} object={effect} dispose={null} />;
  }
);

BlackHoleEffect.displayName = "BlackHoleEffect";
