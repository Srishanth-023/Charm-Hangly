import React, { useEffect, useRef } from 'react';
import './index.css';

function App() {
  const heroRef = useRef(null);

  useEffect(() => {
    const hero = heroRef.current;
    
    const handleMouseMove = (e) => {
      if (window.innerWidth > 768) {
        const x = e.clientX / window.innerWidth;
        const y = e.clientY / window.innerHeight;
        hero.style.background = `radial-gradient(circle at ${x * 100}% ${y * 100}%, var(--secondary-bg) 0%, var(--primary-bg) 100%)`;
      }
    };

    const handleMouseLeave = () => {
      if (window.innerWidth > 768) {
        hero.style.background = `radial-gradient(circle at center, var(--secondary-bg) 0%, var(--primary-bg) 100%)`;
      }
    };

    if (hero) {
      hero.addEventListener('mousemove', handleMouseMove);
      hero.addEventListener('mouseleave', handleMouseLeave);
    }

    return () => {
      if (hero) {
        hero.removeEventListener('mousemove', handleMouseMove);
        hero.removeEventListener('mouseleave', handleMouseLeave);
      }
    };
  }, []);

  return (
    <>
      <div className="decorative-line top"></div>
      
      <nav className="navbar">
        <div className="logo">CHARM HANGLY</div>
      </nav>

      <header className="hero" id="home" ref={heroRef}>
        <div className="hero-container">
          <div className="hero-content">
            <h1 className="hero-title">Experience the Magic of <br/><span>Charm Hangly</span></h1>
            <p className="hero-subtitle">
              A realistic charm that elegantly hangs and swings from a rope on your screen. Add a touch of beauty and fortune to your device.
            </p>
            <div className="hero-actions">
              <a href="#downloads" className="btn btn-primary">Download Now</a>
            </div>
          </div>
          <div className="hero-image">
            <img src="/hangly-desktop.png" alt="Charm Hangly in action" className="floating-preview" />
          </div>
        </div>
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
              <a href="/resources/CharmHangly-Mobile-release-v1.2.0.apk" className="btn btn-card" download>
                <i className="fa-brands fa-android"></i> Download for Android
              </a>
              <span className="version-tag">Version 1.2.0</span>
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
                <a href="/resources/CharmHangly-Setup-x64-v1.1.0.exe" className="btn btn-card small" download>
                  <i className="fa-brands fa-windows"></i> x64
                </a>
                <a href="/resources/CharmHangly-Setup-arm64-v1.1.0.exe" className="btn btn-card small" download>
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
          <p>&copy; 2026 Charm Hangly. Crafted with elegance.</p>
        </div>
      </footer>
    </>
  );
}

export default App;
