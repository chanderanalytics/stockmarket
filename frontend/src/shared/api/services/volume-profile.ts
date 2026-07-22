import { api } from "../api-client";

export const volumeProfileService = {
  data: (params?: Record<string, unknown>) =>
    api.get<{
      level: "sector" | "industry" | "industrySubGroup" | "company";
      total: number;
      rows: Array<{
        id: string;
        name: string;
        sector: string;
        industry: string;
        industrySubGroup: string;
        volume: number;
        avgVol1W: number;
        avgVol1M: number;
        avgVol1Y: number;
        volSortPct: number;
        marketCap: number;
        marketCapBucket: string;
        companyCount: number | null;
        rank: number;
        total: number;
      }>;
    }>("/api/volume-profile", { params }),
  latestDate: () => api.get<{ date: string | null }>("/api/volume-profile/latest-date"),
};
