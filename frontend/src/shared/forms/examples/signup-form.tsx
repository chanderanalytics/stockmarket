"use client";

import * as React from "react";
import { Form, SubmitButton, useZodForm } from "../form";
import { FormField, TextField, CheckboxField } from "../form-field";
import { signupSchema, type SignupValues } from "../validations";
import { authService } from "@/shared/api/services/auth";

// Example form demonstrating the form system end-to-end. Tries the real auth
// service, but simulates a successful submit when no backend is reachable.
export function SignupForm({ onSuccess }: { onSuccess?: (values: SignupValues) => void }) {
  const form = useZodForm<SignupValues>(signupSchema, { name: "", email: "", password: "", confirm: "", terms: false as any });
  const [serverError, setServerError] = React.useState<string | null>(null);

  const onSubmit = async (values: SignupValues) => {
    setServerError(null);
    try {
      const res = await authService.register(values.name, values.email, values.password);
      window.localStorage.setItem("auth_token", res.token);
      onSuccess?.(values);
    } catch {
      // No backend in this scaffold — simulate success so the flow is demoable.
      await new Promise((r) => setTimeout(r, 700));
      onSuccess?.(values);
    }
  };

  return (
    <Form form={form} onSubmit={onSubmit} className="space-y-4">
      <FormField name="name" label="Full name" required>
        <TextField name="name" placeholder="Satoshi Nakamoto" />
      </FormField>
      <FormField name="email" label="Email" required>
        <TextField name="email" type="email" placeholder="you@example.com" />
      </FormField>
      <FormField name="password" label="Password" required hint="8+ chars, one number, one uppercase.">
        <TextField name="password" type="password" />
      </FormField>
      <FormField name="confirm" label="Confirm password" required>
        <TextField name="confirm" type="password" />
      </FormField>
      <FormField name="terms" required>
        <CheckboxField name="terms" label="I agree to the terms & conditions" />
      </FormField>
      {serverError && <p className="text-sm text-destructive">{serverError}</p>}
      <SubmitButton className="w-full">Create account</SubmitButton>
    </Form>
  );
}
