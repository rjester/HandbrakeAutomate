import React from 'react'

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
    <section className="container">
      <h2>Overview</h2>
      <p>
        AutomateHandbrake is a set of PowerShell scripts to rip a single DVD using MakeMKV
        and encode the result with HandBrake CLI. This site documents usage, arguments,
        and quick start instructions.
      </p>

      <h3>Quick Start</h3>
      <pre className="cmd">pwsh ./src/Invoke-DvdRip.ps1 -OutputPath C:\\Videos -PresetFile ./src/presets/DvdRip.json -PresetName "DvdRip Balanced" -OutputFormat mp4</pre>

      <h3>Invoke-DvdRip Arguments</h3>
      <table className="args">
        <thead>
          <tr><th>Name</th><th>Type</th><th>Description</th></tr>
        </thead>
        <tbody>
          {args.map((a) => (
            <tr key={a[0]}>
              <td><strong>{a[0]}</strong></td>
              <td>{a[1]}</td>
              <td>{a[2]}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <h3>Features</h3>
      <ul>
        <li>Auto-detects MakeMKV and HandBrake locations or accept explicit paths.</li>
        <li>Imports HandBrake presets and runs encodes with progress logging.</li>
        <li>Optionally preserves temporary MKV files for debugging.</li>
      </ul>

      <h3>More</h3>
      <p>See the repository README and the scripts under <em>src/</em> for details and examples.</p>
    </section>
  )
}
