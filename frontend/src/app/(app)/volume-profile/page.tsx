"use client";

import * as React from "react";
import { PageHeader } from "@/shared/design-system/PageHeader";
import { VolumeProfileWidget } from "@/analytics/widgets";

export default function VolumeProfilePage() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Volume Profile"
        description="Compare today's trading volume with historical averages across the market hierarchy. Each row is normalized to 100%."
      />
      <VolumeProfileWidget />
    </div>
  );
}
