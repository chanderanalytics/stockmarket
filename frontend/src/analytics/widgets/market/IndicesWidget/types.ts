export interface IndexFeatureRow {
  name: string;
  ticker: string;
  region: string;
  description: string;
  date: string | null;
  open: number | null;
  high: number | null;
  low: number | null;
  close: number | null;
  volume: number | null;
  last_modified: string | null;
  as_of_date: string | null;
  return_1d: number | null;
  return_2d: number | null;
  return_3d: number | null;
  return_4d: number | null;
  return_5d: number | null;
  return_21d: number | null;
  return_63d: number | null;
  return_126d: number | null;
  return_252d: number | null;
  return_504d: number | null;
  return_756d: number | null;
  return_1260d: number | null;
  return_2520d: number | null;
}

export interface IndexPriceRow {
  date: string | null;
  open: number | null;
  high: number | null;
  low: number | null;
  close: number | null;
  volume: number | null;
}

export interface RegionalRow {
  region: string;
  avg_return: number | null;
  index_count: number;
}

export const RETURN_PERIODS = [
  { key: "return_1d", label: "1D" },
  { key: "return_5d", label: "5D" },
  { key: "return_21d", label: "1M" },
  { key: "return_63d", label: "3M" },
  { key: "return_126d", label: "6M" },
  { key: "return_252d", label: "1Y" },
  { key: "return_504d", label: "2Y" },
  { key: "return_756d", label: "3Y" },
  { key: "return_1260d", label: "5Y" },
  { key: "return_2520d", label: "10Y" },
] as const;

export type SortKey = keyof Pick<
  IndexFeatureRow,
  | "name"
  | "ticker"
  | "region"
  | "close"
  | "return_1d"
  | "return_2d"
  | "return_3d"
  | "return_4d"
  | "return_5d"
  | "return_21d"
  | "return_63d"
  | "return_126d"
  | "return_252d"
  | "return_504d"
  | "return_756d"
  | "return_1260d"
  | "return_2520d"
>;
export type ReturnSortKey =
  | "return_1d"
  | "return_2d"
  | "return_3d"
  | "return_4d"
  | "return_5d"
  | "return_21d"
  | "return_63d"
  | "return_126d"
  | "return_252d"
  | "return_504d"
  | "return_756d"
  | "return_1260d"
  | "return_2520d";
export type SortDir = "asc" | "desc";
