import React from 'react';
import { Brain, FileText, AlertTriangle, ShieldCheck, MapPin } from 'lucide-react';

export default function ReasoningInspector({ activity }) {
  if (!activity) {
    return (
      <div className="glass-panel p-6 text-center text-slate-500 font-mono text-xs">
        Select a field report to inspect AI reasoning traces & Red Cross protocol citations.
      </div>
    );
  }

  const steps = activity.first_aid_steps || [];
  const sources = activity.sources || [];
  const reasoning = activity.reasoning_trace;
  const evacuation = activity.evacuation_target;
  const alerts = activity.hazard_alerts || [];

  return (
    <div className="glass-panel p-5 space-y-5">
      <div className="flex items-center justify-between pb-3 border-b border-slate-800">
        <h3 className="text-sm font-bold tracking-tight text-white flex items-center gap-2">
          <Brain className="w-4 h-4 text-purple-400" />
          Gemma 4 Reasoning & Protocol Grounding
        </h3>
        <span className="text-xs font-mono text-cyan-400 bg-cyan-950/40 px-2 py-0.5 rounded border border-cyan-800/30">
          {activity.latency_ms} ms
        </span>
      </div>

      {/* Clinical Summary */}
      <div>
        <h4 className="text-xs font-semibold text-slate-400 mb-1.5 uppercase tracking-wider">
          Clinical & Tactical Summary
        </h4>
        <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 text-slate-200 text-xs leading-relaxed font-sans">
          {activity.clinical_summary}
        </div>
      </div>

      {/* Evacuation Route & Hazard Alerts */}
      {(evacuation || alerts.length > 0) && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {evacuation && (
            <div className="p-3 rounded-xl bg-amber-950/20 border border-amber-800/40">
              <div className="flex items-center gap-1.5 text-xs font-bold text-amber-400 mb-1">
                <MapPin className="w-4 h-4 text-amber-400" />
                <span>EVACUATION TARGET</span>
              </div>
              <p className="text-xs font-mono text-amber-200">{evacuation}</p>
            </div>
          )}

          {alerts.length > 0 && (
            <div className="p-3 rounded-xl bg-red-950/20 border border-red-800/40">
              <div className="flex items-center gap-1.5 text-xs font-bold text-red-400 mb-1">
                <AlertTriangle className="w-4 h-4 text-red-400" />
                <span>HAZARD ALERTS</span>
              </div>
              <ul className="text-xs font-mono text-red-200 space-y-1">
                {alerts.map((a, i) => (
                  <li key={i}>• {a}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      {/* First-Aid Protocol Steps */}
      <div>
        <h4 className="text-xs font-semibold text-slate-400 mb-2 uppercase tracking-wider flex items-center gap-2">
          <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
          <span>Actionable First-Aid Steps</span>
        </h4>
        <div className="space-y-2">
          {steps.map((step, idx) => (
            <div
              key={idx}
              className="flex items-start gap-3 p-2.5 rounded-lg bg-slate-900/60 border border-slate-800/80 text-xs text-slate-200"
            >
              <span className="flex-shrink-0 w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center justify-center font-mono font-bold text-[10px]">
                {idx + 1}
              </span>
              <span className="mt-0.5 leading-normal">{step}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Reasoning Trace (<|think|> CoT) */}
      {reasoning && (
        <div>
          <h4 className="text-xs font-semibold text-slate-400 mb-1.5 uppercase tracking-wider flex items-center gap-2">
            <Brain className="w-3.5 h-3.5 text-purple-400" />
            <span>Chain-of-Thought Reasoning Trace</span>
          </h4>
          <div className="p-3.5 rounded-xl bg-slate-950/80 border border-purple-900/40 font-mono text-[11px] text-purple-200/90 leading-relaxed whitespace-pre-wrap max-h-48 overflow-y-auto">
            {reasoning}
          </div>
        </div>
      )}

      {/* RAG Protocol Document Citations */}
      {sources.length > 0 && (
        <div>
          <h4 className="text-xs font-semibold text-slate-400 mb-1.5 uppercase tracking-wider flex items-center gap-2">
            <FileText className="w-3.5 h-3.5 text-cyan-400" />
            <span>Red Cross / WHO Document Citations</span>
          </h4>
          <div className="flex flex-wrap gap-2">
            {sources.map((src, i) => (
              <span
                key={i}
                className="px-2.5 py-1 rounded-md bg-cyan-950/40 border border-cyan-800/40 font-mono text-[11px] text-cyan-300"
              >
                📜 {src}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
