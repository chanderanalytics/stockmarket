"use client";

import * as React from "react";
import { PageHeader } from "@/shared/design-system/PageHeader";
import { PriceTrendV2Widget } from "@/analytics/widgets";

export default function PriceTrendV2Page() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Price Trends V2"
        description="Market-cap weighted price trends. Sector and industry returns are computed as weighted averages using each company's market cap."
      />
      <PriceTrendV2Widget />
    </div>
  );
}
