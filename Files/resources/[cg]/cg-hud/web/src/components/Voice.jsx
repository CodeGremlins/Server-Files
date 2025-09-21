export default function VoiceIndicator({ voice }) {
  const bars = [1,2,3].map(n => n <= (voice?.range ?? 2));
  return (
    <div class="flex items-center gap-2 bg-black/40 px-3 py-2 rounded-xl">
      <div class={`${bars[0] ? 'bg-emerald-400' : 'bg-gray-600'} w-2 h-3 rounded-full`} />
      <div class={`${bars[1] ? 'bg-emerald-400' : 'bg-gray-600'} w-2 h-4 rounded-full`} />
      <div class={`${bars[2] ? 'bg-emerald-400' : 'bg-gray-600'} w-2 h-5 rounded-full`} />
      <div class={`ml-2 text-xs ${voice?.mic ? 'text-emerald-400' : 'text-gray-400'}`}>{voice?.mic ? 'Talking' : 'Muted'}</div>
    </div>
  );
}
