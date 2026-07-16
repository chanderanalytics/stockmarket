"use client";

import * as React from "react";
import Link from "next/link";
import { Card } from "@/components/ui/card";
import { Form, SubmitButton, useZodForm } from "@/shared/forms";
import { FormField, TextField } from "@/shared/forms";
import { loginSchema, type LoginValues } from "@/shared/forms";
import { useToast } from "@/components/feedback";

export default function LoginPage() {
  const form = useZodForm<LoginValues>(loginSchema, { email: "", password: "" });
  const { toast } = useToast();

  const onSubmit = async (values: LoginValues) => {
    await new Promise((r) => setTimeout(r, 600));
    toast({ title: "Welcome back", description: values.email });
  };

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-sm space-y-6 p-6">
        <div className="text-center">
          <h1 className="text-xl font-semibold">Sign in</h1>
          <p className="text-sm text-muted-foreground">Access your trading dashboard.</p>
        </div>
        <Form form={form} onSubmit={onSubmit} className="space-y-4">
          <FormField name="email" label="Email" required>
            <TextField name="email" type="email" placeholder="you@example.com" />
          </FormField>
          <FormField name="password" label="Password" required>
            <TextField name="password" type="password" />
          </FormField>
          <SubmitButton className="w-full">Sign in</SubmitButton>
        </Form>
        <p className="text-center text-sm text-muted-foreground">
          No account?{" "}
          <Link href="/auth/register" className="text-primary hover:underline">
            Create one
          </Link>
        </p>
      </Card>
    </div>
  );
}
