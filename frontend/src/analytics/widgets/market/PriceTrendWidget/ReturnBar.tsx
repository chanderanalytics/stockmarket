import * as React from "react";

export interface ReturnBarProps {
  normalized: number;
  label?: string;
  color?: string;
}

/**
 * Fully colored cell with the label at the extreme left inside the color.
 * No track, no proportional fill — the entire area is colored by value.
 */
export const ReturnBar = React.memo(function ReturnBar({
  normalized,
  label,
  color = "#cbd5e1",
}: ReturnBarProps) {
  return (
    <div className="relative flex h-full w-full flex-row items-center" style={{ backgroundColor: color }}>
      {label && (
        <span className="truncate pl-1.5  text-[11px] font-bold tabular-nums text-black">
          {label}
        </span>
      )}
    </div>
  );
});
