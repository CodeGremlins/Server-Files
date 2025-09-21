let active = false;
let state = null;
let pins = [];
let timerInterval = null;

function reset() {
	pins = [];
	state = null;
	active = false;
	if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
	document.getElementById('pins').innerHTML = '';
	document.getElementById('status').className = 'status';
	document.getElementById('status').textContent = 'Press SPACE inside green zones';
	document.getElementById('timer').classList.add('hidden');
}

function closeUI(sendCancel=true) {
	document.getElementById('app').classList.add('hidden');
	active = false;
	if (sendCancel) fetch(`https://${GetParentResourceName()}/lockpick:close`, {method:'POST', body:'{}'});
	reset();
}

function complete(success) {
	document.getElementById('status').className = 'status ' + (success ? 'good':'bad');
	document.getElementById('status').textContent = success ? 'Unlocked!' : 'Failed';
	setTimeout(()=>{
		fetch(`https://${GetParentResourceName()}/lockpick:result`, {method:'POST', body: JSON.stringify({ success })});
		closeUI(false);
	}, 550);
}

function buildPins(cfg) {
	const wrap = document.getElementById('pins');
	for (let i=0;i<cfg.pins;i++) {
		const el = document.createElement('div');
		el.className='pin';
		el.dataset.index = i;
		el.innerHTML = `<div class="pin-label">PIN ${i+1}</div><div class="track"></div><div class="attempts"></div>`;
		wrap.appendChild(el);

		const track = el.querySelector('.track');
		const zone = document.createElement('div');
		zone.className='zone';
		// random zone vertical position (keep inside track with margin)
		const trackHeight =  track.clientHeight || 180;
		const zHeight = 48;
		const maxTop = trackHeight - zHeight - 4;
		zone.style.top = Math.floor(Math.random()*maxTop)+ 'px';
		track.appendChild(zone);

		const marker = document.createElement('div');
		marker.className='marker';
		track.appendChild(marker);

		pins.push({ el, track, zone, marker, attempts: cfg.attemptsPerPin, cleared:false, y:2, dir:1 + (Math.random()>0.5?0:-0.2) });
	}
	updateAttempts();
}

function updateAttempts(){
	pins.forEach(p=>{
		p.el.querySelector('.attempts').textContent = 'x' + p.attempts;
	});
}

function tick() {
	if (!active) return;
	const speed = state.speed;
	pins.forEach(p=>{
		if (p.cleared) return;
		const trackHeight = p.track.clientHeight - 16 - 6; // marker height + margin
		p.y += (p.dir * speed * 2);
		if (p.y <= 2) { p.y = 2; p.dir = Math.abs(p.dir); }
		else if (p.y >= trackHeight) { p.y = trackHeight; p.dir = -Math.abs(p.dir); }
		p.marker.style.top = p.y + 'px';
	});
	requestAnimationFrame(tick);
}

function spacePress() {
	if (!active) return;
	// find first uncleared pin
	const pin = pins.find(p=>!p.cleared);
	if (!pin) return;
	const mTop = pin.y;
	const zTop = parseFloat(pin.zone.style.top);
	const zHeight = pin.zone.clientHeight;
	const within = mTop + 8 >= zTop && (mTop+8) <= (zTop + zHeight);
	if (within) {
		pin.cleared = true;
		pin.el.classList.remove('fail');
		pin.el.classList.add('success');
		document.getElementById('status').className='status good';
		document.getElementById('status').textContent='Good!';
		// next zone: just highlight next
		if (pins.every(p=>p.cleared)) {
			complete(true);
		}
	} else {
		pin.attempts -= 1;
		pin.el.classList.add('fail');
		document.getElementById('status').className='status bad';
		document.getElementById('status').textContent='Miss!';
		if (pin.attempts <= 0) {
			if (state.failFast) {
				complete(false); return;
			}
		}
		updateAttempts();
	}
}

function startTimer(limit) {
	if (!limit || limit <= 0) return;
	const timerEl = document.getElementById('timer');
	timerEl.classList.remove('hidden');
	const end = performance.now() + limit;
	timerInterval = setInterval(()=>{
		const remain = end - performance.now();
		if (remain <= 0) {
			clearInterval(timerInterval); timerInterval=null; complete(false);
		} else {
			timerEl.textContent = (remain/1000).toFixed(1);
		}
	}, 80);
}

window.addEventListener('message', (e)=>{
	const d = e.data;
	if (d.action === 'open') {
		reset();
		active = true;
		state = {
			tier: d.tier,
			pins: d.pins,
			window: d.window,
			speed: d.speed,
			attemptsPerPin: d.attemptsPerPin,
			failBreakModifier: d.failBreakModifier,
			globalTimeLimit: d.globalTimeLimit,
			failFast: d.failFast !== undefined ? d.failFast : true,
		};
		document.documentElement.style.setProperty('--bg', d.theme?.bg || 'rgba(15,15,18,0.9)');
		document.getElementById('tierLabel').textContent = 'Tier: ' + d.tier.toUpperCase();
		document.getElementById('app').classList.remove('hidden');
		buildPins(state);
		requestAnimationFrame(tick);
		startTimer(state.globalTimeLimit);
	}
});

document.addEventListener('keydown', (e)=>{
	if (!active) return;
	if (e.code === 'Space') {
		e.preventDefault();
		spacePress();
	} else if (e.code === 'Escape') {
		closeUI();
	}
});

document.getElementById('closeBtn').addEventListener('click', ()=> closeUI());

// Prevent scroll etc.
window.addEventListener('wheel', e=>{ if(active) e.preventDefault(); }, { passive:false });
