import React from 'react';
import { PrimitiveProps, buildPrimitiveRef } from "../common";

export const OHLCPrimitive: React.FC<PrimitiveProps> = ({
  data,
  config,
  loading,
  error,
  adapter,
}) => {
  if (loading) {
    return <div className="skeleton-loader">Loading...</div>;
  }

  if (error) {
    return <div className="error-panel">Error: {error}</div>;
  }

  return adapter.render(buildPrimitiveRef(config), data, config.options || {});
};