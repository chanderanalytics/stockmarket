import React from 'react';

interface VisualizationTooltipProps {
  visible: boolean;
  x?: number;
  y?: number;
  content?: React.ReactNode;
  className?: string;
}

export const VisualizationTooltip: React.FC<VisualizationTooltipProps> = ({
  visible,
  x,
  y,
  content,
  className,
}) => {
  if (!visible) return null;

  const style: React.CSSProperties = {
    position: "fixed",
    left: x,
    top: y,
    pointerEvents: "none",
  };

  return (
    <div className={`visualization-tooltip ${className ?? ""}`} style={style} role="tooltip">
      {content}
    </div>
  );
};