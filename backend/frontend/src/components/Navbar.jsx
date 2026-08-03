import React, { useState, useEffect } from 'react';
import { Shield, Cpu, Database, Wifi, Clock, Activity, Radio } from 'lucide-react';

export default function Navbar({ healthData }) {
  const [timeStr, setTimeStr] = useState('');

  useEffect(() => {
    const updateClock = () => {
      const now = new Date();
      setTimeStr(now.toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' }));
    };
    updateClock();
    const interval = setInterval(updateClock, 1000);
    return () => clearInterval(interval);
  }, []);

  const isModelLoaded = healthData?.model_loaded ?? false;
  const isOnline = healthData?.web_connectivity ?? false;
  const ragCount = healthData?.vector_db_chunks ?? 0;
  const ollamaModel = healthData?.ollama_model ?? 'gemma4:12b';

  return (
    <header className="glass-nav sticky top-0 z-50 px-6 py-3.5 flex flex-wrap items-center justify-between gap-4">
      {/* Left Branding */}
      <div className="flex items-center gap-3">
        <div className="p-2.5 rounded-xl bg-cyan-500/10 border border-cyan-500/30 text-cyan-400 shadow-[0_0_15px_rgba(0,240,255,0.2)]">
          <Shield className="w-6 h-6" />
        </div>
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl font-bold tracking-tight text-white">ResilienceMesh</h1>
            <span className="text-[10px] font-mono uppercase tracking-widest px-2 py-0.5 rounded-full bg-cyan-500/15 text-cyan-400 border border-cyan-500/30">
              Tier 2 Node
            </span>
          </div>
          <p className="text-xs text-slate-400">Tactical First-Aid Command Center</p>
        </div>
      </div>

      {/* Middle Health Indicators */}
      <div className="flex items-center gap-5 text-xs font-mono">
        {/* Ollama LLM Status */}
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-900/60 border border-slate-800">
          <Cpu className={`w-4 h-4 ${isModelLoaded ? 'text-cyan-400' : 'text-amber-400'}`} />
          <span className="text-slate-400">LLM:</span>
          <span className="text-slate-200 font-semibold">{ollamaModel}</span>
          <span
            className={`pulse-indicator ${isModelLoaded ? 'bg-cyan-400 shadow-[0_0_8px_#00f0ff]' : 'bg-amber-400'}`}
          />
        </div>

        {/* Vector DB RAG Status */}
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-900/60 border border-slate-800">
          <Database className="w-4 h-4 text-purple-400" />
          <span className="text-slate-400">RAG Vector DB:</span>
          <span className="text-purple-300 font-semibold">{ragCount} Chunks</span>
        </div>

        {/* Opportunistic Web Agent Status */}
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-900/60 border border-slate-800">
          <Wifi className={`w-4 h-4 ${isOnline ? 'text-emerald-400' : 'text-slate-500'}`} />
          <span className="text-slate-400">Web Agent:</span>
          <span className={isOnline ? 'text-emerald-400 font-medium' : 'text-slate-500'}>
            {isOnline ? 'ONLINE' : 'AIR-GAPPED'}
          </span>
          <span
            className={`pulse-indicator ${isOnline ? 'bg-emerald-400 shadow-[0_0_8px_#22c55e]' : 'bg-slate-600'}`}
          />
        </div>
      </div>

      {/* Right Live Clock & Server Badge */}
      <div className="flex items-center gap-4">
        <div className="flex items-center gap-2 font-mono text-xs text-slate-300 px-3 py-1.5 rounded-lg bg-slate-900/80 border border-slate-800">
          <Clock className="w-3.5 h-3.5 text-cyan-400" />
          <span>{timeStr} UTC</span>
        </div>
      </div>
    </header>
  );
}
