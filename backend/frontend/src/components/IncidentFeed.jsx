import React from 'react';
import { MessageSquare, Camera, Mic, MapPin, Clock, ArrowRight, ShieldAlert, CheckCircle2, ChevronRight } from 'lucide-react';

export default function IncidentFeed({ activities, selectedId, onSelectActivity }) {
  if (!activities || activities.length === 0) {
    return (
      <div className="glass-panel p-8 text-center flex flex-col items-center justify-center min-h-[300px]">
        <div className="p-4 rounded-full bg-slate-900/80 border border-slate-800 text-slate-500 mb-3">
          <MessageSquare className="w-8 h-8" />
        </div>
        <h3 className="text-base font-semibold text-slate-300">No Field Reports Recorded</h3>
        <p className="text-xs text-slate-500 max-w-sm mt-1">
          Awaiting field triage requests from Mobile Edge Nodes or Command Test Console...
        </p>
      </div>
    );
  }

  const getUrgencyBadge = (urgency) => {
    switch (urgency?.toLowerCase()) {
      case 'red':
      case 'critical':
        return <span className="px-2.5 py-1 rounded-md text-xs font-bold font-mono badge-red">CRITICAL RED</span>;
      case 'yellow':
      case 'urgent':
        return <span className="px-2.5 py-1 rounded-md text-xs font-bold font-mono badge-yellow">URGENT YELLOW</span>;
      default:
        return <span className="px-2.5 py-1 rounded-md text-xs font-bold font-mono badge-green">STABLE GREEN</span>;
    }
  };

  return (
    <div className="space-y-3">
      {activities.map((item) => {
        const isSelected = selectedId === item.id;
        const timeFormatted = item.timestamp ? new Date(item.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : 'Just now';

        return (
          <div
            key={item.id}
            onClick={() => onSelectActivity(item)}
            className={`glass-panel p-4 cursor-pointer transition-all duration-200 border ${
              isSelected
                ? 'border-cyan-400/60 bg-slate-900/80 shadow-[0_0_20px_rgba(0,240,255,0.15)]'
                : 'hover:border-slate-700 hover:bg-slate-900/40'
            }`}
          >
            <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
              <div className="flex items-center gap-2">
                <span className="font-mono text-xs font-semibold text-cyan-400 px-2 py-0.5 rounded bg-cyan-950/60 border border-cyan-800/40">
                  {item.id}
                </span>
                <div className="flex items-center gap-1 text-xs font-mono text-slate-400">
                  <MapPin className="w-3.5 h-3.5 text-purple-400" />
                  <span>{item.sector_id}</span>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <div className="flex items-center gap-1.5 text-[11px] font-mono text-slate-400">
                  <Clock className="w-3 h-3 text-slate-500" />
                  <span>{timeFormatted}</span>
                </div>
                {getUrgencyBadge(item.urgency_level)}
              </div>
            </div>

            {/* Field Query snippet */}
            <p className="text-sm font-medium text-slate-200 line-clamp-2 mb-2">
              "{item.text_query}"
            </p>

            {/* Media Badges */}
            <div className="flex items-center justify-between pt-2 border-t border-slate-800/60 text-xs">
              <div className="flex items-center gap-3">
                {item.has_image && (
                  <span className="flex items-center gap-1 text-cyan-300 font-mono text-[11px] bg-cyan-950/40 px-2 py-0.5 rounded border border-cyan-800/30">
                    <Camera className="w-3 h-3" /> Photo Attached
                  </span>
                )}
                {item.audio_transcript && (
                  <span className="flex items-center gap-1 text-purple-300 font-mono text-[11px] bg-purple-950/40 px-2 py-0.5 rounded border border-purple-800/30">
                    <Mic className="w-3 h-3" /> Voice Note
                  </span>
                )}
                {item.web_enhanced && (
                  <span className="flex items-center gap-1 text-emerald-400 font-mono text-[11px] bg-emerald-950/40 px-2 py-0.5 rounded border border-emerald-800/30">
                    Web Enhanced
                  </span>
                )}
              </div>

              <div className="flex items-center gap-1 text-slate-400 font-mono text-[11px] group-hover:text-cyan-400">
                <span>View Details</span>
                <ChevronRight className="w-3.5 h-3.5 text-cyan-400" />
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
