import React, { useEffect, useMemo, useRef } from 'react';
import confetti from 'canvas-confetti';
import './index.css';

const YELLOW_COLORS = ['#F4A825', '#FFD873', '#ffffff'];
const GLITTER_COUNT = 45;

function popConfetti(originX) {
  confetti({
    particleCount: 45,
    angle: originX === 0 ? 60 : 120,
    spread: 60,
    origin: { x: originX, y: 0.6 },
    colors: YELLOW_COLORS,
  });
}

function useParallax() {
  const blobRefs = useRef([]);

  useEffect(() => {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) return;

    let ticking = false;

    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        const y = window.scrollY;
        blobRefs.current.forEach((el) => {
          if (!el) return;
          const speed = Number(el.dataset.speed || 0.2);
          el.style.transform = `translateY(${y * speed}px)`;
        });
        ticking = false;
      });
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return blobRefs;
}

function useGlitterDots() {
  return useMemo(
    () =>
      Array.from({ length: GLITTER_COUNT }, () => ({
        left: Math.random() * 100,
        top: Math.random() * 100,
        size: 2 + Math.random() * 3,
        delay: Math.random() * 4,
        duration: 2.5 + Math.random() * 2.5,
      })),
    []
  );
}

function useReveal() {
  useEffect(() => {
    const els = document.querySelectorAll('.reveal');
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('in-view');
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.2 }
    );
    els.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, []);
}

function App() {
  const blobRefs = useParallax();
  const glitterDots = useGlitterDots();
  useReveal();

  useEffect(() => {
    const timer = setTimeout(() => {
      popConfetti(0);
      popConfetti(1);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  return (
    <>
      <div className="glitter-layer" aria-hidden="true">
        {glitterDots.map((dot, i) => (
          <span
            key={i}
            className="glitter-dot"
            style={{
              left: `${dot.left}%`,
              top: `${dot.top}%`,
              width: dot.size,
              height: dot.size,
              animationDelay: `${dot.delay}s`,
              animationDuration: `${dot.duration}s`,
            }}
          />
        ))}
      </div>

      <nav className="navbar">
        <div className="logo">Charm <span>Hangly</span></div>
      </nav>

      <header className="hero" id="home">
        <div className="hero-blob b1" ref={(el) => (blobRefs.current[0] = el)} data-speed="0.15"></div>
        <div className="hero-blob b2" ref={(el) => (blobRefs.current[1] = el)} data-speed="0.3"></div>
        <div className="hero-blob b3" ref={(el) => (blobRefs.current[2] = el)} data-speed="0.22"></div>

        <div className="hero-content">
          <h1 className="hero-title">
            <span className="happy">Happy Birthday,</span>{' '}
            <span className="name">Nene!!</span>
          </h1>

          <div className="nene-image-wrapper">
            <div className="nene-glow"></div>
            <img src="/nene-img.png" alt="NeNe" />
          </div>

          <i className="fa-solid fa-chevron-down scroll-indicator"></i>
        </div>
      </header>

      <section className="message-section reveal">
        <div className="message-card">
          <p>
            Another year, more reasons to celebrate you. Hope today brings you as much joy,
            laughter and sunshine as you bring to everyone around you. Here's a little gift, just for you <i className="fa-solid fa-gift inline-icon"></i>
          </p>
        </div>
      </section>

      <section className="downloads reveal" id="downloads">
        <div className="section-header">
          <h2>Your Birthday Gift</h2>
          <p>A charm that hangs on your screen, made with you in mind.</p>
        </div>

        <div className="cards-container">
          <div className="download-card">
            <i className="fa-solid fa-mobile-screen-button card-icon"></i>
            <h3>Mobile Edition</h3>
            <p>Charm Hangly lives on top of your apps, swinging naturally as you move your phone. Includes custom charm studio and 70+ built-in charms.</p>
            <ul className="card-features">
              <li><i className="fa-solid fa-check"></i> Interactive Physics</li>
              <li><i className="fa-solid fa-check"></i> Custom Charms</li>
              <li><i className="fa-solid fa-check"></i> Haptic Feedback</li>
            </ul>
            <a href="https://github.com/Srishanth-023/Charm-Hangly/releases/download/v1.2.0_Mobile_B'day_Version/CharmHangly-Mobile-release-v1.2.0.apk" className="btn-card" download>
              <i className="fa-brands fa-android"></i> Download for Android
            </a>
            <span className="version-tag">Version 1.2.0</span>
          </div>

          <div className="download-card">
            <i className="fa-solid fa-desktop card-icon"></i>
            <h3>Desktop Edition</h3>
            <p>A beautiful native Windows application that hangs charms gracefully over your desktop workspace. Built with modern WinUI 3.</p>
            <ul className="card-features">
              <li><i className="fa-solid fa-check"></i> x64 Support</li>
              <li><i className="fa-solid fa-check"></i> Multi-charm Strings</li>
              <li><i className="fa-solid fa-check"></i> Low Resource Usage</li>
            </ul>
            <a href="https://github.com/Srishanth-023/Charm-Hangly/releases/download/v1.1.0(Desktop)_v1.0.0(Mobile)/CharmHangly-Setup-x64-v1.1.0.exe" className="btn-card" download>
              <i className="fa-brands fa-windows"></i> Download for Windows
            </a>
            <span className="version-tag">Windows 10 / 11</span>
          </div>
        </div>
      </section>

      <footer className="footer">
        <div className="footer-logo">Charm <span>Hangly</span></div>
        <p>&copy; 2026 Charm Hangly.</p>
        <p className="footer-credits">Made by Sri &lt;3 !!</p>
      </footer>
    </>
  );
}

export default App;
