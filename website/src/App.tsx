import React from 'react'
import Home from './pages/Home'

export default function App(): JSX.Element {
  return (
    <div className="app">
      <header className="site-header">
        <h1>AutomateHandbrake</h1>
        <p className="tagline">PowerShell helpers to rip DVDs with MakeMKV and encode with HandBrake.</p>
      </header>
      <main>
        <Home />
      </main>
      <footer className="site-footer">© AutomateHandbrake — Generated companion site</footer>
    </div>
  )
}
