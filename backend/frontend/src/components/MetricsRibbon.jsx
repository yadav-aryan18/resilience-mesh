import React from 'react';
import { Activity, AlertTriangle, Radio, Gauge, Zap } from 'lucide-react';

export default function MetricsRibbon({ statsData }) {
  const total = statsData?.total_requests ?? 0;
  const redCount = statsData?.urgency_counts?.red ?? 0;
  const yellowCount = statsData?.urgency_counts?.yellow ?? 0;
  const greenCount = statsData?.urgency_counts?.green ?? 0;
  const avgLatency = statsData?.avg_latency_ms ?? 0;
  const activeSectors = statsData?.active_sectors ?? [];

  return (
    <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      {/* Total Field Triage Requests */}
      <div className="glass-panel p-4 flex items-center justify-between">
        <div>
          <p className="text-xs uppercase tracking-wider font-semibold text-slate-400 mb-1">
            Total Triage Requests
          </p>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-extrabold font-mono text-white">{total}</span>
            <span className="text-xs text-cyan-400 font-mono">Processed</span>
          </div>
        </div>
        <div className="p-3 rounded-xl bg-cyan-500/10 border border-cyan-500/30 text-cyan-400">
          <Activity className="w-6 h-6" />
        </div>
      </div>

      {/* Urgency Distribution */}
      <div className="glass-panel p-4 flex items-center justify-between">
        <div>
          <p className="text-xs uppercase tracking-wider font-semibold text-slate-400 mb-1">
            Urgency Breakdown
          </p>
          <div className="flex items-center gap-3 mt-1.5 font-mono text-sm font-bold">
            <span className="px-2 py-0.5 rounded badge-red">{redCount} Red</span>
            <span className="px-2 py-0.5 rounded badge-yellow">{yellowCount} Yel</span>
            <span className="px-2 py-0.5 rounded badge-green">{greenCount} Grn</span>
          </div>
        </div>
        <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400">
          <AlertTriangle className="w-6 h-6" />
        </div>
      </div>

      {/* Active Sectors Covered */}
      <div className="glass-panel p-4 flex items-center justify-between">
        <div>
          <p className="text-xs uppercase tracking-wider font-semibold text-slate-400 mb-1">
            Active Mesh Sectors
          </p>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-extrabold font-mono text-purple-300">
              {activeSectors.length > 0 ? activeSectors.length : '0'}
            </span>
            <span className="text-xs text-slate-400 truncate max-w-[120px]">
              {activeSectors.length > 0 ? activeSectors.join(', ') : 'Monitoring...'}
            </span>
          </div>
        </div>
        <div className="p-3 rounded-xl bg-purple-500/10 border border-purple-500/30 text-purple-400">
          <Radio className="w-6 h-6" />
        </div>
      </div>

      {/* Average LLM Latency */}
      <div className="glass-panel p-4 flex items-center justify-between">
        <div>
          <p className="text-xs uppercase tracking-wider font-semibold text-slate-400 mb-1">
            Avg LLM Response Time
          </p>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-extrabold font-mono text-emerald-400">
              {avgLatency > 1000 ? `${(avgLatency / 1000).toFixed(1)}s` : `${avgLatency}ms`}
            </span>
            <span className="text-xs text-emerald-500 font-mono">Gemma 4</span>
          </div>
        </div>
        <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-400">
          <Zap className="w-6 h-6" />
        </div>
      </div>
    </section>
  );
}
