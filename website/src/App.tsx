import React, { useEffect, useState } from 'react'
import Home from './pages/Home'
import { Sun, Moon } from 'lucide-react'

export default function App(): JSX.Element {
  const [isDark, setIsDark] = useState<boolean>(() => {
    try {
      const stored = localStorage.getItem('theme')
      if (stored) return stored === 'dark'
      return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
    } catch {
      return false
    }
  })

  useEffect(() => {
    const root = document.documentElement
    if (isDark) {
      root.classList.add('theme-dark')
      localStorage.setItem('theme', 'dark')
    } else {
      root.classList.remove('theme-dark')
      localStorage.setItem('theme', 'light')
    }
  }, [isDark])

  return (
    <div className="app">
      <nav className="main-nav">
        <div className="nav-container">
          <div className="nav-logo">Handbrake Automate</div>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#docs">Docs</a>
            <a href="https://github.com/rjester/HandbrakeAutomate">GitHub</a>
            <button
              aria-label="Toggle theme"
              className="theme-toggle"
              onClick={() => setIsDark((s) => !s)}
              title={isDark ? 'Switch to light' : 'Switch to dark'}
            >
              {isDark ? <Sun size={16} /> : <Moon size={16} />}
            </button>
          </div>
        </div>
      </nav>
      <header className="site-header">
        <h1>Handbrake Automate</h1>
        <p className="tagline">The ultimate PowerShell companion for your physical media collection.</p>
      </header>
      <main>
        <Home />
      </main>
      <footer className="site-footer">
        <div className="footer-content">
          <p>© 2026 Handbrake Automate. Built with React & Vite.</p>
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
