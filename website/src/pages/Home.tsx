import React from 'react'
import { Disc, Settings, Trash2, ExternalLink, BookOpen } from 'lucide-react'

const args = [
  ['PresetFile', 'string', `Default: %USERPROFILE%\\AppData\\Roaming\\HandBrake\\presets.json`],
  ['PresetName', 'string', 'Default: Fast 1080p30'],
  ['OutputPath', 'string', 'Default: $PWD\\output'],
  ['TempPath', 'string', 'Default: %TEMP%\\dvd_rip_temp'],
  ['OutputFormat', "'mp4'|'mkv'", "Default: 'mp4'"],
  ['MakeMKVPath', 'string', 'Optional explicit makemkvcon path'],
  ['HandBrakePath', 'string', 'Optional explicit HandBrakeCLI path'],
  ['KeepTemp', 'switch', 'Preserve temp MKV files when set'],
  ['VerboseLogs', 'switch', 'Enable verbose logging']
]

export default function Home(): JSX.Element {
  return (
    <div className="home-content">
      <section className="container hero-section">
        <h2>Streamline Your Media Library</h2>
        <p className="lead">
          AutomateHandbrake provides a powerful, scriptable interface for converting your physical media
          into high-quality digital files. Built on top of industry-standard tools like MakeMKV
          and HandBrake CLI.
        </p>

        <div className="quick-start-box">
          <div className="box-header">
            <span className="terminal-dots"></span>
            <span className="box-title">Quick Start</span>
          </div>
          <pre className="cmd">pwsh ./src/Invoke-DvdRip.ps1 -OutputPath C:\\Videos -PresetFile ./src/presets/DvdRip.json -PresetName "DvdRip Balanced" -OutputFormat mp4</pre>
        </div>
      </section>

      <section id="features" className="container features-grid">
        <div className="feature-card">
          <div className="feature-icon"><Disc size={36} /></div>
          <h3>Auto-Detection</h3>
          <p>Intelligently finds MakeMKV and HandBrake on your system, or accepts custom paths for portable setups.</p>
        </div>
        <div className="feature-card">
          <div className="feature-icon"><Settings size={36} /></div>
          <h3>Preset Support</h3>
          <p>Full support for HandBrake JSON presets, allowing you to maintain consistent quality across your entire collection.</p>
        </div>
        <div className="feature-card">
          <div className="feature-icon"><Trash2 size={36} /></div>
          <h3>Smart Cleanup</h3>
          <p>Automatically manages temporary files, with options to keep them for manual inspection when needed.</p>
        </div>
      </section>

      <section className="container args-section">
        <h3>Configuration Reference</h3>
        <p>Customize the behavior of <code>Invoke-DvdRip.ps1</code> using these parameters.</p>
        <div className="table-wrapper">
          <table className="args">
            <thead>
              <tr><th>Parameter</th><th>Type</th><th>Description</th></tr>
            </thead>
            <tbody>
              {args.map((a) => (
                <tr key={a[0]}>
                  <td><strong>{a[0]}</strong></td>
                  <td><span className="type-badge">{a[1]}</span></td>
                  <td>{a[2]}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="container info-section">
        <h3>Getting Started</h3>
        <p>
          Ensure you have the prerequisites installed and a DVD in your drive. 
          The script will guide you through title selection and handle the rest.
        </p>
        <div className="info-links">
          <a href="https://github.com/yourusername/AutomateHandbrake" className="btn btn-primary"><ExternalLink size={16} style={{marginRight:8}}/>View on GitHub</a>
          <a href="#docs" className="btn btn-secondary"><BookOpen size={14} style={{marginRight:8}}/>Read Documentation</a>
        </div>
      </section>
    </div>
  )
}
