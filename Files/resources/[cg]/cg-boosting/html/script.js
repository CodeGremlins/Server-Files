// Navigation functionality
document.addEventListener('DOMContentLoaded', function() {
    // Main navigation tabs
    const mainNavTabs = document.querySelectorAll('.nav-tab');
    const subNavTabs = document.querySelectorAll('.sub-nav-tab');
    const contentSections = document.querySelectorAll('.content-section');

    // Handle main navigation
    mainNavTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Remove active class from all main tabs
            mainNavTabs.forEach(t => t.classList.remove('active'));
            // Add active class to clicked tab
            this.classList.add('active');
            
            // For demo purposes, we'll just show the admin section
            // In a real app, you'd switch between different main sections
            console.log('Switched to:', this.dataset.tab);
        });
    });

    // Handle sub navigation
    subNavTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Remove active class from all sub tabs
            subNavTabs.forEach(t => t.classList.remove('active'));
            // Add active class to clicked tab
            this.classList.add('active');
            
            // Hide all content sections
            contentSections.forEach(section => section.classList.remove('active'));
            
            // Show corresponding content section
            const targetSection = document.getElementById(this.dataset.subtab + '-content');
            if (targetSection) {
                targetSection.classList.add('active');
            }
        });
    });

    // Header button interactions
    const headerButtons = document.querySelectorAll('.header-btn');
    headerButtons.forEach(btn => {
        btn.addEventListener('click', function() {
            const icon = this.querySelector('i');
            if (icon.classList.contains('fa-bell')) {
                console.log('Notifications clicked');
                // Add notification logic here
            } else if (icon.classList.contains('fa-cog')) {
                console.log('Settings clicked');
                // Add settings logic here
            } else if (icon.classList.contains('fa-power-off')) {
                console.log('Power/Logout clicked');
                // Add logout logic here
            }
        });
    });

    // Add some interactive animations
    const statCards = document.querySelectorAll('.stat-card');
    statCards.forEach(card => {
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-2px)';
        });
        
        card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0)';
        });
    });

    // Action items click handlers
    const actionItems = document.querySelectorAll('.action-item');
    actionItems.forEach(item => {
        item.addEventListener('click', function() {
            console.log('Action item clicked:', this.querySelector('.action-title').textContent);
            // Add action item details modal or navigation here
        });
    });

    // Booster items click handlers
    const boosterItems = document.querySelectorAll('.booster-item');
    boosterItems.forEach(item => {
        item.addEventListener('click', function() {
            const name = this.querySelector('.booster-name').textContent;
            console.log('Booster clicked:', name);
            // Add booster profile modal or navigation here
        });
    });

    // Update time every minute
    function updateTime() {
        const now = new Date();
        const timeString = now.toLocaleTimeString('en-US', { 
            hour: 'numeric', 
            minute: '2-digit',
            hour12: true 
        });
        document.querySelector('.time').textContent = timeString;
    }

    // Update time immediately and then every minute
    updateTime();
    setInterval(updateTime, 60000);

    // Add smooth scrolling for better UX
    document.documentElement.style.scrollBehavior = 'smooth';

    // Add keyboard navigation support
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Tab') {
            // Ensure tab navigation is visible
            document.body.classList.add('keyboard-navigation');
        }
    });

    document.addEventListener('mousedown', function() {
        document.body.classList.remove('keyboard-navigation');
    });

    // Add loading states for dynamic content
    function showLoadingState(element) {
        element.style.opacity = '0.6';
        element.style.pointerEvents = 'none';
    }

    function hideLoadingState(element) {
        element.style.opacity = '1';
        element.style.pointerEvents = 'auto';
    }

    // Simulate data updates (for demo purposes)
    function simulateDataUpdate() {
        const statValues = document.querySelectorAll('.stat-value');
        statValues.forEach(value => {
            const currentValue = parseInt(value.textContent.replace(/[^\d]/g, ''));
            if (!isNaN(currentValue)) {
                // Randomly increase or decrease by small amounts
                const change = Math.floor(Math.random() * 3) - 1; // -1, 0, or 1
                const newValue = Math.max(0, currentValue + change);
                
                if (value.textContent.includes('K')) {
                    value.textContent = (newValue / 1000).toFixed(1) + 'K';
                } else {
                    value.textContent = newValue.toString();
                }
            }
        });
    }

    // Update stats every 30 seconds (for demo)
    setInterval(simulateDataUpdate, 30000);

    // ------- Boosting Tablet Integration -------
    const appRoot = document.getElementById('boostingApp');
    const contractsListEl = document.getElementById('contractsList');
    const repAmountEl = document.getElementById('repAmount');
    const repProgressEl = document.getElementById('repProgress');
    const repTierEl = document.getElementById('repTier');
    const requestBtn = document.getElementById('requestContractBtn');
    const requestHint = document.getElementById('requestHint');
    const activeContainer = document.getElementById('activeContractContainer');
    const completeBtn = document.getElementById('completeBtn');
    const vinScratchBtn = document.getElementById('vinScratchBtn');
    const activeActions = document.getElementById('activeActions');
    const closeBtn = document.getElementById('closeBtn');
    const tierBar = document.getElementById('xpTierBar');
    const bannerContractText = document.getElementById('bannerContractText');
    const bannerMetaText = document.getElementById('bannerMetaText');

    let contractQueue = [];
    let activeContract = null;
    let countdownInterval = null;
    let tiersCache = [
        { name:'D', repRequired:0 },
        { name:'C', repRequired:200 },
        { name:'B', repRequired:500 },
        { name:'A', repRequired:1000 },
        { name:'S', repRequired:1800 }
    ];

    function postNui(action, data = {}, cb) {
        fetch(`https://cg-boosting/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        }).then(r => r.json().catch(()=>null)).then(resp => {
            if (cb) cb(resp);
        }).catch(err => console.error('NUI post error', action, err));
    }

    function openApp() {
        appRoot.style.display = 'block';
        document.body.classList.add('boosting-open');
        // default to contracts tab
        document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
        const contractsNav = Array.from(document.querySelectorAll('.nav-tab')).find(t => t.dataset.tab === 'contract-history') || null;
        if (contractsNav) contractsNav.classList.add('active');
        document.querySelectorAll('.sub-nav-tab').forEach(t => t.classList.remove('active'));
        const contractsSub = Array.from(document.querySelectorAll('.sub-nav-tab')).find(t => t.dataset.subtab === 'contracts');
        if (contractsSub) contractsSub.classList.add('active');
        document.querySelectorAll('.content-section').forEach(sec => sec.classList.remove('active'));
        document.getElementById('contracts-content').classList.add('active');
        fetchInitial();
    }

    function closeApp() {
        appRoot.style.display = 'none';
        document.body.classList.remove('boosting-open');
        clearCountdown();
        activeContract = null;
    }

    function fetchInitial() {
        postNui('fetchReputation', {}, data => updateReputation(data));
        postNui('fetchContracts', {}, data => updateContracts(data || []));
    }

    function updateReputation(data) {
        if (!data) return;
        repAmountEl.textContent = data.rep || 0;
        // determine tier progress
        let currentTier = tiersCache[0];
        let nextTier = null;
        for (let i=0;i<tiersCache.length;i++) {
            if ((data.rep||0) >= tiersCache[i].repRequired) {
                currentTier = tiersCache[i];
                nextTier = tiersCache[i+1] || null;
            }
        }
        repTierEl.textContent = currentTier.name;
        if (!nextTier) {
            repProgressEl.style.width = '100%';
        } else {
            const span = nextTier.repRequired - currentTier.repRequired;
            const into = (data.rep||0) - currentTier.repRequired;
            repProgressEl.style.width = Math.min(100, (into/span)*100).toFixed(1) + '%';
        }

        // Highlight tiers in bar
        if (tierBar) {
            const chips = tierBar.querySelectorAll('.tier-chip');
            chips.forEach(chip => {
                chip.classList.remove('active','unlocked','locked');
                const tierName = chip.dataset.tier;
                const tierObj = tiersCache.find(t=>t.name===tierName);
                if (!tierObj) return;
                if ((data.rep||0) >= tierObj.repRequired) {
                    chip.classList.add('unlocked');
                } else {
                    chip.classList.add('locked');
                }
                if (tierName === currentTier.name) chip.classList.add('active');
            });
        }
    }

    function updateContracts(list) {
        contractQueue = list;
        renderContracts();
    }

    function renderContracts() {
        if (!contractQueue || contractQueue.length === 0) {
            contractsListEl.classList.add('empty');
            contractsListEl.innerHTML = 'No queued contracts';
            return;
        }
        contractsListEl.classList.remove('empty');
        contractsListEl.innerHTML = contractQueue.map(c => {
            return `<div class="contract-item tier-${c.tier}">
                <div class="contract-left">
                    <div class="contract-tier">${c.tier}</div>
                    <div class="contract-model">${c.model.toUpperCase()}</div>
                    <div class="contract-meta">$${c.payout} | ${c.repGain} RP ${c.vinScratch==1?'| VIN':''}</div>
                </div>
                <div class="contract-actions">
                    <button class="small-btn accept" data-id="${c.id}">Accept</button>
                    <button class="small-btn decline" data-id="${c.id}">Decline</button>
                </div>
            </div>`;
        }).join('');
        // bind buttons
        contractsListEl.querySelectorAll('.accept').forEach(btn => btn.addEventListener('click', e => {
            postNui('acceptContract', { id: btn.dataset.id });
        }));
        contractsListEl.querySelectorAll('.decline').forEach(btn => btn.addEventListener('click', e => {
            postNui('declineContract', { id: btn.dataset.id });
        }));
    }

    function setActiveContract(c) {
        activeContract = c;
        clearCountdown();
        if (!c) {
            activeContainer.classList.add('empty');
            activeContainer.innerHTML = 'No active contract';
            activeActions.style.display = 'none';
            if (bannerContractText) bannerContractText.textContent = 'None';
            if (bannerMetaText) bannerMetaText.textContent = 'No active contract';
            return;
        }
        activeContainer.classList.remove('empty');
        activeActions.style.display = 'flex';
        vinScratchBtn.style.display = c.vinScratch == 1 ? 'inline-block' : 'none';
        activeContainer.innerHTML = `<div class="active-row"><span class="tag tier-${c.tier}">${c.tier}</span> <strong>${c.model.toUpperCase()}</strong></div>
            <div class="active-line">Payout: $${c.payout} | Rep: +${c.repGain}</div>
            <div class="active-line">Tracker: ${c.tracker ? 'Yes':'No'}</div>
            <div class="active-line">Time Left: <span id="timeLeft">--:--</span></div>`;
        if (bannerContractText) bannerContractText.textContent = `${c.model.toUpperCase()} (${c.tier} Class)`;
        if (bannerMetaText) bannerMetaText.textContent = `Reward: $${c.payout} • +${c.repGain} RP`;
        startCountdown();
    }

    function startCountdown() {
        if (!activeContract || !activeContract.expires) return;
        function tick() {
            const left = Math.max(0, activeContract.expires - Math.floor(Date.now()/1000));
            const m = Math.floor(left/60).toString().padStart(2,'0');
            const s = (left%60).toString().padStart(2,'0');
            const el = document.getElementById('timeLeft');
            if (el) el.textContent = `${m}:${s}`;
            if (left <= 0) clearCountdown();
        }
        tick();
        countdownInterval = setInterval(tick, 1000);
    }

    function clearCountdown() { if (countdownInterval) { clearInterval(countdownInterval); countdownInterval = null; } }

    // Button handlers
    requestBtn?.addEventListener('click', () => {
        postNui('requestContract');
        requestHint.textContent = 'Request sent...';
        setTimeout(()=>{ requestHint.textContent=''; }, 3000);
    });
    completeBtn?.addEventListener('click', () => postNui('completeDelivery'));
    vinScratchBtn?.addEventListener('click', () => postNui('vinScratch'));
    closeBtn?.addEventListener('click', () => {
        postNui('close');
        closeApp();
    });

    // Listen to messages from client Lua
    window.addEventListener('message', (event) => {
        const msg = event.data || {};
        switch (msg.action) {
            case 'open':
                openApp();
                break;
            case 'close':
                closeApp();
                break;
            case 'contracts':
                updateContracts(msg.data || []);
                break;
            case 'reputation':
                updateReputation(msg.data || {});
                break;
            case 'accepted':
                setActiveContract(msg.data);
                break;
        }
    });

    console.log('Boosting Tablet UI initialized.');
});