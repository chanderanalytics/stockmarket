import { api } from "../api-client";
import type { AuthResponse, User } from "../types";

export const authService = {
  login: (email: string, password: string) =>
    api.post<AuthResponse>("/auth/login", { email, password }),
  register: (name: string, email: string, password: string) =>
    api.post<AuthResponse>("/auth/register", { name, email, password }),
  me: () => api.get<User>("/auth/me"),
  logout: () => api.post<void>("/auth/logout"),
};
