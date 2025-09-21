const app = document.getElementById('app');
const itemsEl = document.getElementById('items');
const detailsEl = document.getElementById('details');
const detailsEmpty = document.getElementById('detailsEmpty');
const dLabel = document.getElementById('dLabel');
const dStock = document.getElementById('dStock');
const dPrice = document.getElementById('dPrice');
const dLicense = document.getElementById('dLicense');
const qtyInput = document.getElementById('qty');
const buyBtn = document.getElementById('buyBtn');
const dIcon = document.getElementById('dIcon');
const closeBtn = document.getElementById('closeBtn');
let currentItem = null;

function setTime() {
  const now = new Date();
  document.getElementById('time').textContent = now.toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'});
}
setInterval(setTime, 1000); setTime();

function openUI(data) {
  app.classList.remove('hidden');
  document.body.style.pointerEvents = 'auto';
  buildItems(data.items || []);
}

function closeUI() {
  app.classList.add('hidden');
  fetch(`https://${GetParentResourceName()}/close`, {method:'POST'});
}

closeBtn.addEventListener('click', closeUI);
window.addEventListener('keydown', (e)=> { if(e.key === 'Escape') closeUI(); });

function buildItems(items) {
  itemsEl.innerHTML='';
  currentItem = null;
  detailsEl.classList.add('hidden');
  detailsEmpty.classList.remove('hidden');
  for(const item of items) {
    const card = document.createElement('div');
    card.className = 'item-card fade-in';
    if(item.amount <= 0) card.classList.add('out');
    else if(item.amount <= Math.max(1, Math.floor(item.max * 0.2))) card.classList.add('low');
    const giveBadge = item.give && item.give>1 ? `<span class="badge">x${item.give}</span>` : '';
    const iconPath = `nui://ox_inventory/web/images/${item.name}.png`;
    card.innerHTML = `${giveBadge}<div class="icon-wrap"><img src="${iconPath}" alt="${item.name}" onerror="this.style.display='none'"/></div><h4>${item.label || item.name}</h4><div class="price">$${item.price}</div><div class="stock">${item.amount}/${item.max}</div>`;
    card.addEventListener('click', () => selectItem(item));
    itemsEl.appendChild(card);
  }
}

function selectItem(item) {
  currentItem = item;
  detailsEmpty.classList.add('hidden');
  detailsEl.classList.remove('hidden');
  dLabel.textContent = item.label || item.name;
  dStock.textContent = `Stock: ${item.amount}/${item.max}`;
  let per = item.give && item.give>1 ? ` (x${item.give})` : '';
  dPrice.textContent = `Price: $${item.price}${per}`;
  const iconPath = `nui://ox_inventory/web/images/${item.name}.png`;
  dIcon.src = iconPath;
  dIcon.classList.remove('hidden');
  dIcon.onerror = function(){ this.classList.add('hidden'); };
  if(item.license) { dLicense.textContent = `Requires: ${item.license}`; dLicense.classList.remove('hidden'); }
  else dLicense.classList.add('hidden');
  qtyInput.value = 1;
  buyBtn.disabled = item.amount <= 0;
}

buyBtn.addEventListener('click', () => {
  if(!currentItem) return;
  let qty = parseInt(qtyInput.value) || 1;
  if(qty < 1) qty = 1;
  fetch(`https://${GetParentResourceName()}/buy`, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ name: currentItem.name, qty }) });
});

window.addEventListener('message', (e) => {
  const data = e.data;
  if(data.action === 'open') openUI(data);
  if(data.action === 'refresh') buildItems(data.items||[]);
  if(data.action === 'close') closeUI();
});

// Prevent scroll bubbling
window.addEventListener('wheel', e => { if(!app.classList.contains('hidden')) e.stopPropagation(); }, { passive:true });
