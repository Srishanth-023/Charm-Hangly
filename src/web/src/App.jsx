import React, { useEffect } from 'react';
import confetti from 'canvas-confetti';
import './index.css';

function App() {
  useEffect(() => {
    // Fire confetti popping animation
    const duration = 4000;
    const end = Date.now() + duration;

    const frame = () => {
      confetti({
        particleCount: 7,
        angle: 60,
        spread: 60,
        origin: { x: 0 },
        colors: ['#FDE047', '#EAB308', '#ffffff']
      });
      confetti({
        particleCount: 7,
        angle: 120,
        spread: 60,
        origin: { x: 1 },
        colors: ['#FDE047', '#EAB308', '#ffffff']
      });

      if (Date.now() < end) {
        requestAnimationFrame(frame);
      }
    };
    frame();
  }, []);

  return (
    <div className="parallax-wrapper">
      <nav className="navbar">
        <div className="logo">CHARM <span>HANGLY</span></div>
      </nav>

      <div className="parallax-group">
        <div className="hero">
          <div className="hero-background"></div>
          <div className="hero-content">
            <div className="birthday-badge">Wishing You A</div>
            <h1 className="hero-title">
              <span className="happy">Happy</span>
              <span className="birthday">Birthday</span>
              <span>NeNe! 🎂</span>
            </h1>
            <div className="nene-image-wrapper">
              <img src="/nene-img.png" alt="Happy Birthday NeNe" />
            </div>
            
            <i className="fa-solid fa-chevron-down scroll-indicator"></i>
          </div>
        </div>
      </div>

      <div className="main-content">
        <section className="downloads" id="downloads">
          <div className="section-header">
            <h2>Get Charm Hangly</h2>
            <p>Your special gift, available for mobile and desktop.</p>
          </div>

          <div className="cards-container">
            {/* Mobile Card */}
            <div className="download-card" id="card-mobile">
              <i className="fa-solid fa-mobile-screen-button card-icon"></i>
              <h3>Mobile Edition</h3>
              <p>Charm Hangly lives on top of your apps, swinging naturally as you move your phone. Includes custom charm studio and 70+ built-in charms.</p>
              <ul className="card-features">
                <li><i className="fa-solid fa-check"></i> Interactive Physics</li>
                <li><i className="fa-solid fa-check"></i> Custom Charms</li>
                <li><i className="fa-solid fa-check"></i> Haptic Feedback</li>
              </ul>
              <a href="https://github.com/Srishanth-023/Charm-Hangly/releases/download/v1.2.0_Mobile_B'day_Version/CharmHangly-Mobile-release-v1.2.0.apk" className="btn btn-card" download>
                <i className="fa-brands fa-android"></i> Download for Android
              </a>
              <span className="version-tag">Version 1.2.0</span>
            </div>

            {/* Desktop Card */}
            <div className="download-card" id="card-desktop">
              <i className="fa-solid fa-desktop card-icon"></i>
              <h3>Desktop Edition</h3>
              <p>A beautiful native Windows application that hangs charms gracefully over your desktop workspace. Built with modern WinUI 3.</p>
              <ul className="card-features">
                <li><i className="fa-solid fa-check"></i> x64 & ARM64 Support</li>
                <li><i className="fa-solid fa-check"></i> Multi-charm Strings</li>
                <li><i className="fa-solid fa-check"></i> Low Resource Usage</li>
              </ul>
              <div className="desktop-downloads">
                <a href="https://github.com/Srishanth-023/Charm-Hangly/releases/download/v1.1.0(Desktop)_v1.0.0(Mobile)/CharmHangly-Setup-x64-v1.1.0.exe" className="btn btn-card small" download>
                  <i className="fa-brands fa-windows"></i> x64
                </a>
                <a href="https://github.com/Srishanth-023/Charm-Hangly/releases/download/v1.1.0(Desktop)_v1.0.0(Mobile)/CharmHangly-Setup-arm64-v1.1.0.exe" className="btn btn-card small" download>
                  <i className="fa-brands fa-windows"></i> ARM64
                </a>
              </div>
              <span className="version-tag">Windows 10 / 11</span>
            </div>
          </div>
        </section>

        <footer className="footer">
          <div className="footer-content">
            <div className="footer-logo">CHARM <span>HANGLY</span></div>
            <p>&copy; 2026 Charm Hangly. Crafted with elegance.</p>
            <p className="footer-credits">Created by Sri &lt;3 !!</p>
          </div>
        </footer>
      </div>
    </div>
  );
}

export default App;
