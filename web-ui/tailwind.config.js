/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        obsidian: {
          950: '#070709',
          900: '#0B0C10',
          850: '#0E0F14',
          800: '#151720',
          700: '#1E212E',
        },
        breach: {
          DEFAULT: '#FF3B30',
          crimson: '#E5484D',
          dark: '#7F1D1D',
        },
        cyber: {
          cyan: '#00E5FF',
          gold: '#F5A623',
          emerald: '#10B981',
          violet: '#A855F7',
        },
      },
      fontFamily: {
        sans: [
          'Inter',
          '-apple-system',
          'BlinkMacSystemFont',
          '"PingFang SC"',
          '"Microsoft YaHei"',
          'sans-serif',
        ],
        mono: [
          '"JetBrains Mono"',
          '"SF Mono"',
          'Menlo',
          'Monaco',
          'Consolas',
          'monospace',
        ],
      },
      boxShadow: {
        crimson: '0 0 24px -4px rgba(255, 59, 48, 0.45)',
        cyan: '0 0 24px -4px rgba(0, 229, 255, 0.4)',
        gold: '0 0 24px -4px rgba(245, 166, 35, 0.45)',
        violet: '0 0 24px -4px rgba(168, 85, 247, 0.4)',
      },
      animation: {
        'pulse-fast': 'pulse 1.1s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'scanline': 'scanline 6s linear infinite',
      },
      keyframes: {
        scanline: {
          '0%': { transform: 'translateY(-100%)' },
          '100%': { transform: 'translateY(400%)' },
        },
      },
    },
  },
  plugins: [],
};
