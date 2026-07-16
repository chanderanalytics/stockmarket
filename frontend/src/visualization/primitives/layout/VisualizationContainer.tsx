import React from 'react';
import type { VisualizationConfiguration } from '../../types';

interface VisualizationContainerProps {
  children: React.ReactNode;
  config?: Partial<VisualizationConfiguration>;
  fullscreen?: boolean;
  className?: string;
}

export const VisualizationContainer: React.FC<VisualizationContainerProps> = ({
  children,
  config,
  fullscreen,
  className,
}) => {
  const width = config?.options && (config.options as any).width;
  const height = config?.options && (config.options as any).height;

  const style: React.CSSProperties = {
    width: width ?? "100%",
    height: height ?? "100%",
    position: fullscreen ? "fixed" : "relative",
    inset: fullscreen ? 0 : undefined,
    zIndex: fullscreen ? 9999 : undefined,
  };

  return (
    <div className={`visualization-container ${className ?? ""}`} style={style}>
      {children}
    </div>
  );
};