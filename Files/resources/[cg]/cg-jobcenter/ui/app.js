let currentJob = null;
const tablet = document.getElementById('tablet');
const list = document.getElementById('job-list');
const title = document.getElementById('job-title');
const motivation = document.getElementById('motivation');
const applyBtn = document.getElementById('apply-btn');
const closeBtn = document.getElementById('close-btn');
const statusLine = document.getElementById('status');

function setStatus(msg) {
  statusLine.textContent = msg || '';
}

function openTablet() {
  tablet.classList.remove('hidden');
  setStatus('Loading jobs...');
}
function closeTablet() {
  tablet.classList.add('hidden');
  currentJob = null;
  list.innerHTML='';
  title.textContent='Select a job';
  motivation.value='';
  applyBtn.disabled = true;
  setStatus('');
  fetch(`https://${GetParentResourceName()}/close`, {method:'POST', body:'{}'});
}

window.addEventListener('message', (e) => {
  const data = e.data;
  if (!data || !data.action) return;
  if (data.action === 'open') {
    openTablet();
  } else if (data.action === 'close') {
    closeTablet();
  } else if (data.action === 'jobs') {
    renderJobs(data.data || []);
    setStatus('');
  }
});

function renderJobs(jobs) {
  list.innerHTML='';
  if (!jobs.length) {
    const li = document.createElement('li');
  li.textContent = 'No jobs found';
    list.appendChild(li);
    return;
  }
  jobs.forEach(job => {
    const li = document.createElement('li');
    li.textContent = `${job.label} (${job.name})`;
    li.addEventListener('click', () => selectJob(job, li));
    list.appendChild(li);
  });
}

function selectJob(job, element) {
  currentJob = job;
  [...list.children].forEach(c => c.classList.remove('active'));
  element.classList.add('active');
  title.textContent = job.label + ' / ' + job.name;
  applyBtn.disabled = false;
  setStatus('Ready to apply.');
}

applyBtn.addEventListener('click', () => {
  if (!currentJob) return;
  setStatus('Submitting application...');
  fetch(`https://${GetParentResourceName()}/apply`, {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ job: currentJob.name, motivation: motivation.value })
  }).then(() => {
  setStatus('Application submitted.');
    motivation.value='';
  });
});

closeBtn.addEventListener('click', () => {
  closeTablet();
});

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeTablet();
    fetch(`https://${GetParentResourceName()}/escape`, {method:'POST', body:'{}'});
  }
});
