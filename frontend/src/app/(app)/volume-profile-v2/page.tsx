"use client";

import * as React from "react";
import { PageHeader } from "@/shared/design-system/PageHeader";
import { VolumeProfileV2Widget } from "@/analytics/widgets";

export default function VolumeProfileV2Page() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Volume Profile V2"
        description="Relative volume comparison: today's volume vs the entity's own historical averages (1W, 1M, 1Y)."
      />
      <VolumeProfileV2Widget />
    </div>
  );
}
