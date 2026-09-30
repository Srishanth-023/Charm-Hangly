import React, { useEffect, useState, useRef } from 'react';
import './HeartEffect.css';

const HeartEffect = () => {
  const [particles, setParticles] = useState([]);
  const idCounter = useRef(0);

  useEffect(() => {
    // Periodically spawn brewing hearts
    const interval = setInterval(() => {
      const spawnCount = Math.floor(Math.random() * 2) + 2; // 2 or 3 hearts
      
      for (let i = 0; i < spawnCount; i++) {
        setTimeout(() => {
          const id = idCounter.current++;
          // Space them out horizontally around the center
          const offset = (Math.random() - 0.5) * 50; // more spread
          const newParticle = { id, left: 50 + offset };
          
          setParticles(p => [...p, newParticle]);
          
          // Remove after animation (0.8s float + 0.6s splash = 1.4s total)
          setTimeout(() => {
            setParticles(p => p.filter(x => x.id !== id));
          }, 1400);
        }, i * 350); // 350ms stagger for more vertical spacing
      }
    }, 2000); // spawn every 2 seconds

    return () => clearInterval(interval);
  }, []);

  return (
    <span className="heart-effect-container">
      <span className="heart">&lt;3</span>
      {particles.map(p => (
        <span key={p.id} className="brewing-heart" style={{ left: `${p.left}%` }}>
          <i className="fa-solid fa-heart inner-heart"></i>
          <span className="splash-stain"></span>
        </span>
      ))}
    </span>
  );
};

export default HeartEffect;
