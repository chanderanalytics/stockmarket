"use client";

import * as React from "react";

// Serialize the first <svg> inside `container` and download it as a PNG.
// Used by the export button in ChartFrame.
export function exportChartAsPng(container: HTMLElement | null, filename = "chart.png") {
  if (!container) return;
  const svg = container.querySelector("svg");
  if (!svg) return;

  const clone = svg.cloneNode(true) as SVGSVGElement;
  const bbox = svg.getBoundingClientRect();
  const width = bbox.width || 600;
  const height = bbox.height || 400;
  clone.setAttribute("width", String(width));
  clone.setAttribute("height", String(height));
  clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");

  const xml = new XMLSerializer().serializeToString(clone);
  const svgBlob = new Blob([xml], { type: "image/svg+xml;charset=utf-8" });
  const url = URL.createObjectURL(svgBlob);
  const img = new Image();
  img.onload = () => {
    const canvas = document.createElement("canvas");
    const scale = 2;
    canvas.width = width * scale;
    canvas.height = height * scale;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue("--background") || "#fff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.scale(scale, scale);
    ctx.drawImage(img, 0, 0);
    URL.revokeObjectURL(url);
    canvas.toBlob((blob) => {
      if (!blob) return;
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = filename;
      a.click();
      URL.revokeObjectURL(a.href);
    });
  };
  img.src = url;
}
