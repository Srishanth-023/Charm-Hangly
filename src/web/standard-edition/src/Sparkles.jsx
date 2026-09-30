import React, { useEffect, useState } from 'react';
import './Sparkles.css';

const Sparkles = () => {
  const [sparkles, setSparkles] = useState([]);

  useEffect(() => {
    // Generate 40 random golden sparkles
    const newSparkles = Array.from({ length: 40 }).map((_, i) => ({
      id: i,
      size: Math.random() * 4 + 2, // 2px to 6px
      top: Math.random() * 100 + '%',
      left: Math.random() * 100 + '%',
      animationDuration: Math.random() * 4 + 3 + 's', // 3s to 7s
      animationDelay: Math.random() * 5 + 's', // 0s to 5s delay
    }));
    setSparkles(newSparkles);
  }, []);

  return (
    <div className="sparkles-container">
      {sparkles.map(s => (
        <div 
          key={s.id} 
          className="sparkle"
          style={{
            width: s.size + 'px',
            height: s.size + 'px',
            top: s.top,
            left: s.left,
            animationDuration: s.animationDuration,
            animationDelay: s.animationDelay
          }}
        />
      ))}
    </div>
  );
};

export default Sparkles;
