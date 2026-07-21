import { api } from "../api-client";

export const priceTrendV2Service = {
  data: (params?: Record<string, unknown>) =>
    api.get<{
      level: "sector" | "industry" | "industrySubGroup" | "company";
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
    }>("/api/price-trends-v2", { params }),
  latestDate: () => api.get<{ date: string | null }>("/api/price-trends-v2/latest-date"),
};
