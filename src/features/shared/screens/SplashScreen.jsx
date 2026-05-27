import { useState, useEffect, useMemo } from 'react';
import { motion } from 'framer-motion';
import { AppColors } from '../../../core/constants/appColors';

function Particle({ delay }) {
  const config = useMemo(() => ({
    x: Math.random() * 100,
    size: 2 + Math.random() * 4,
    duration: 4 + Math.random() * 4,
    delay: delay + Math.random() * 3,
    waveAmp: 10 + Math.random() * 30,
  }), [delay]);

  return (
    <motion.div
      style={{
        position: 'absolute',
        left: `${config.x}%`,
        width: config.size,
        height: config.size,
        borderRadius: '50%',
        background: 'white',
        boxShadow: `0 0 ${config.size * 2}px rgba(255,255,255,0.4)`,
      }}
      initial={{ bottom: '-5%', opacity: 0 }}
      animate={{
        bottom: '105%',
        opacity: [0, 0.4, 0.3, 0],
        x: [0, config.waveAmp, -config.waveAmp, 0],
      }}
      transition={{
        duration: config.duration,
        delay: config.delay,
        repeat: Infinity,
        ease: 'linear',
      }}
    />
  );
}

export default function SplashScreen({ onComplete }) {
  const [show, setShow] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => {
      setShow(false);
      onComplete?.();
    }, 2500);
    return () => clearTimeout(timer);
  }, [onComplete]);

  if (!show) return null;

  return (
    <motion.div
      initial={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      style={{
        position: 'fixed', inset: 0, zIndex: 9999,
        background: `linear-gradient(to bottom, #0A1628 0%, #132B4C 30%, #1565C0 60%, #42A5F5 85%, #64B5F6 100%)`,
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        overflow: 'hidden',
      }}
    >
      {/* Background Radial Glow */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'radial-gradient(circle at center, rgba(66,165,245,0.15) 0%, transparent 60%)',
      }} />

      {/* Particles */}
      {Array.from({ length: 30 }, (_, i) => (
        <Particle key={i} delay={i * 0.15} />
      ))}

      {/* Logo Wrapper */}
      <motion.div
        initial={{ scale: 0.8, opacity: 0, y: 30 }}
        animate={{ scale: 1, opacity: 1, y: 0 }}
        transition={{ duration: 1, type: 'spring', bounce: 0.5 }}
        style={{ position: 'relative', zIndex: 1 }}
      >
        <motion.div
          animate={{ y: [-8, 8, -8] }}
          transition={{ duration: 4, repeat: Infinity, ease: 'easeInOut' }}
        >
          <div style={{
            width: 180, height: 180,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            position: 'relative',
          }}>
            <img
              src="/images/Logo.png"
              alt="VGo"
              style={{ width: '100%', height: '100%', objectFit: 'contain', filter: 'drop-shadow(0px 8px 16px rgba(0,0,0,0.2))' }}
            />
          </div>
        </motion.div>
      </motion.div>

      {/* Title */}
      <motion.h1
        initial={{ opacity: 0, y: 15 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.3, duration: 0.8, ease: 'easeOut' }}
        style={{
          fontSize: 64, fontWeight: 900,
          letterSpacing: 3, marginTop: 24,
          background: 'linear-gradient(to bottom, #FFFFFF 0%, #E3F2FD 100%)',
          WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
          textShadow: '0 8px 24px rgba(0,0,0,0.2)',
          position: 'relative', zIndex: 1,
          fontFamily: 'system-ui, -apple-system, sans-serif'
        }}
      >
        VGo
      </motion.h1>

      {/* Tagline */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.7, duration: 1 }}
        style={{
          color: 'rgba(255,255,255,0.9)', fontSize: 18,
          fontWeight: 500, letterSpacing: 1,
          marginTop: 8, position: 'relative', zIndex: 1,
          textShadow: '0 2px 8px rgba(0,0,0,0.2)',
        }}
      >
        Học mọi lúc, vui mọi nơi
      </motion.p>
    </motion.div>
  );
}
