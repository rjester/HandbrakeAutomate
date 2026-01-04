import React from 'react'
import Home from './pages/Home'

export default function App(): JSX.Element {
  return (
    <div className="app">
      <nav className="main-nav">
        <div className="nav-container">
          <div className="nav-logo">AutomateHandbrake</div>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#docs">Docs</a>
            <a href="https://github.com/yourusername/AutomateHandbrake">GitHub</a>
          </div>
        </div>
      </nav>
      <header className="site-header">
        <h1>AutomateHandbrake</h1>
        <p className="tagline">The ultimate PowerShell companion for your physical media collection.</p>
      </header>
      <main>
        <Home />
      </main>
      <footer className="site-footer">
        <div className="footer-content">
          <p>© 2026 AutomateHandbrake. Built with React & Vite.</p>
          <div className="footer-links">
            <a href="#">Privacy</a>
            <a href="#">Terms</a>
            <a href="#">Contact</a>
          </div>
        </div>
      </footer>
    </div>
  )
}
