/* Let Talk landing page. No libraries: IntersectionObserver, CSS transforms and opacity. */
(function () {
  'use strict';
  var d = document;
  var reduce = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
  var $ = function (s, r) { return (r || d).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || d).querySelectorAll(s)); };

  /* ---------- Reveal on scroll ---------- */
  var revealEls = $$('[data-reveal]');
  if ('IntersectionObserver' in window && !reduce) {
    var revealIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); revealIO.unobserve(e.target); }
      });
    }, { threshold: 0.15, rootMargin: '0px 0px -8% 0px' });
    revealEls.forEach(function (el, i) {
      el.style.transitionDelay = (i % 4) * 70 + 'ms';
      revealIO.observe(el);
    });
  } else {
    revealEls.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---------- Hero: live translation demo (prepared phrases, no network calls) ---------- */
  var LANGS = {
    es: { name: 'Spanish', who: 'Sofía' },
    ja: { name: 'Japanese', who: 'Yuki' },
    fr: { name: 'French', who: 'Camille' },
    ar: { name: 'Arabic', who: 'Layla', rtl: true },
    pt: { name: 'Portuguese', who: 'Rafael' },
    ko: { name: 'Korean', who: 'Min-jun' }
  };
  var PHRASES = [
    { en: 'I miss you. When are you coming home?',
      es: 'Te extraño. ¿Cuándo vuelves a casa?', ja: '会いたいよ。いつ帰ってくるの？', fr: 'Tu me manques. Quand est-ce que tu rentres ?',
      ar: 'أشتاق إليك. متى ستعود إلى البيت؟', pt: 'Estou com saudades. Quando você volta para casa?', ko: '보고 싶어요. 언제 집에 와요?' },
    { en: 'Where is the train station?',
      es: '¿Dónde está la estación de tren?', ja: '駅はどこですか？', fr: 'Où est la gare ?',
      ar: 'أين محطة القطار؟', pt: 'Onde fica a estação de trem?', ko: '기차역이 어디예요?' },
    { en: 'Happy birthday, grandma!',
      es: '¡Feliz cumpleaños, abuela!', ja: 'おばあちゃん、お誕生日おめでとう！', fr: 'Joyeux anniversaire, mamie !',
      ar: 'عيد ميلاد سعيد يا جدتي!', pt: 'Feliz aniversário, vovó!', ko: '할머니, 생신 축하드려요!' },
    { en: 'Nice to meet you.',
      es: 'Mucho gusto.', ja: 'はじめまして。', fr: 'Enchanté.',
      ar: 'تشرفت بمعرفتك.', pt: 'Prazer em conhecer você.', ko: '만나서 반가워요.' },
    { en: 'How much does this cost?',
      es: '¿Cuánto cuesta esto?', ja: 'これはいくらですか？', fr: 'Combien ça coûte ?',
      ar: 'كم سعر هذا؟', pt: 'Quanto custa isso?', ko: '이거 얼마예요?' },
    { en: "Let's talk tomorrow.",
      es: 'Hablamos mañana.', ja: '明日話しましょう。', fr: 'On se parle demain.',
      ar: 'لنتحدث غداً.', pt: 'A gente se fala amanhã.', ko: '내일 얘기해요.' }
  ];

  var outEl = $('#demo-out'), inEl = $('#demo-in'), inBubble = $('#demo-in-bubble');
  var nameEl = $('#demo-name'), avatarEl = $('#demo-avatar'), tagEl = $('#demo-tag');
  var phone = $('#demo-phone'), note = $('#try-note');
  var state = { lang: 'es', phrase: 0, run: 0, visible: true, timer: null };

  function wait(ms, run) {
    return new Promise(function (resolve, reject) {
      setTimeout(function () { run === state.run ? resolve() : reject(new Error('stale')); }, ms);
    });
  }

  // Split into animated pieces. Arabic is split by word so its letters stay joined.
  function pieces(text, byWord) {
    var parts = byWord ? text.split(/(\s+)/) : Array.from(text);
    var frag = d.createDocumentFragment();
    parts.forEach(function (p, i) {
      if (/^\s+$/.test(p)) { frag.appendChild(d.createTextNode(p)); return; }
      var s = d.createElement('span');
      s.className = 'ch';
      s.style.setProperty('--i', i);
      s.textContent = p;
      frag.appendChild(s);
    });
    return frag;
  }

  function setHeader() {
    var L = LANGS[state.lang];
    nameEl.textContent = L.who;
    avatarEl.textContent = L.who.charAt(0);
    tagEl.textContent = L.who + ' reads it in ' + L.name;
  }

  function showFinal() {
    var L = LANGS[state.lang], P = PHRASES[state.phrase];
    outEl.textContent = P.en;
    inEl.textContent = P[state.lang];
    inEl.lang = state.lang;
    inEl.dir = L.rtl ? 'rtl' : 'ltr';
    inBubble.classList.remove('is-hidden', 'is-out');
    phone.classList.remove('is-typing');
  }

  function runDemo(typeIt) {
    var run = ++state.run;
    var L = LANGS[state.lang], P = PHRASES[state.phrase];
    clearTimeout(state.timer);
    setHeader();
    if (reduce) { showFinal(); return; }

    var chain = Promise.resolve();
    if (typeIt) {
      inBubble.classList.add('is-hidden');
      outEl.textContent = '';
      phone.classList.add('is-typing');
      Array.from(P.en).forEach(function (c) {
        chain = chain.then(function () { outEl.textContent += c; return wait(26, run); });
      });
      chain = chain.then(function () { phone.classList.remove('is-typing'); return wait(260, run); });
    } else {
      outEl.textContent = P.en;
    }

    chain.then(function () {
      // Start from the English words, dissolve them, then re-form in the other language.
      inEl.lang = 'en'; inEl.dir = 'ltr';
      inEl.textContent = '';
      inEl.appendChild(pieces(P.en, false));
      inBubble.classList.remove('is-hidden', 'is-out');
      return wait(typeIt ? 420 : 60, run);
    }).then(function () {
      inBubble.classList.add('is-out');
      return wait(360 + P.en.length * 6, run);
    }).then(function () {
      inEl.lang = state.lang; inEl.dir = L.rtl ? 'rtl' : 'ltr';
      inEl.textContent = '';
      inEl.appendChild(pieces(P[state.lang], !!L.rtl));
      inBubble.classList.remove('is-out');
      // Keep cycling through phrases while the hero is on screen.
      state.timer = setTimeout(function () {
        if (!state.visible || d.hidden) return;
        state.phrase = (state.phrase + 1) % PHRASES.length;
        runDemo(true);
      }, 5200);
    }).catch(function () { /* a newer run took over */ });
  }

  $$('.chip').forEach(function (chip) {
    chip.addEventListener('click', function () {
      $$('.chip').forEach(function (c) { c.classList.remove('is-on'); c.setAttribute('aria-pressed', 'false'); });
      chip.classList.add('is-on'); chip.setAttribute('aria-pressed', 'true');
      state.lang = chip.getAttribute('data-lang');
      note.textContent = '';
      runDemo(false);
    });
  });

  var list = $('#try-phrases');
  PHRASES.forEach(function (p) { var o = d.createElement('option'); o.value = p.en; list.appendChild(o); });

  var STOP = { the: 1, a: 1, is: 1, to: 1, you: 1, i: 1, are: 1, this: 1, does: 1, it: 1 };
  function words(s) {
    return s.toLowerCase().replace(/[^a-z'\s]/g, ' ').split(/\s+/).filter(function (w) { return w && !STOP[w]; });
  }
  function match(text) {
    var typed = words(text), best = -1, score = 0;
    PHRASES.forEach(function (p, i) {
      var pw = words(p.en);
      var s = typed.filter(function (w) { return pw.indexOf(w) > -1; }).length;
      if (s > score) { score = s; best = i; }
    });
    return best;
  }
  $('#try-form').addEventListener('submit', function (e) {
    e.preventDefault();
    var input = $('#try-input'), text = input.value.trim();
    if (!text) { input.focus(); return; }
    var i = match(text);
    if (i < 0) {
      note.textContent = 'This demo knows six phrases, like "Where is the train station?" The app translates anything you say.';
      return;
    }
    note.textContent = PHRASES[i].en.toLowerCase().replace(/[^a-z]/g, '') === text.toLowerCase().replace(/[^a-z]/g, '')
      ? '' : 'Closest phrase in this demo. The app translates anything you say.';
    state.phrase = i;
    input.value = '';
    runDemo(true);
  });

  var hero = $('#hero');
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (entries) {
      var was = state.visible;
      state.visible = entries[0].isIntersecting;
      if (state.visible && !was && !reduce) runDemo(true);
      if (!state.visible) clearTimeout(state.timer);
    }, { threshold: 0.2 }).observe(hero);
  }
  setHeader();
  if (!reduce) setTimeout(function () { runDemo(true); }, 500);

  /* ---------- Hero: glows lean toward the pointer ---------- */
  if (!reduce) {
    var gx = 0, gy = 0, queued = false;
    var lean = function (x, y) {
      var r = hero.getBoundingClientRect();
      gx = ((x - r.left) / r.width - 0.5) * 2;
      gy = ((y - r.top) / r.height - 0.5) * 2;
      if (queued) return;
      queued = true;
      requestAnimationFrame(function () {
        hero.style.setProperty('--gx', gx.toFixed(3));
        hero.style.setProperty('--gy', gy.toFixed(3));
        queued = false;
      });
    };
    hero.addEventListener('pointermove', function (e) { lean(e.clientX, e.clientY); }, { passive: true });
    hero.addEventListener('touchmove', function (e) {
      if (e.touches[0]) lean(e.touches[0].clientX, e.touches[0].clientY);
    }, { passive: true });
  }

  /* ---------- The problem: bubbles meet as you scroll ---------- */
  var wall = $('#wall');
  if (reduce) {
    wall.classList.add('is-static');
  } else {
    var wallOn = false, wallQueued = false;
    var wallUpdate = function () {
      wallQueued = false;
      var r = wall.getBoundingClientRect();
      var total = r.height - window.innerHeight;
      var p = total > 0 ? Math.min(1, Math.max(0, -r.top / total)) : 1;
      wall.style.setProperty('--p', p.toFixed(3));
    };
    var wallScroll = function () {
      if (!wallOn || wallQueued) return;
      wallQueued = true;
      requestAnimationFrame(wallUpdate);
    };
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (e) { wallOn = e[0].isIntersecting; wallScroll(); }).observe(wall);
    } else { wallOn = true; }
    window.addEventListener('scroll', wallScroll, { passive: true });
    window.addEventListener('resize', wallScroll, { passive: true });
    wallUpdate();
  }

  /* ---------- Scroll story: pinned phone, four scenes ---------- */
  var steps = $$('.step'), scenes = $$('.scene'), rail = $$('.rail li');
  function setScene(i) {
    steps.forEach(function (s, n) { s.classList.toggle('is-on', n === i); });
    scenes.forEach(function (s, n) { s.classList.toggle('is-on', n === i); });
    rail.forEach(function (s, n) { s.classList.toggle('is-on', n === i); s.classList.toggle('is-done', n < i); });
  }
  if ('IntersectionObserver' in window) {
    var stepIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) setScene(+e.target.getAttribute('data-step'));
      });
    }, { rootMargin: (window.matchMedia && matchMedia('(max-width: 860px)').matches) ? '-72% 0px -28% 0px' : '-50% 0px -50% 0px' });
    steps.forEach(function (s) { stepIO.observe(s); });
  } else {
    steps.forEach(function (s) { s.classList.add('is-on'); });
  }

  // Decorative QR-style pattern (not a scannable code).
  var qr = $('#qr');
  if (qr) {
    var N = 21, seed = 7, html = '';
    var rnd = function () { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
    var finder = function (x, y) {
      var f = function (ox, oy) {
        var dx = x - ox, dy = y - oy;
        if (dx < 0 || dy < 0 || dx > 6 || dy > 6) return null;
        return dx === 0 || dy === 0 || dx === 6 || dy === 6 || (dx > 1 && dx < 5 && dy > 1 && dy < 5);
      };
      var a = f(0, 0), b = f(N - 7, 0), c = f(0, N - 7);
      if (a !== null) return a; if (b !== null) return b; if (c !== null) return c;
      if ((x < 8 && y < 8) || (x > N - 9 && y < 8) || (x < 8 && y > N - 9)) return false;
      return null;
    };
    for (var y = 0; y < N; y++) for (var x = 0; x < N; x++) {
      var on = finder(x, y); if (on === null) on = rnd() > 0.52;
      html += '<i' + (on ? ' class="on"' : '') + '></i>';
    }
    qr.innerHTML = html;
  }

  /* ---------- Voice teaser: waveform + browser voices (an illustration, not cloning) ---------- */
  var wave = $('#wave'), play = $('#play'), waveNote = $('#wave-note');
  var bars = '';
  for (var b = 0; b < 44; b++) {
    var h = 22 + Math.round(60 * Math.abs(Math.sin(b * 0.55) * Math.cos(b * 0.21)) + (b % 3) * 6);
    bars += '<i style="--h:' + Math.min(100, h) + '%;--d:' + (b * 37 % 600) + 'ms"></i>';
  }
  wave.innerHTML = bars;

  var synth = window.speechSynthesis, voiceIx = 0, speaking = false, stopTimer = null;
  function pickVoices(prefix) {
    var all = synth ? synth.getVoices() : [];
    return all.filter(function (v) { return v.lang && v.lang.toLowerCase().indexOf(prefix) === 0; });
  }
  if (synth && synth.getVoices) synth.getVoices(); // some browsers load the list lazily
  function stopSample() {
    speaking = false;
    clearTimeout(stopTimer);
    if (synth) synth.cancel();
    wave.classList.remove('is-playing');
    play.classList.remove('is-playing');
    play.setAttribute('aria-label', 'Play sample');
  }
  function say(text, voice, lang, pitch) {
    return new Promise(function (resolve) {
      var u = new SpeechSynthesisUtterance(text);
      if (voice) u.voice = voice;
      u.lang = voice ? voice.lang : lang;
      u.pitch = pitch; u.rate = 0.95;
      u.onend = resolve; u.onerror = resolve;
      synth.speak(u);
    });
  }
  function playSample() {
    speaking = true;
    wave.classList.add('is-playing');
    play.classList.add('is-playing');
    play.setAttribute('aria-label', 'Stop sample');
    if (!synth || typeof SpeechSynthesisUtterance === 'undefined') {
      waveNote.textContent = "Your browser can't play speech, so this shows the waveform only. Voice cloning isn't available yet.";
      stopTimer = setTimeout(stopSample, 3200);
      return;
    }
    var en = pickVoices('en'), es = pickVoices('es');
    // Voice B: a second voice if the browser has one, otherwise the same voice at a lower pitch.
    var same = en.length < 2;
    var enV = en[same ? 0 : voiceIx] || null;
    var esV = es[es.length > 1 ? voiceIx : 0] || null;
    var pitch = voiceIx === 1 && same ? 0.7 : 1;
    stopTimer = setTimeout(stopSample, 12000); // safety net if the browser never reports the end
    say('Hello, how are you?', enV, 'en-US', pitch)
      .then(function () { return speaking ? say('Hola, ¿cómo estás?', esV, 'es-ES', pitch) : null; })
      .then(function () { if (speaking) stopSample(); });
  }
  play.addEventListener('click', function () { speaking ? stopSample() : playSample(); });
  $$('.seg-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      $$('.seg-btn').forEach(function (x) { x.classList.remove('is-on'); x.setAttribute('aria-pressed', 'false'); });
      btn.classList.add('is-on'); btn.setAttribute('aria-pressed', 'true');
      voiceIx = +btn.getAttribute('data-voice');
      if (speaking) { stopSample(); playSample(); }
    });
  });
  window.addEventListener('pagehide', function () { if (synth) synth.cancel(); });

  /* ---------- Sign-up forms (Netlify Forms) ---------- */
  $$('form.signup').forEach(function (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var msg = $('.signup-msg', form), btn = $('button[type=submit]', form);
      var body = new URLSearchParams(new FormData(form)).toString();
      btn.disabled = true;
      msg.className = 'signup-msg';
      msg.textContent = 'Sending…';
      fetch('/', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body })
        .then(function (r) {
          if (!r.ok) throw new Error('HTTP ' + r.status);
          form.classList.add('is-done');
          msg.classList.add('ok');
          msg.textContent = form.getAttribute('data-success');
        })
        .catch(function () {
          btn.disabled = false;
          msg.classList.add('err');
          msg.textContent = "That didn't go through. Please try again, or email support@lettalkapp.com.";
        });
    });
  });

  /* ---------- Ticker: hello in 30 languages ---------- */
  var HELLOS = ['Hello', 'Hola', 'Bonjour', 'Hallo', 'Ciao', 'Olá', 'こんにちは', '안녕하세요', '你好', 'مرحبا',
    'नमस्ते', 'Привет', 'Merhaba', 'Γειά σου', 'שלום', 'Sawubona', 'Jambo', 'Xin chào', 'สวัสดี', 'Halo',
    'Kumusta', 'Hej', 'Hei', 'Ahoj', 'Cześć', 'Salut', 'Szia', 'Привіт', 'হ্যালো', 'سلام'];
  var ticker = $('#ticker');
  if (ticker) {
    var run = HELLOS.map(function (h) { return '<span>' + h + '</span>'; }).join('') +
      '<span class="ticker-cta">Coming to the App Store</span>';
    ticker.innerHTML = '<div class="ticker-run">' + run + '</div><div class="ticker-run">' + run + '</div>';
  }

  /* ---------- Header shadow once you scroll ---------- */
  var header = $('.header');
  var onScroll = function () { header.classList.toggle('is-scrolled', window.scrollY > 8); };
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
})();
