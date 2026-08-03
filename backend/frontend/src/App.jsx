import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import MetricsRibbon from './components/MetricsRibbon';
import IncidentFeed from './components/IncidentFeed';
import MediaLightroom from './components/MediaLightroom';
import ReasoningInspector from './components/ReasoningInspector';
import TestConsole from './components/TestConsole';
import { Activity, Shield, RefreshCw } from 'lucide-react';

export default function App() {
  const [healthData, setHealthData] = useState(null);
  const [statsData, setStatsData] = useState(null);
  const [activities, setActivities] = useState([]);
  const [selectedActivity, setSelectedActivity] = useState(null);
  const [activeTab, setActiveTab] = useState('stream'); // 'stream' | 'test'
  const [loading, setLoading] = useState(true);

  const fetchTelemetry = async () => {
    try {
      const [hRes, sRes, aRes] = await Promise.all([
        fetch('/api/health').then((r) => (r.ok ? r.json() : null)),
        fetch('/api/stats').then((r) => (r.ok ? r.json() : null)),
        fetch('/api/activities').then((r) => (r.ok ? r.json() : [])),
      ]);

      if (hRes) setHealthData(hRes);
      if (sRes) setStatsData(sRes);
      if (Array.isArray(aRes)) {
        setActivities(aRes);
        // Retain current selection if present, else default to latest
        if (!selectedActivity && aRes.length > 0) {
          setSelectedActivity(aRes[0]);
        } else if (selectedActivity) {
          const updated = aRes.find((a) => a.id === selectedActivity.id);
          if (updated) setSelectedActivity(updated);
        }
      }
    } catch (err) {
      console.warn('Telemetry poll notice:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTelemetry();
    const interval = setInterval(fetchTelemetry, 2500);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen flex flex-col">
      {/* Top Navbar */}
      <Navbar healthData={healthData} />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 py-6">
        {/* Metrics Ribbon */}
        <MetricsRibbon statsData={statsData} />

        {/* Action Bar & Tab Navigation */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2 p-1 rounded-xl bg-slate-900/80 border border-slate-800">
            <button
              onClick={() => setActiveTab('stream')}
              className={`px-4 py-1.5 rounded-lg text-xs font-semibold tracking-wide transition-all ${
                activeTab === 'stream'
                  ? 'bg-cyan-500 text-slate-950 shadow-[0_0_12px_rgba(0,240,255,0.3)]'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              Live Incident Stream ({activities.length})
            </button>
            <button
              onClick={() => setActiveTab('test')}
              className={`px-4 py-1.5 rounded-lg text-xs font-semibold tracking-wide transition-all ${
                activeTab === 'test'
                  ? 'bg-cyan-500 text-slate-950 shadow-[0_0_12px_rgba(0,240,255,0.3)]'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              Command Test Console
            </button>
          </div>

          <button
            onClick={fetchTelemetry}
            className="p-2 rounded-xl bg-slate-900/60 border border-slate-800 text-slate-400 hover:text-cyan-400 text-xs font-mono flex items-center gap-1.5"
            title="Refresh Telemetry"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Poll Now</span>
          </button>
        </div>

        {/* Modular Grid Layout */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Left Column: Stream or Test Console */}
          <div className="lg:col-span-5 space-y-4">
            {activeTab === 'stream' ? (
              <IncidentFeed
                activities={activities}
                selectedId={selectedActivity?.id}
                onSelectActivity={(act) => setSelectedActivity(act)}
              />
            ) : (
              <TestConsole onTriageComplete={fetchTelemetry} />
            )}
          </div>

          {/* Right Column: Media Lightroom & Reasoning Inspector */}
          <div className="lg:col-span-7 space-y-6">
            <MediaLightroom activity={selectedActivity} />
            <ReasoningInspector activity={selectedActivity} />
          </div>
        </div>
      </main>

      {/* Footer Status */}
      <footer className="py-4 border-t border-slate-800/60 text-center text-xs font-mono text-slate-500">
        ResilienceMesh Tier 2 Command Node • Air-Gapped Tactical First-Aid Protocol Engine
      </footer>
    </div>
  );
}
