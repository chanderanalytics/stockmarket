"use client";

import * as React from "react";
import { useFormContext, Controller, type ControllerRenderProps } from "react-hook-form";
import { cn } from "@/lib/utils";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { FormError } from "./form-error";

// Layout wrapper: renders a label, the control (children), and any error.
export function FormField({
  name,
  label,
  hint,
  required,
  className,
  children,
}: {
  name: string;
  label?: React.ReactNode;
  hint?: React.ReactNode;
  required?: boolean;
  className?: string;
  children: React.ReactNode;
}) {
  const {
    formState: { errors },
  } = useFormContext();
  const error = errors[name];
  const errorMsg = error?.message ? String(error.message) : undefined;

  return (
    <div className={cn("space-y-1.5", className)}>
      {label && (
        <Label htmlFor={name}>
          {label}
          {required && <span className="ml-0.5 text-destructive">*</span>}
        </Label>
      )}
      {children}
      {hint && !errorMsg && <p className="text-xs text-muted-foreground">{hint}</p>}
      <FormError message={errorMsg} />
    </div>
  );
}

export function TextField({
  name,
  type = "text",
  placeholder,
  disabled,
}: {
  name: string;
  type?: string;
  placeholder?: string;
  disabled?: boolean;
}) {
  const { register } = useFormContext();
  return <Input id={name} type={type} placeholder={placeholder} disabled={disabled} {...register(name)} />;
}

export function TextareaField({ name, placeholder, rows = 4 }: { name: string; placeholder?: string; rows?: number }) {
  const { register } = useFormContext();
  return <Textarea id={name} placeholder={placeholder} rows={rows} {...register(name)} />;
}

export function CheckboxField({
  name,
  label,
}: {
  name: string;
  label: React.ReactNode;
}) {
  const { control } = useFormContext();
  return (
    <Controller
      control={control}
      name={name}
      render={({ field }: { field: ControllerRenderProps }) => (
        <label className="flex items-center gap-2 text-sm">
          <Checkbox checked={!!field.value} onCheckedChange={(v: boolean | string) => field.onChange(v === true)} />
          <span>{label}</span>
        </label>
      )}
    />
  );
}
