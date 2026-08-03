import React, { useState } from 'react';
import { Send, Terminal, Loader2, Sparkles } from 'lucide-react';

export default function TestConsole({ onTriageComplete }) {
  const [textQuery, setTextQuery] = useState('');
  const [sectorId, setSectorId] = useState('Sector 4');
  const [audioTranscript, setAudioTranscript] = useState('');
  const [loading, setLoading] = useState(false);
  const [lastResponse, setLastResponse] = useState(null);

  const presets = [
    { title: 'Severe Arterial Bleeding', query: 'Victim with deep laceration on thigh, arterial spurting blood, pulse weak.', sector: 'Sector 2' },
    { title: 'Rapid Flood Evacuation', query: 'Water rising to roof level in Sector 4. 2 adults and 1 infant trapped on rooftop.', sector: 'Sector 4' },
    { title: 'Structural Collapse & Fracture', query: 'Building collapse. Victim pinned under concrete beam with suspected femur fracture.', sector: 'Sector 7' },
  ];

  const handleApplyPreset = (preset) => {
    setTextQuery(preset.query);
    setSectorId(preset.sector);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!textQuery.trim()) return;

    setLoading(true);
    setLastResponse(null);

    try {
      const payloadObj = {
        text_query: textQuery.trim(),
        audio_transcript: audioTranscript.trim() || null,
        sector_id: sectorId.trim() || null,
        timestamp: new Date().toISOString(),
      };

      const formData = new FormData();
      formData.append('payload', JSON.stringify(payloadObj));

      const res = await fetch('/api/expert-triage', {
        method: 'POST',
        body: formData,
      });

      if (!res.ok) {
        throw new Error(`Server error ${res.status}`);
      }

      const data = await res.json();
      setLastResponse(data);
      if (onTriageComplete) onTriageComplete();
    } catch (err) {
      alert(`Test Query Failed: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="glass-panel p-5 space-y-4">
      <div className="flex items-center justify-between pb-3 border-b border-slate-800">
        <h3 className="text-sm font-bold tracking-tight text-white flex items-center gap-2">
          <Terminal className="w-4 h-4 text-cyan-400" />
          Command Test Console (Laptop Simulator)
        </h3>
        <span className="text-[10px] font-mono text-slate-400">Trigger Direct Inference</span>
      </div>

      {/* Quick Presets */}
      <div>
        <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider block mb-2">
          Quick Incident Presets:
        </span>
        <div className="flex flex-wrap gap-2">
          {presets.map((p, i) => (
            <button
              key={i}
              type="button"
              onClick={() => handleApplyPreset(p)}
              className="px-2.5 py-1.5 rounded-lg bg-slate-900/80 border border-slate-800 hover:border-cyan-500/50 text-xs text-slate-300 hover:text-cyan-300 transition-all flex items-center gap-1.5"
            >
              <Sparkles className="w-3 h-3 text-cyan-400" />
              <span>{p.title}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Form Inputs */}
      <form onSubmit={handleSubmit} className="space-y-3">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div className="md:col-span-2">
            <label className="text-xs font-semibold text-slate-400 block mb-1">Field Query / Incident Report</label>
            <input
              type="text"
              value={textQuery}
              onChange={(e) => setTextQuery(e.target.value)}
              placeholder="e.g. Victim unconscious with head injury..."
              className="w-full px-3.5 py-2 rounded-xl bg-slate-950/80 border border-slate-800 text-xs text-white placeholder-slate-600 focus:outline-none focus:border-cyan-400"
              required
            />
          </div>
          <div>
            <label className="text-xs font-semibold text-slate-400 block mb-1">Sector ID</label>
            <input
              type="text"
              value={sectorId}
              onChange={(e) => setSectorId(e.target.value)}
              placeholder="Sector 1"
              className="w-full px-3.5 py-2 rounded-xl bg-slate-950/80 border border-slate-800 text-xs text-white placeholder-slate-600 focus:outline-none focus:border-cyan-400 font-mono"
            />
          </div>
        </div>

        <div>
          <label className="text-xs font-semibold text-slate-400 block mb-1">Simulated Audio Transcript (Optional)</label>
          <input
            type="text"
            value={audioTranscript}
            onChange={(e) => setAudioTranscript(e.target.value)}
            placeholder="Spoken voice transcript..."
            className="w-full px-3.5 py-2 rounded-xl bg-slate-950/80 border border-slate-800 text-xs text-white placeholder-slate-600 focus:outline-none focus:border-cyan-400"
          />
        </div>

        <button
          type="submit"
          disabled={loading || !textQuery.trim()}
          className="w-full py-2.5 px-4 rounded-xl bg-cyan-500 hover:bg-cyan-400 disabled:opacity-50 text-slate-950 font-bold text-xs tracking-wide transition-all flex items-center justify-center gap-2 shadow-[0_0_20px_rgba(0,240,255,0.3)]"
        >
          {loading ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              <span>Executing Gemma 4 Inference + RAG...</span>
            </>
          ) : (
            <>
              <Send className="w-4 h-4" />
              <span>Execute Triage Test Request</span>
            </>
          )}
        </button>
      </form>
    </div>
  );
}
