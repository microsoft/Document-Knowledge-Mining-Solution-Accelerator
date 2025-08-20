import React, { useState, useRef, useEffect } from 'react';

interface PanelResizerProps {
  onResize?: (leftWidth: number, rightWidth: number) => void;
  minLeftWidth?: number;
  minRightWidth?: number;
  initialLeftWidth?: number;
}

export const PanelResizer: React.FC<PanelResizerProps> = ({
  onResize,
  minLeftWidth = 200,
  minRightWidth = 200,
  initialLeftWidth = 50
}) => {
  const [isDragging, setIsDragging] = useState(false);
  const resizerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!isDragging || !resizerRef.current) return;

      const container = resizerRef.current.parentElement;
      if (!container) return;

      const containerRect = container.getBoundingClientRect();
      const newLeftWidth = ((e.clientX - containerRect.left) / containerRect.width) * 100;
      const newRightWidth = 100 - newLeftWidth;

      // Apply minimum width constraints
      const minLeftPercent = (minLeftWidth / containerRect.width) * 100;
      const minRightPercent = (minRightWidth / containerRect.width) * 100;

      if (newLeftWidth >= minLeftPercent && newRightWidth >= minRightPercent) {
        onResize?.(newLeftWidth, newRightWidth);
      }
    };

    const handleMouseUp = () => {
      setIsDragging(false);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    };

    if (isDragging) {
      document.body.style.cursor = 'col-resize';
      document.body.style.userSelect = 'none';
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    }

    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging, onResize, minLeftWidth, minRightWidth]);

  const handleMouseDown = () => {
    setIsDragging(true);
  };

  const resizerStyle: React.CSSProperties = {
    width: '8px',
    background: isDragging ? '#d0d0d0' : '#f0f0f0',
    borderLeft: '1px solid #ddd',
    borderRight: '1px solid #ddd',
    cursor: 'col-resize',
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    transition: 'background-color 0.2s ease',
    userSelect: 'none',
    flexShrink: 0,
  };

  const handleStyle: React.CSSProperties = {
    height: '60px',
    width: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    pointerEvents: 'none',
  };

  const dotsStyle: React.CSSProperties = {
    display: 'flex',
    flexDirection: 'column',
    gap: '3px',
    alignItems: 'center',
  };

  const dotStyle: React.CSSProperties = {
    width: '3px',
    height: '3px',
    backgroundColor: isDragging ? '#333' : '#999',
    borderRadius: '50%',
  };

  return (
    <div
      ref={resizerRef}
      style={resizerStyle}
      onMouseDown={handleMouseDown}
      onMouseEnter={(e) => {
        if (!isDragging) {
          (e.target as HTMLElement).style.background = '#e0e0e0';
        }
      }}
      onMouseLeave={(e) => {
        if (!isDragging) {
          (e.target as HTMLElement).style.background = '#f0f0f0';
        }
      }}
    >
      <div style={handleStyle}>
        <div style={dotsStyle}>
          <div style={dotStyle}></div>
          <div style={dotStyle}></div>
          <div style={dotStyle}></div>
        </div>
      </div>
    </div>
  );
};
