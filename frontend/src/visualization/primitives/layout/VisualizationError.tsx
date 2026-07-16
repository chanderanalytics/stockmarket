import React from 'react';

interface VisualizationErrorProps {
  message: string;
  detail?: string;
  onRetry?: () => void;
  className?: string;
}

export const VisualizationError: React.FC<VisualizationErrorProps> = ({
  message,
  detail,
  onRetry,
  className,
}) => {
  return (
    <div className={`visualization-error ${className ?? ""}`} role="alert">
      <span className="visualization-error__message">{message}</span>
      {detail && <span className="visualization-error__detail">{detail}</span>}
      {onRetry && (
        <button type="button" className="visualization-error__retry" onClick={onRetry}>
          Retry
        </button>
      )}
    </div>
  );
};