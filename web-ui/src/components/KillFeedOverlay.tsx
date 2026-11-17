import React from 'react';
import { KillFeedItem } from '../types/pit';

interface KillFeedOverlayProps {
  items: KillFeedItem[];
}

export const KillFeedOverlay: React.FC<KillFeedOverlayProps> = ({ items }) => {
  if (!items.length) return null;

  return (
    <div className="space-y-2">
      {items.slice(0, 8).map((item) => {
        const isPatch = item.is_patch;
        const isCritical = item.is_first_blood || item.is_mana_dry;
        return (
          <div
            key={item.id}
            className="animate-kill-in rounded-xl bg-[#F7F8FA] border border-black/[0.05] p-2.5 space-y-1"
          >
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-1.5 min-w-0">
                <span
                  className={`font-mono text-[9.5px] font-bold px-2 py-0.5 rounded-full shrink-0 ${
                    isPatch
                      ? 'bg-[#007AFF]/10 text-[#007AFF]'
                      : isCritical
                        ? 'bg-[#DC2E33]/12 text-[#DC2E33]'
                        : 'bg-[#D1800A]/12 text-[#D1800A]'
                  }`}
                >
                  {item.probe_tag}
                </span>
                <span className="font-semibold text-[12px] text-[#1A1A1E] truncate">
                  {item.actor_name}
                </span>
              </div>

              {item.points_delta ? (
                <span className="font-mono text-[11px] font-bold text-[#007AFF] shrink-0">
                  +{item.points_delta}
                </span>
              ) : null}
            </div>

            <div className="text-[11.5px] text-[#61626A] leading-snug">{item.action_label}</div>
          </div>
        );
      })}
    </div>
  );
};
