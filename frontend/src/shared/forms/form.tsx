"use client";

import * as React from "react";
import { useForm, FormProvider, useFormContext, type UseFormReturn } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import type { FieldValues, DefaultValues } from "react-hook-form";
import { Button } from "@/components/ui/button";
import { Spinner } from "@/components/feedback/spinner";

// Creates a react-hook-form instance bound to a zod schema.
export function useZodForm<TFieldValues extends FieldValues>(schema: any, defaultValues?: DefaultValues<TFieldValues>) {
  return useForm<TFieldValues>({
    resolver: zodResolver(schema) as any,
    defaultValues,
    mode: "onTouched",
  });
}

// Provider + <form> wiring. Pass a `form` created with useZodForm.
export function Form({
  form,
  onSubmit,
  className,
  children,
}: {
  form: UseFormReturn<any>;
  onSubmit: (values: any) => void | Promise<void>;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <FormProvider {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className={className} noValidate>
        {children}
      </form>
    </FormProvider>
  );
}

export function SubmitButton({ children = "Submit", className }: { children?: React.ReactNode; className?: string }) {
  let methods: ReturnType<typeof useFormContext> | undefined;
  try {
    methods = useFormContext();
  } catch {
    methods = undefined;
  }
  return (
    <Button type="submit" disabled={methods?.formState.isSubmitting} className={className}>
      {methods?.formState.isSubmitting && <Spinner className="mr-2 h-4 w-4" />}
      {children}
    </Button>
  );
}
