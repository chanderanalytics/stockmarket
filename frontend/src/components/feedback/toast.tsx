"use client";

import * as React from "react";
import { cn } from "@/lib/utils";
import { X } from "lucide-react";

type ToastTone = "default" | "success" | "error" | "warning";
interface Toast {
  id: string;
  title?: string;
  description?: string;
  tone: ToastTone;
}

interface ToastCtx {
  toasts: Toast[];
  toast: (t: { title?: string; description?: string; tone?: ToastTone }) => void;
  dismiss: (id: string) => void;
}

const Ctx = React.createContext<ToastCtx | null>(null);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = React.useState<Toast[]>([]);

  const dismiss = React.useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const toast = React.useCallback((t: { title?: string; description?: string; tone?: ToastTone }) => {
    const id = Math.random().toString(36).slice(2);
    setToasts((prev) => [...prev, { id, tone: t.tone ?? "default", title: t.title, description: t.description }]);
    setTimeout(() => dismiss(id), 4000);
  }, [dismiss]);

  return <Ctx.Provider value={{ toasts, toast, dismiss }}>{children}</Ctx.Provider>;
}

export function useToast(): ToastCtx {
  const ctx = React.useContext(Ctx);
  if (!ctx) throw new Error("useToast must be used within ToastProvider");
  return ctx;
}

const toneStyles: Record<ToastTone, string> = {
  default: "border-border",
  success: "border-success/40",
  error: "border-destructive/40",
  warning: "border-warning/40",
};

export function Toaster() {
  const { toasts, dismiss } = useToast();
  return (
    <div className="pointer-events-none fixed bottom-4 right-4 z-[100] flex w-80 flex-col gap-2">
      {toasts.map((t) => (
        <div
          key={t.id}
          className={cn("pointer-events-auto flex items-start gap-3 rounded-lg border bg-card p-3 shadow-lg animate-fade-in", toneStyles[t.tone])}
        >
          <div className="flex-1">
            {t.title && <p className="text-sm font-medium text-foreground">{t.title}</p>}
            {t.description && <p className="text-xs text-muted-foreground">{t.description}</p>}
          </div>
          <button onClick={() => dismiss(t.id)} className="text-muted-foreground hover:text-foreground" aria-label="Dismiss">
            <X className="h-4 w-4" />
          </button>
        </div>
      ))}
    </div>
  );
}
