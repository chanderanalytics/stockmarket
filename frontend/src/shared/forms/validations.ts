import { z } from "zod";

// Reusable zod v4 schemas + localized messages for the form system.
export const validations = {
  email: z.string().min(1, "Email is required").pipe(z.email({ message: "Enter a valid email" })),
  password: z
    .string()
    .min(8, "At least 8 characters")
    .regex(/[A-Z]/, "Add an uppercase letter")
    .regex(/[0-9]/, "Add a number"),
  name: z.string().min(2, "Too short").max(60, "Too long"),
};

export const loginSchema = z.object({
  email: validations.email,
  password: z.string().min(1, "Password is required"),
});

export const signupSchema = z
  .object({
    name: validations.name,
    email: validations.email,
    password: validations.password,
    confirm: z.string().min(1, "Confirm your password"),
    terms: z.boolean().refine((v) => v === true, { message: "Accept the terms to continue" }),
  })
  .refine((d) => d.password === d.confirm, {
    message: "Passwords do not match",
    path: ["confirm"],
  });

export const profileSchema = z.object({
  name: validations.name,
  bio: z.string().max(280, "Keep it under 280 characters").optional(),
});

export type LoginValues = z.infer<typeof loginSchema>;
export type SignupValues = z.infer<typeof signupSchema>;
export type ProfileValues = z.infer<typeof profileSchema>;
