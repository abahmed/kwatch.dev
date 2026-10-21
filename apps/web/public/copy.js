document.querySelectorAll('[data-copy]').forEach(function (b) {
  b.addEventListener('click', function () {
    var el = document.getElementById(b.getAttribute('data-copy'));
    var s = document.getElementById('copy-status');
    if (!el || !navigator.clipboard) return;
    navigator.clipboard.writeText(el.textContent.trim()).then(function () {
      if (s) s.textContent = 'Copied';
      b.textContent = 'Copied';
      setTimeout(function () { b.textContent = 'Copy'; if (s) s.textContent = ''; }, 2000);
    });
  });
});
