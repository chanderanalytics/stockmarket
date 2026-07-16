import type { ReactNode } from "react";

export type ColumnDef<T> = {
  key: string;
  header: ReactNode;
  accessor?: (row: T) => unknown;
  cell?: (row: T) => ReactNode;
  filterValue?: (row: T) => string;
  sortable?: boolean;
  align?: "left" | "right" | "center";
  className?: string;
};
