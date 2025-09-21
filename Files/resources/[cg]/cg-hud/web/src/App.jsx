import { createEffect, Show } from 'solid-js';
import { createStore } from 'solid-js/store';
import StatusRow from './components/StatusRow';
import VehicleHUD from './components/VehicleHUD';
import TopRight from './components/TopRight';
import VoiceIndicator from './components/Voice';
import './index.css';

function App() {
    const [state, setState] = createStore({
        show: false,
        status: {
            healthBar: 100,
            armorBar: 0,
            drinkBar: 100,
            foodBar: 100,
            oxygenBar: 100,
            staminaBar: 100,
        },
        hud: {
            playerId: 1,
            onlinePlayers: 1,
            moneys: { bank: 0, money: 0 },
            job: '',
            streetName: '',
            weaponData: { use: false, name: '', currentAmmo: 0, maxAmmo: 0, isWeaponMelee: false },
            voice: { mic: false, radio: false, range: 2 },
        },
        vehicle: {
            show: false,
            speed: 0,
            kmh: true,
            fuel: { level: 0, maxLevel: 100 },
            damage: 100,
            driver: false,
            rpm: 0,
        },
    });

    const open = () => (document.body.style.display = 'block');
    const close = () => (document.body.style.display = 'none');

    createEffect(() => {
        window.addEventListener('message', (event) => {
            const { type, value } = event.data || {};
            switch (type) {
                case 'SHOW':
                    if (value) open(); else close();
                    setState('show', !!value);
                    break;
                case 'STATUS_HUD':
                    setState('status', (prev) => ({ ...prev, ...(value || {}) }));
                    break;
                case 'HUD_DATA':
                    setState('hud', (prev) => ({ ...prev, ...(value || {}), moneys: { ...(value?.moneys || prev.moneys) } }));
                    break;
                case 'VEH_HUD':
                    setState('vehicle', (prev) => ({ ...prev, ...(value || {}) }));
                    break;
                case 'VOICE_RANGE':
                    setState('hud', 'voice', 'range', value);
                    break;
            }
        });
    });

    return (
        <div class="fixed inset-0 pointer-events-none select-none text-white">
            {/* Top-right only */}
            <div class="absolute top-6 right-6">
                <TopRight hud={state.hud} />
            </div>

            {/* Bottom area: left group (voice + statuses inline), right vehicle */}
            <div class="absolute bottom-3 left-6 right-6 flex items-end justify-between">
                <div class="flex items-end gap-4">
                    <VoiceIndicator voice={state.hud.voice} />
                    <div class="ml-1">
                        <StatusRow values={state.status} />
                    </div>
                </div>
                <Show when={state.vehicle?.show}>
                    <VehicleHUD data={state.vehicle} />
                </Show>
            </div>
        </div>
    );
}

export default App;

