export default function TopRight({ hud }) {
  const money = () => hud?.moneys || { money: 0, bank: 0 };
  return (
    <div class="flex flex-col items-end gap-2 bg-black/40 px-4 py-2 rounded-md">
      <div class="text-sm text-gray-300">ID {hud?.playerId} • {hud?.onlinePlayers} online</div>
      <div class="text-lg font-semibold">${money().money?.toLocaleString?.() ?? money().money} <span class="text-amber-400">•</span> <span class="text-emerald-300">${money().bank?.toLocaleString?.() ?? money().bank}</span></div>
      <div class="text-xs text-gray-400">{hud?.job} {hud?.streetName && `• ${hud.streetName}`}</div>
    </div>
  );
}
