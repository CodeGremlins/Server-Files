import CircleGauge from './CircleGauge';

export default function StatusRow({ values = {} }) {
  const Item = (props) => (
    <div class="flex flex-col items-center gap-1 bg-black/40 px-1.5 py-1.5 rounded-xl">
      <CircleGauge value={props.value} size={36} thickness={4} showText={true} />
      <div class="text-[10px] text-gray-300 capitalize">{props.label}</div>
    </div>
  );

  return (
    <div class="flex flex-wrap gap-1.5 items-center">
      <Item label="health" value={values.healthBar} />
      <Item label="armor" value={values.armorBar} />
      <Item label="hunger" value={values.foodBar} />
      <Item label="thirst" value={values.drinkBar} />
      <Item label="stamina" value={values.staminaBar} />
      <Item label="oxygen" value={values.oxygenBar} />
    </div>
  );
}
