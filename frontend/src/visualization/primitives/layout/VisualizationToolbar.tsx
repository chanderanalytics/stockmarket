import React from 'react';

interface VisualizationToolbarProps {
  items: Array<{ key: string; label: string; onClick: () => void; icon?: React.ReactNode }>;
  className?: string;
}

export const VisualizationToolbar: React.FC<VisualizationToolbarProps> = ({ items, className }) => {
  return (
    <div className={`visualization-toolbar ${className ?? ""}`} role="toolbar">
      {items.map((item) => (
        <button
          key={item.key}
          type="button"
          className="visualization-toolbar__item"
          onClick={item.onClick}
        >
          {item.icon}
          {item.label}
        </button>
      ))}
    </div>
  );
};