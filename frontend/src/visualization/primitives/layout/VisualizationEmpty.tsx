import React from 'react';

interface VisualizationEmptyProps {
  message?: string;
  className?: string;
}

export const VisualizationEmpty: React.FC<VisualizationEmptyProps> = ({
  message = "No data available",
  className,
}) => {
  return (
    <div className={`visualization-empty ${className ?? ""}`} role="status">
      <span className="visualization-empty__message">{message}</span>
    </div>
  );
};