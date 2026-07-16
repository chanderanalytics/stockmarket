import React from 'react';

interface VisualizationLegendProps {
  items: Array<{ key: string; label: string; color?: string }>;
  position?: "top" | "bottom" | "left" | "right";
  className?: string;
}

export const VisualizationLegend: React.FC<VisualizationLegendProps> = ({
  items,
  position = "bottom",
  className,
}) => {
  return (
    <div className={`visualization-legend visualization-legend--${position} ${className ?? ""}`}>
      {items.map((item) => (
        <div key={item.key} className="visualization-legend__item">
          {item.color && (
            <span
              className="visualization-legend__swatch"
              style={{ backgroundColor: item.color }}
            />
          )}
          <span className="visualization-legend__label">{item.label}</span>
        </div>
      ))}
    </div>
  );
};