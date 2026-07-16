import React from 'react';

interface VisualizationLoadingProps {
  label?: string;
  className?: string;
}

export const VisualizationLoading: React.FC<VisualizationLoadingProps> = ({
  label = "Loading...",
  className,
}) => {
  return (
    <div className={`visualization-loading ${className ?? ""}`} role="status" aria-live="polite">
      <div className="visualization-loading__spinner" />
      <span className="visualization-loading__label">{label}</span>
    </div>
  );
};