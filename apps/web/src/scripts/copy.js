// Progressive enhancement: reveal Copy buttons. The command is always plain selectable text.
for (const group of document.querySelectorAll('[data-install]')) {
  const btn = group.querySelector('[data-copy]');
  const code = group.querySelector('code');
  const status = group.querySelector('[data-status]');
  if (!btn || !code) continue;
  btn.hidden = false;
  const canCopy = !!(navigator.clipboard && navigator.clipboard.writeText);
  if (!canCopy) btn.textContent = 'Select';
  let timer;
  btn.addEventListener('click', async () => {
    const text = code.textContent.trim();
    let done = false;
    if (canCopy) {
      try { await navigator.clipboard.writeText(text); done = true; } catch {}
    }
    if (!done) {
      const r = document.createRange();
      r.selectNodeContents(code);
      const s = getSelection();
      s.removeAllRanges();
      s.addRange(r);
    }
    const label = done ? 'Copied' : 'Selected';
    const idle = canCopy ? 'Copy' : 'Select';
    btn.textContent = label;
    if (status) status.textContent = done ? 'Command copied' : 'Command selected';
    clearTimeout(timer);
    timer = setTimeout(() => { btn.textContent = idle; if (status) status.textContent = ''; }, 2000);
  });
}
