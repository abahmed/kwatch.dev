// Sets data-theme before first paint so a saved choice never flashes.
try {
  var t = localStorage.getItem('kwatch-theme');
  if (t === 'light' || t === 'dark') document.documentElement.setAttribute('data-theme', t);
} catch (e) {}
