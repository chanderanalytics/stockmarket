import { api } from "../api-client";

export const priceTrendService = {
  data: (params?: Record<string, unknown>) =>
    api.get<{
      level: "company";
      periods: string[];
      total: number;
      rows: Array<{
        id: string;
        name: string;
        sector: string;
        industry: string;
        industrySubGroup: string;
        marketCap: number;
        marketCapBucket: string;
        [period: string]: string | number | null;
      }>;
    }>("/api/price-trends", { params }),
  latestDate: () => api.get<{ date: string | null }>("/api/price-trends/latest-date"),
};
