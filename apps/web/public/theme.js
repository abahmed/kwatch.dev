/* Theme choice: System (default), Light or Dark. Loaded in <head> without
   defer so data-theme is set before first paint. Stored in localStorage under
   "kwatch-theme"; System stores nothing. */
(function () {
  var KEY = 'kwatch-theme';
  var root = document.documentElement;
  var order = ['system', 'light', 'dark'];
  function read() {
    try {
      var v = localStorage.getItem(KEY);
      return v === 'light' || v === 'dark' ? v : 'system';
    } catch (e) { return 'system'; }
  }
  function apply(mode) {
    if (mode === 'system') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', mode);
    root.setAttribute('data-theme-mode', mode);
    var b = document.querySelectorAll('[data-theme-toggle]');
    var label = { system: 'System', light: 'Light', dark: 'Dark' }[mode];
    for (var i = 0; i < b.length; i++) {
      b[i].setAttribute('aria-label', 'Theme: ' + label + '. Change theme');
      b[i].setAttribute('title', 'Theme: ' + label);
    }
  }
  apply(read());
  document.addEventListener('DOMContentLoaded', function () { apply(read()); });
  document.addEventListener('click', function (e) {
    var t = e.target.closest && e.target.closest('[data-theme-toggle]');
    if (!t) return;
    var next = order[(order.indexOf(read()) + 1) % order.length];
    try {
      if (next === 'system') localStorage.removeItem(KEY);
      else localStorage.setItem(KEY, next);
    } catch (err) {}
    apply(next);
  });
  window.addEventListener('storage', function (e) { if (e.key === KEY) apply(read()); });
})();
