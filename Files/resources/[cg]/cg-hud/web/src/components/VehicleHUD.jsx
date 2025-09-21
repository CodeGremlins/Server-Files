export default function VehicleHUD({ data }) {
  const speedUnit = data?.kmh ? 'KMH' : 'MPH';
  return (
    <div class="flex items-center gap-4 bg-black/40 px-4 py-2 rounded-xl">
      <div class="text-4xl font-bold tracking-wider">
        {Math.round(data?.speed || 0)} <span class="text-sm text-gray-400">{speedUnit}</span>
      </div>
      <div class="flex items-center gap-2 text-sm">
        <div class="bg-gray-700/60 rounded-full h-2 w-28 overflow-hidden">
          <div class="h-full bg-amber-400 rounded-full" style={{ width: `${Math.min(100, Math.round((data?.fuel?.level || 0) / (data?.fuel?.maxLevel || 100) * 100))}%` }} />
        </div>
        <span class="text-gray-300">Fuel</span>
      </div>
      <div class="flex items-center gap-2 text-sm">
        <div class="bg-gray-700/60 rounded-full h-2 w-28 overflow-hidden">
          <div class="h-full bg-emerald-400 rounded-full" style={{ width: `${Math.min(100, data?.damage ?? 100)}%` }} />
        </div>
        <span class="text-gray-300">Cond.</span>
      </div>
    </div>
  );
}
