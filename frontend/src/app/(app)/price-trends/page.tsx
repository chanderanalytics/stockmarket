"use client";

import * as React from "react";
import { PageHeader } from "@/shared/design-system/PageHeader";
import { PriceTrendWidget } from "@/analytics/widgets";

export default function PriceTrendsPage() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Price Trends"
        description="Compare company price performance across multiple lookback periods."
      />
      <PriceTrendWidget />
    </div>
  );
}
