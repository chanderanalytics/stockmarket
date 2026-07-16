"use client";

import * as React from "react";
import type { VolumeProfileDrillState, VolumeProfileLevel } from "./VolumeProfile.types";

interface Crumb {
  key: string;
  label: string;
  target: VolumeProfileLevel;
}

const LEVEL_LABEL: Record<VolumeProfileLevel, string> = {
  sector: "Sectors",
  industry: "Industries",
  industrySubGroup: "Sub-groups",
  company: "Companies",
};

const LEVEL_ORDER: VolumeProfileLevel[] = ["sector", "industry", "industrySubGroup", "company"];

export function VolumeProfileHierarchy({
  drill,
  onSelect,
}: {
  drill: VolumeProfileDrillState;
  onSelect: (target: VolumeProfileLevel) => void;
}) {
  const currentIdx = LEVEL_ORDER.indexOf(drill.level);
  const crumbs: Crumb[] = [];

  crumbs.push({ key: "root", label: "Sectors", target: "sector" });

  if (drill.sector || currentIdx >= 1) {
    crumbs.push({
      key: "sector",
      label: drill.sector || LEVEL_LABEL.industry,
      target: "industry",
    });
  }
  if (drill.industry || currentIdx >= 2) {
    crumbs.push({
      key: "industry",
      label: drill.industry || LEVEL_LABEL.industrySubGroup,
      target: "industrySubGroup",
    });
  }
  if (drill.industrySubGroup || currentIdx >= 3) {
    crumbs.push({
      key: "subgroup",
      label: drill.industrySubGroup || LEVEL_LABEL.company,
      target: "company",
    });
  }

  return (
    <nav aria-label="Hierarchy" className="flex flex-wrap items-center gap-1 text-sm">
      {crumbs.map((crumb, index) => (
        <React.Fragment key={crumb.key}>
          {index > 0 && <span className="text-muted-foreground">›</span>}
          <button
            type="button"
            onClick={() => onSelect(crumb.target)}
            className={
              index === crumbs.length - 1
                ? "font-medium text-foreground"
                : "text-muted-foreground transition-colors hover:text-foreground"
            }
          >
            {crumb.label}
          </button>
        </React.Fragment>
      ))}
    </nav>
  );
}
