"use client";

import * as React from "react";

export function FormError({ message }: { message?: string }) {
  if (!message) return null;
  return (
    <p className="animate-fade-in text-xs text-destructive">{message}</p>
  );
}
