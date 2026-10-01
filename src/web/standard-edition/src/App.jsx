import React, { useEffect, useRef, useState } from 'react';
import './index.css';
import Sparkles from './Sparkles';
import HeartEffect from './HeartEffect';

function App() {
  const heroRef = useRef(null);
  const [isDarkMode, setIsDarkMode] = useState(false);

  useEffect(() => {
    if (isDarkMode) {
      document.body.setAttribute('data-theme', 'dark');
    } else {
      document.body.removeAttribute('data-theme');
    }
  }, [isDarkMode]);

  useEffect(() => {
    const hero = heroRef.current;
    if (!hero) return;

    const handleMouseMove = (e) => {
      const { clientX, clientY } = e;
      const xPos = (clientX / window.innerWidth - 0.5) * 20;
      const yPos = (clientY / window.innerHeight - 0.5) * 20;
      
      hero.style.backgroundPosition = `calc(50% + ${xPos}px) calc(50% + ${yPos}px)`;
    };

    const handleMouseLeave = () => {
      hero.style.backgroundPosition = 'center';
    };

    hero.addEventListener('mousemove', handleMouseMove);
    hero.addEventListener('mouseleave', handleMouseLeave);

    return () => {
      if (hero) {
        hero.removeEventListener('mousemove', handleMouseMove);
        hero.removeEventListener('mouseleave', handleMouseLeave);
      }
    };
  }, []);

  return (
    <>
      <Sparkles />
      <div className="decorative-line top"></div>
      
      <nav className="navbar">
        <div 
          className="logo" 
          onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })} 
          style={{ cursor: 'pointer' }}
          title="Go to Top"
        >
          CHARM HANGLY
        </div>

        <div className="hanging-charm-container">
          <div className="golden-chain"></div>
          <img src="/nazar.svg" alt="Nazar Charm" className="nazar-svg" />
        </div>

        <button 
          className="theme-toggle" 
          onClick={() => setIsDarkMode(!isDarkMode)}
          aria-label="Toggle Dark Mode"
        >
          {isDarkMode ? <i className="fa-solid fa-sun"></i> : <i className="fa-solid fa-moon"></i>}
        </button>
      </nav>

      <header className="hero" id="home" ref={heroRef}>
        <div className="hero-container">
          <div className="hero-content">
            <h1 className="hero-title">Experience the Magic of <br className="mobile-break" /><span>Charm Hangly</span></h1>
            <p className="hero-subtitle">
              A realistic charm that elegantly hangs and swings from a rope on your screen. Add a touch of beauty and fortune to your device.
            </p>
            <div className="hero-actions">
              <a href="#downloads" className="btn btn-primary">
                Download Now
              </a>
            </div>
          </div>
          <div className="hero-image">
            <img src="/hangly-desktop.png" alt="Charm Hangly in action" className="floating-preview" />
          </div>
        </div>
        <a href="#downloads" className="scroll-indicator" aria-label="Scroll Down">
          <i className="fa-solid fa-chevron-down"></i>
        </a>
      </header>

      <section className="downloads" id="downloads">
        <div className="section-header">
          <h2>Get Charm Hangly</h2>
          <div className="section-divider"></div>
          <p>Available for both mobile devices and desktop computers.</p>
        </div>

        <div className="cards-container">
          {/* Mobile Card */}
          <div className="download-card" id="card-mobile">
            <div className="card-border"></div>
            <div className="card-content">
              <i className="fa-solid fa-mobile-screen-button card-icon"></i>
              <h3>Mobile Edition</h3>
              <p>Charm Hangly lives on top of your apps, swinging naturally as you move your phone. Includes custom charm studio and 70+ built-in charms.</p>
              <ul className="card-features">
                <li><i className="fa-solid fa-check"></i> Interactive Physics</li>
                <li><i className="fa-solid fa-check"></i> Custom Charms</li>
                <li><i className="fa-solid fa-check"></i> Haptic Feedback</li>
              </ul>
              <a href="https://github.com/Srishanth-023/Charm-Hangly/releases/download/Polished-Update/CharmHangly-Mobile-release-v1.4.0.apk" className="btn btn-card" download>
                <i className="fa-brands fa-android"></i> Download for Android
              </a>
              <span className="version-tag">Version 1.4.0</span>
            </div>
          </div>

          {/* Desktop Card */}
          <div className="download-card" id="card-desktop">
            <div className="card-border"></div>
            <div className="card-content">
              <i className="fa-solid fa-desktop card-icon"></i>
              <h3>Desktop Edition</h3>
              <p>A beautiful native Windows application that hangs charms gracefully over your desktop workspace. Built with modern WinUI 3.</p>
              <ul className="card-features">
                <li><i className="fa-solid fa-check"></i> x64 & ARM64 Support</li>
                <li><i className="fa-solid fa-check"></i> Multi-charm Strings</li>
                <li><i className="fa-solid fa-check"></i> Low Resource Usage</li>
              </ul>
              <div className="desktop-downloads">
                <a href="https://github.com/Srishanth-023/Charm-Hangly/releases/download/Polished-Update/CharmHangly-Setup-x64-v1.6.0.exe" className="btn btn-card small" download>
                  <i className="fa-brands fa-windows"></i> x64
                </a>
                <a href="https://github.com/Srishanth-023/Charm-Hangly/releases/download/Polished-Update/CharmHangly-Setup-arm64-v1.6.0.exe" className="btn btn-card small" download>
                  <i className="fa-brands fa-windows"></i> ARM64
                </a>
              </div>
              <span className="version-tag">Windows 10 / 11</span>
            </div>
          </div>
        </div>
      </section>

      <footer className="footer">
        <div className="decorative-line bottom"></div>
        <div className="footer-content">
          <div className="footer-logo">CHARM HANGLY</div>
          
          <div className="social-links">
            <a href="https://github.com/Srishanth-023/Charm-Hangly" target="_blank" rel="noopener noreferrer" aria-label="GitHub">
              <i className="fa-brands fa-github"></i>
            </a>
            <a href="https://www.instagram.com/sri.23._/" target="_blank" rel="noopener noreferrer" aria-label="Instagram">
              <i className="fa-brands fa-instagram"></i>
            </a>
            <a href="https://www.linkedin.com/in/sri-shanth-0520a9315/" target="_blank" rel="noopener noreferrer" aria-label="LinkedIn">
              <i className="fa-brands fa-linkedin"></i>
            </a>
            <a href="mailto:srishanth232007@gmail.com" aria-label="Email">
              <i className="fa-solid fa-envelope"></i>
            </a>
          </div>

          <p>&copy; 2026 Charm Hangly. Crafted with elegance.</p>
          <p className="created-by">Created by Sri <HeartEffect /> !!</p>
        </div>
      </footer>
    </>
  );
}

export default App;
