import { api } from "@/shared/api/api-client";

export const volumeProfileV2Service = {
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
        relative1W: number | null;
        relative1M: number | null;
        relative1Y: number | null;
        marketCap: number;
        marketCapBucket: string;
        companyCount: number | null;
        rank: number;
        total: number;
      }>;
    }>("/api/volume-profile-v2", { params }),
  latestDate: () => api.get<{ date: string | null }>("/api/volume-profile-v2/latest-date"),
};
