import React from 'react';

interface PitEmblemProps {
  size?: number;
  pulse?: boolean;
  className?: string;
}

/**
 * Apple Squircle Brand Icon (Matching Aexus Spear & MacApp 1:1)
 */
export const PitEmblem: React.FC<PitEmblemProps> = ({
  size = 36,
  className = '',
}) => {
  const radius = Math.round(size * 0.235);
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: radius,
        background: 'linear-gradient(145deg, #23252F 0%, #0E0F14 100%)',
        boxShadow: '0 4px 10px rgba(0,0,0,0.14), inset 0 1px 0 rgba(255,255,255,0.18)',
        border: '1px solid rgba(0,0,0,0.12)',
      }}
      className={`relative flex items-center justify-center shrink-0 overflow-hidden ${className}`}
    >
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background:
            'radial-gradient(circle at 28% 22%, rgba(255,255,255,0.20), transparent 55%)',
        }}
      />
      <svg
        width={Math.round(size * 0.72)}
        height={Math.round(size * 0.72)}
        viewBox="0 0 64 64"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <circle cx="32" cy="32" r="24" stroke="rgba(255,255,255,0.22)" strokeWidth="2.2" />
        <circle cx="32" cy="32" r="15" stroke="rgba(0,122,255,0.55)" strokeWidth="1.8" />
        <polygon points="24,6 40,6 32,24" fill="#FF5A36" />
        <polygon points="24,58 40,58 32,40" fill="#007AFF" />
        <circle cx="32" cy="32" r="5.5" fill="#FFFFFF" />
      </svg>
    </div>
  );
};

interface AppleSquircleIconProps {
  colors: [string, string];
  size?: number;
  children: React.ReactNode;
  className?: string;
}

/**
 * Glossy 62px / 48px / 28px App Store Squircle Tile Icon (Exact Aexus Spear card tile)
 */
export const AppleSquircleIcon: React.FC<AppleSquircleIconProps> = ({
  colors,
  size = 60,
  children,
  className = '',
}) => {
  const radius = Math.round(size * 0.225);
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: radius,
        background: `linear-gradient(135deg, ${colors[0]} 0%, ${colors[1]} 100%)`,
        boxShadow: `0 ${Math.max(2, Math.round(size * 0.08))}px ${Math.round(
          size * 0.22
        )}px ${colors[0]}26, inset 0 1px 0 rgba(255,255,255,0.32)`,
        border: '1px solid rgba(0,0,0,0.06)',
      }}
      className={`relative flex items-center justify-center shrink-0 overflow-hidden text-white ${className}`}
    >
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background:
            'linear-gradient(145deg, rgba(255,255,255,0.28) 0%, rgba(255,255,255,0.02) 52%, rgba(0,0,0,0.12) 100%)',
        }}
      />
      <div className="relative z-10 flex items-center justify-center drop-shadow-sm">
        {children}
      </div>
    </div>
  );
};

interface AppleOpenPillProps {
  label: string;
  active?: boolean;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  title?: string;
}

/**
 * App Store "OPEN / 选择 / 选作靶标" Capsule Pill Button
 */
export const AppleOpenPill: React.FC<AppleOpenPillProps> = ({
  label,
  active = false,
  onClick,
  title,
}) => {
  return (
    <button
      type="button"
      onClick={onClick}
      title={title}
      className={`px-3.5 py-1.5 rounded-full text-[11.5px] font-bold tracking-tight transition-all shrink-0 ${
        active
          ? 'bg-[#007AFF] text-white shadow-sm hover:bg-[#0066D6]'
          : 'bg-[#EBF3FF] text-[#007AFF] hover:bg-[#DCEBFE] border border-[#007AFF]/15'
      }`}
    >
      {label}
    </button>
  );
};
