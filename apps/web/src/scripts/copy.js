// Progressive enhancement: reveal the copy icon. The command is always plain selectable text.
for (const group of document.querySelectorAll('[data-install]')) {
  const btn = group.querySelector('[data-copy]');
  const code = group.querySelector('code');
  const status = group.querySelector('[data-status]');
  if (!btn || !code) continue;
  btn.hidden = false;
  let timer;
  btn.addEventListener('click', async () => {
    let done = false;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      try { await navigator.clipboard.writeText(code.textContent.trim()); done = true; } catch {}
    }
    if (!done) {
      const r = document.createRange();
      r.selectNodeContents(code);
      const s = getSelection();
      s.removeAllRanges();
      s.addRange(r);
    }
    btn.classList.add('done');
    if (status) status.textContent = done ? 'Copied' : 'Command selected';
    clearTimeout(timer);
    timer = setTimeout(() => { btn.classList.remove('done'); if (status) status.textContent = ''; }, 2000);
  });
}
