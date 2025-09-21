import { createMemo } from 'solid-js';

export default function CircleGauge(props) {
  // Defaults + reactive accessors
  const size = () => props.size ?? 36;
  const thickness = () => props.thickness ?? 4;
  const color = () => props.color ?? '#34d399';
  const track = () => props.track ?? 'rgba(55,65,81,0.6)';
  const showText = () => props.showText ?? true;
  const textColor = () => props.textColor ?? '#e5e7eb';

  // Reactive geometry and value
  const clamped = () => Math.max(0, Math.min(100, props.value ?? 0));
  const radius = () => (size() - thickness()) / 2;
  const circumference = createMemo(() => 2 * Math.PI * radius());
  const offset = createMemo(() => circumference() * (1 - clamped() / 100));
  const fontSize = () => Math.round(size() * 0.32);

  return (
    <svg width={size()} height={size()} viewBox={`0 0 ${size()} ${size()}`} class="block">
      <circle
        cx={size() / 2}
        cy={size() / 2}
        r={radius()}
        fill="transparent"
        stroke={track()}
        stroke-width={thickness()}
      />
      <circle
        cx={size() / 2}
        cy={size() / 2}
        r={radius()}
        fill="transparent"
        stroke={color()}
        stroke-width={thickness()}
        stroke-linecap="round"
        stroke-dasharray={`${circumference()} ${circumference()}`}
        stroke-dashoffset={offset()}
        style={{ transform: 'rotate(-90deg)', transformOrigin: '50% 50%' }}
      />
      {showText() && (
        <text
          x="50%"
          y="50%"
          fill={textColor()}
          font-size={fontSize()}
          font-weight="600"
          text-anchor="middle"
          dominant-baseline="central"
        >
          {Math.round(clamped())}%
        </text>
      )}
    </svg>
  );
}
