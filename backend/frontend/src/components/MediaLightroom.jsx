import React, { useState } from 'react';
import { Camera, Mic, Play, Pause, ZoomIn, X, Volume2, ShieldAlert } from 'lucide-react';

export default function MediaLightroom({ activity }) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [showImageZoom, setShowImageZoom] = useState(false);

  if (!activity) {
    return (
      <div className="glass-panel p-6 text-center text-slate-500 font-mono text-xs">
        Select an incident to view field photo & play voice notes.
      </div>
    );
  }

  const hasPhoto = activity.has_image && activity.image_base64;
  const imageSrc = hasPhoto ? `data:image/jpeg;base64,${activity.image_base64}` : null;
  const audioTranscript = activity.audio_transcript;

  return (
    <div className="glass-panel p-5 space-y-5">
      <div className="flex items-center justify-between pb-3 border-b border-slate-800">
        <h3 className="text-sm font-bold tracking-tight text-white flex items-center gap-2">
          <Camera className="w-4 h-4 text-cyan-400" />
          Field Media & Telemetry
        </h3>
        <span className="font-mono text-xs text-slate-400">{activity.id}</span>
      </div>

      {/* Captured Photo Section */}
      <div>
        <h4 className="text-xs font-semibold text-slate-400 mb-2 uppercase tracking-wider flex items-center justify-between">
          <span>Captured Disaster Scene Photo</span>
          {hasPhoto && (
            <span className="text-[10px] text-cyan-400 font-mono">Click to Zoom</span>
          )}
        </h4>

        {hasPhoto ? (
          <div
            onClick={() => setShowImageZoom(true)}
            className="relative rounded-xl overflow-hidden border border-slate-700/80 group cursor-pointer aspect-video bg-slate-950 flex items-center justify-center"
          >
            <img
              src={imageSrc}
              alt="Field Scene Capture"
              className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
            />
            <div className="absolute inset-0 bg-slate-950/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2 text-white text-xs font-mono">
              <ZoomIn className="w-5 h-5 text-cyan-400" /> Full Resolution Lightbox
            </div>
          </div>
        ) : (
          <div className="rounded-xl border border-dashed border-slate-800 p-6 text-center bg-slate-950/40 text-slate-500 text-xs">
            No photo capture attached to this field report.
          </div>
        )}
      </div>

      {/* Spoken Voice Note Audio Section */}
      <div>
        <h4 className="text-xs font-semibold text-slate-400 mb-2 uppercase tracking-wider flex items-center gap-2">
          <Mic className="w-3.5 h-3.5 text-purple-400" />
          <span>Spoken Field Voice Note</span>
        </h4>

        {audioTranscript ? (
          <div className="p-3.5 rounded-xl bg-purple-950/20 border border-purple-800/40 space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-xs font-semibold text-purple-300">
                <Volume2 className="w-4 h-4 text-purple-400" />
                <span>Audio Transcript Recognized</span>
              </div>
            </div>
            <p className="text-xs text-purple-200/90 italic font-sans leading-relaxed">
              "{audioTranscript}"
            </p>
          </div>
        ) : (
          <div className="rounded-xl border border-dashed border-slate-800 p-4 text-center bg-slate-950/40 text-slate-500 text-xs">
            No spoken voice note attached.
          </div>
        )}
      </div>

      {/* Lightbox Modal */}
      {showImageZoom && hasPhoto && (
        <div className="fixed inset-0 z-50 bg-slate-950/90 backdrop-blur-md flex items-center justify-center p-4">
          <div className="relative max-w-4xl max-h-[90vh] glass-panel p-2">
            <button
              onClick={() => setShowImageZoom(false)}
              className="absolute top-4 right-4 p-2 rounded-full bg-slate-900/80 border border-slate-700 text-white hover:text-cyan-400"
            >
              <X className="w-5 h-5" />
            </button>
            <img
              src={imageSrc}
              alt="High Res Field Scene"
              className="max-h-[85vh] w-auto object-contain rounded-lg"
            />
          </div>
        </div>
      )}
    </div>
  );
}
