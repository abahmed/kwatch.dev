// Runs in <head>, before paint: apply the stored theme choice (System by default).
(function () {
  var r = document.documentElement;
  try {
    var m = localStorage.getItem('kwatch-theme');
    if (m === 'light' || m === 'dark') r.setAttribute('data-theme', m);
  } catch (e) {}
})();
