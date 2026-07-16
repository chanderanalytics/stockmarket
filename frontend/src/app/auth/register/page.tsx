"use client";

import * as React from "react";
import Link from "next/link";
import { Card } from "@/components/ui/card";
import { SignupForm } from "@/shared/forms";
import { useToast } from "@/components/feedback";

export default function RegisterPage() {
  const { toast } = useToast();
  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-sm space-y-6 p-6">
        <div className="text-center">
          <h1 className="text-xl font-semibold">Create account</h1>
          <p className="text-sm text-muted-foreground">Start tracking the markets.</p>
        </div>
        <SignupForm onSuccess={(v) => toast({ title: "Account created", description: `Welcome, ${v.name}!` })} />
        <p className="text-center text-sm text-muted-foreground">
          Already have an account?{" "}
          <Link href="/auth/login" className="text-primary hover:underline">
            Sign in
          </Link>
        </p>
      </Card>
    </div>
  );
}
