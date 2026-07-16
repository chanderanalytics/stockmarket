import { api } from "../api-client";
import type { Holding, Portfolio } from "../types";

export const portfolioService = {
  summary: () => api.get<Portfolio>("/portfolio/summary"),
};
