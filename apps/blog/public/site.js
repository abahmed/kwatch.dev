// Progressive enhancement: theme toggle, copy buttons, TOC highlight, search.
(function () {
  var root = document.documentElement;
  var status = document.getElementById('copy-status');

  // ---- Theme: System, Light, Dark ----
  var toggle = document.querySelector('[data-theme-toggle]');
  var modes = ['system', 'light', 'dark'];
  function current() {
    var t = root.getAttribute('data-theme');
    return t === 'light' || t === 'dark' ? t : 'system';
  }
  function paint() {
    if (!toggle) return;
    var m = current();
    toggle.setAttribute('data-mode', m);
    var label = m.charAt(0).toUpperCase() + m.slice(1);
    toggle.setAttribute('aria-label', 'Theme: ' + label + '. Change theme');
  }
  if (toggle) {
    paint();
    toggle.addEventListener('click', function () {
      var next = modes[(modes.indexOf(current()) + 1) % modes.length];
      if (next === 'system') root.removeAttribute('data-theme');
      else root.setAttribute('data-theme', next);
      try { if (next === 'system') localStorage.removeItem('kwatch-theme'); else localStorage.setItem('kwatch-theme', next); } catch (e) {}
      paint();
    });
  }

  // ---- Copy ----
  function copy(text, btn) {
    if (!navigator.clipboard) return;
    navigator.clipboard.writeText(text).then(function () {
      var old = btn.textContent;
      btn.textContent = 'Copied';
      if (status) status.textContent = 'Copied';
      setTimeout(function () { btn.textContent = old; if (status) status.textContent = ''; }, 2000);
    });
  }
  document.querySelectorAll('[data-copy]').forEach(function (b) {
    b.addEventListener('click', function () {
      var el = document.getElementById(b.getAttribute('data-copy'));
      if (el) copy(el.textContent.trim(), b);
    });
  });
  document.querySelectorAll('.article pre.astro-code').forEach(function (pre) {
    var wrap = document.createElement('div');
    wrap.className = 'code-block';
    pre.parentNode.insertBefore(wrap, pre);
    wrap.appendChild(pre);
    var b = document.createElement('button');
    b.type = 'button';
    b.className = 'copy-btn';
    b.textContent = 'Copy';
    b.setAttribute('aria-label', 'Copy code');
    b.addEventListener('click', function () { copy(pre.textContent.replace(/\n$/, ''), b); });
    wrap.appendChild(b);
    if (!pre.hasAttribute('tabindex')) pre.setAttribute('tabindex', '0');
  });

  // ---- TOC: mark the section being read ----
  var tocLinks = Array.prototype.slice.call(document.querySelectorAll('.toc a'));
  if (tocLinks.length && 'IntersectionObserver' in window) {
    var map = {};
    tocLinks.forEach(function (a) { map[a.getAttribute('href').slice(1)] = a; });
    var heads = Object.keys(map).map(function (id) { return document.getElementById(id); }).filter(Boolean);
    var mark = function (id) {
      tocLinks.forEach(function (a) { if (a === map[id]) a.setAttribute('aria-current', 'location'); else a.removeAttribute('aria-current'); });
    };
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) mark(e.target.id); });
    }, { rootMargin: '0px 0px -70% 0px' });
    heads.forEach(function (h) { io.observe(h); });
    if (heads[0]) mark(heads[0].id);
  }

  // ---- Search (Pagefind) ----
  var dlg = document.getElementById('search');
  if (!dlg || typeof dlg.showModal !== 'function') return;
  var input = document.getElementById('search-input');
  var idle = document.getElementById('search-idle');
  var results = document.getElementById('search-results');
  var none = document.getElementById('search-none');
  var noneTitle = document.getElementById('search-none-title');
  var sstatus = document.getElementById('search-status');
  var pf = null, trigger = null, seq = 0, timer = 0, selected = -1;

  function opts() { return Array.prototype.slice.call(dlg.querySelectorAll('[role="option"]')).filter(function (o) { return o.offsetParent !== null; }); }
  function select(i) {
    var list = opts();
    if (!list.length) return;
    selected = (i + list.length) % list.length;
    list.forEach(function (o, n) {
      o.setAttribute('aria-selected', n === selected ? 'true' : 'false');
      if (n === selected) { input.setAttribute('aria-activedescendant', o.id || ''); o.scrollIntoView({ block: 'nearest' }); }
    });
  }
  function open(from) {
    trigger = from || document.activeElement;
    dlg.showModal();
    input.focus();
  }
  function close() { dlg.close(); }
  dlg.addEventListener('close', function () {
    if (trigger && trigger.focus) trigger.focus();
  });
  dlg.addEventListener('click', function (e) { if (e.target === dlg) close(); });
  document.querySelectorAll('[data-search-open]').forEach(function (b) {
    b.addEventListener('click', function () { open(b); });
  });
  var closeBtn = dlg.querySelector('[data-search-close]');
  if (closeBtn) closeBtn.addEventListener('click', close);
  document.addEventListener('keydown', function (e) {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      if (dlg.open) close(); else open();
    }
  });
  dlg.querySelector('form').addEventListener('submit', function (e) { e.preventDefault(); });
  input.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown') { e.preventDefault(); select(selected + 1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); select(selected - 1); }
    else if (e.key === 'Enter') {
      var list = opts();
      var o = list[selected >= 0 ? selected : 0];
      if (o && o.href) { e.preventDefault(); window.location.href = o.href; }
    }
  });

  function show(state) {
    idle.hidden = state !== 'idle';
    results.hidden = state !== 'results';
    none.hidden = state !== 'none';
    selected = -1;
  }
  function load() {
    if (!pf) pf = import('/pagefind/pagefind.js').then(function (m) { return m.options ? m.options({ excerptLength: 18 }).then(function () { return m; }) : m; });
    return pf;
  }
  function render(items) {
    results.textContent = '';
    items.forEach(function (d, i) {
      var a = document.createElement('a');
      a.setAttribute('role', 'option');
      a.id = 'search-opt-' + i;
      a.setAttribute('aria-selected', 'false');
      a.href = d.url;
      var s = document.createElement('strong');
      s.textContent = d.meta && d.meta.title ? d.meta.title : d.url;
      var p = document.createElement('span');
      p.innerHTML = d.excerpt; // Pagefind output of our own index; only <mark> tags.
      a.appendChild(s);
      a.appendChild(p);
      results.appendChild(a);
    });
  }
  function run(q) {
    var mine = ++seq;
    load().then(function (m) { return m.search(q); }).then(function (r) {
      return Promise.all(r.results.slice(0, 8).map(function (x) { return x.data(); }));
    }).then(function (items) {
      if (mine !== seq) return;
      if (!items.length) {
        noneTitle.textContent = 'No posts match "' + q + '".';
        show('none');
        sstatus.textContent = 'No results';
        return;
      }
      render(items);
      show('results');
      select(0);
      sstatus.textContent = items.length + (items.length === 1 ? ' result' : ' results');
    }).catch(function () {
      if (mine !== seq) return;
      noneTitle.textContent = 'Search is not available here.';
      show('none');
    });
  }
  input.addEventListener('input', function () {
    var q = input.value.trim();
    clearTimeout(timer);
    if (!q) { seq++; show('idle'); sstatus.textContent = ''; return; }
    timer = setTimeout(function () { run(q); }, 120);
  });
})();
