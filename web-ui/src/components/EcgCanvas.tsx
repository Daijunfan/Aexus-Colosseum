import React, { useEffect, useRef } from 'react';

interface EcgCanvasProps {
  healthy: boolean;
  phaseOffset?: number;
  height?: number;
}

function samplePqrst(t: number): number {
  const phase = ((t % 1) + 1) % 1;
  if (phase > 0.12 && phase < 0.22) {
    return Math.sin(((phase - 0.12) / 0.1) * Math.PI) * 0.18;
  }
  if (phase >= 0.28 && phase < 0.32) {
    return -Math.sin(((phase - 0.28) / 0.04) * Math.PI) * 0.2;
  }
  if (phase >= 0.32 && phase < 0.38) {
    return Math.sin(((phase - 0.32) / 0.06) * Math.PI) * 0.92;
  }
  if (phase >= 0.38 && phase < 0.43) {
    return -Math.sin(((phase - 0.38) / 0.05) * Math.PI) * 0.34;
  }
  if (phase >= 0.52 && phase < 0.68) {
    return Math.sin(((phase - 0.52) / 0.16) * Math.PI) * 0.26;
  }
  return 0;
}

export const EcgCanvas: React.FC<EcgCanvasProps> = ({
  healthy,
  phaseOffset = 0,
  height = 18,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const healthyRef = useRef(healthy);
  healthyRef.current = healthy;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let rafId = 0;
    const dpr = window.devicePixelRatio || 1;

    const render = (nowMs: number) => {
      const rectW = canvas.clientWidth || 140;
      const rectH = height;
      if (canvas.width !== Math.floor(rectW * dpr) || canvas.height !== Math.floor(rectH * dpr)) {
        canvas.width = Math.floor(rectW * dpr);
        canvas.height = Math.floor(rectH * dpr);
      }

      const w = canvas.width;
      const h = canvas.height;
      ctx.clearRect(0, 0, w, h);

      const isOk = healthyRef.current;
      const strokeColor = isOk ? '#1C9457' : '#DC2E33';
      const midY = h * 0.64;
      const amp = h * 0.52;
      const sweepSpeed = nowMs * 0.0012 + phaseOffset * 0.23;

      ctx.beginPath();
      for (let px = 0; px < w; px += 2) {
        const normX = px / w;
        const yVal = isOk
          ? samplePqrst(normX * 2.1 - sweepSpeed)
          : Math.sin(nowMs * 0.04 + px * 0.18) * 0.03;
        const py = midY - yVal * amp;
        if (px === 0) ctx.moveTo(px, py);
        else ctx.lineTo(px, py);
      }

      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = 1.6 * dpr;
      ctx.stroke();

      rafId = window.requestAnimationFrame(render);
    };

    rafId = window.requestAnimationFrame(render);
    return () => window.cancelAnimationFrame(rafId);
  }, [height, phaseOffset]);

  return (
    <div className="relative w-full overflow-hidden">
      <canvas ref={canvasRef} style={{ height: `${height}px` }} className="w-full block" />
    </div>
  );
};
