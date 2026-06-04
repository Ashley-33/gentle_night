/* ============================================================
   Gentle Night · 温柔夜记
   Data model + logic
   - localStorage entries: one per day, three 1-5 scores
   - score -> bead shade (higher = richer)
   - time range -> beads (gravity-packed, colored by score)
   - insights derived from average score per metric
   - 50+50 bilingual quotes, random (one language) per load
   ============================================================ */
(() => {
  const $  = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n));

  /* ───────────────────────── config ───────────────────────── */
  const METRICS = ["mood", "body", "tomorrow"];
  const RANGE_DAYS = { "7天": 7, "30天": 30, "3个月": 90, "1年": 365 };
  const BEAD_CAP = 70; // max beads rendered per jar (long ranges sampled)

  // 3 anchors per channel: score 1 (neutral taupe/grey) → 3 (soft cream tint) → 5 (rich vivid)
  // low days read as grey, good days as vivid colour — exactly like the reference jars.
  // anchors at score 1 / 3 / 5. The 3→5 spread is deliberately WIDE so each level
  // (一般 / 好 / 很好) reads distinctly: light & soft → clear → deep & vivid.
  // soft, low-saturation "Morandi" palette — premium & milky.
  // levels read by VALUE: taupe (low) → cream (mid) → dusty signature colour (high).
  const RAMP = {
    mood: {
      l: ["#c8bda6", "#f6edd6", "#f1dda8"],
      m: ["#b1a589", "#ecdcb1", "#e6cd83"],
      d: ["#9b9075", "#dac79a", "#d6bb6e"],
    },
    body: {
      l: ["#c5c3b2", "#e9efde", "#cde0bb"],
      m: ["#aaa794", "#cedeba", "#a8cb93"],
      d: ["#949281", "#b6c89f", "#8ab676"],
    },
    tomorrow: {
      l: ["#c4bdc1", "#ece6f1", "#dccfeb"],
      m: ["#a89eaa", "#d6cbe4", "#c3aedd"],
      d: ["#928a93", "#bdafcf", "#ad93d2"],
    },
  };

  // insight copy by bucket (\n = soft line break; cards are narrow)
  const INSIGHTS = {
    mood: {
      none: "今晚落下\n第一颗珠子，\n开始记录\n你的温柔吧。🫙",
      low:  "最近有些\n起伏呢，\n抱抱你，\n一切都会好。🤍",
      mid:  "心情有起有落，\n但你都稳稳\n接住了，\n很棒。🌿",
      high: "最近心情\n大多明亮，\n好好收着\n这份暖。🌼",
    },
    body: {
      none: "记录下\n今天的身体，\n听听它\n说什么。🫙",
      low:  "身体想要\n多歇一歇，\n好好疼疼\n自己呀。🍵",
      mid:  "身体偶尔会累，\n记得喝口水、\n早点休息。🛏️",
      high: "身体状态\n挺不错，\n继续好好\n照顾自己。🌱",
    },
    tomorrow: {
      none: "写下对明天\n的小心情，\n种下一点\n期待吧。🫙",
      low:  "对明天\n可以慢慢来，\n先把今天\n温柔收好。💜",
      mid:  "对明天\n有期待也有思量，\n一步步\n都算数。💫",
      high: "你对明天\n满怀期待，\n这份光\n很珍贵。✨",
    },
  };

  // 50 gentle "check-in" lines for the top
  const HERO_QUOTES = [
    { zh: "今天也辛苦了，先停一停。", en: "You've worked hard today — pause for a moment." },
    { zh: "此刻，只属于你自己。", en: "This moment belongs only to you." },
    { zh: "慢一点，没关系的。", en: "Slow down — it's okay." },
    { zh: "你值得被温柔对待。", en: "You deserve to be treated gently." },
    { zh: "给自己十秒钟的注视。", en: "Give yourself ten seconds of attention." },
    { zh: "不必完美，真实就好。", en: "You needn't be perfect — real is enough." },
    { zh: "你已经做得很好了。", en: "You're already doing well." },
    { zh: "深呼吸，把肩膀放松。", en: "Breathe deep, let your shoulders drop." },
    { zh: "今天的你，也很重要。", en: "Today's you matters too." },
    { zh: "把心事，轻轻放下。", en: "Set your worries down, gently." },
    { zh: "累了就承认累，没关系。", en: "If you're tired, admit it — that's fine." },
    { zh: "你从来都不是一个人。", en: "You are never in this alone." },
    { zh: "善待自己，从此刻开始。", en: "Be kind to yourself, starting now." },
    { zh: "你的感受，都算数。", en: "All your feelings count." },
    { zh: "停下脚步，看看自己。", en: "Pause, and look at yourself." },
    { zh: "今天的情绪，值得被听见。", en: "Today's feelings deserve to be heard." },
    { zh: "你已经很努力了，我看见了。", en: "You've tried so hard — I see it." },
    { zh: "允许自己，只是普通的一天。", en: "Allow yourself an ordinary day." },
    { zh: "温柔地，问问自己好不好。", en: "Gently ask yourself how you are." },
    { zh: "一天结束前，抱抱自己。", en: "Before the day ends, hug yourself." },
    { zh: "你不需要向谁证明什么。", en: "You owe no one any proof." },
    { zh: "慢慢来，时间还够。", en: "Take it slow — there's still time." },
    { zh: "此刻的平静，是给你的礼物。", en: "This calm is a gift for you." },
    { zh: "把今天，温柔地收个尾。", en: "Close today softly." },
    { zh: "你的存在，本身就很好。", en: "Your being here is already enough." },
    { zh: "感受此刻，不必急着评判。", en: "Feel this moment; don't rush to judge." },
    { zh: "无论今天如何，你都值得温柔。", en: "However today went, you deserve tenderness." },
    { zh: "给疲惫的自己，一点空间。", en: "Give your tired self some room." },
    { zh: "你今天，已经尽力了。", en: "You gave your best today." },
    { zh: "轻轻地，和今天说声谢谢。", en: "Quietly, thank today." },
    { zh: "别急，先照顾好情绪。", en: "No rush — tend to your feelings first." },
    { zh: "你比想象中更坚强。", en: "You're stronger than you think." },
    { zh: "这一刻，你可以只是休息。", en: "In this moment, you may simply rest." },
    { zh: "把好与不好，都记下来。", en: "Note it all — the good and the not." },
    { zh: "你愿意停下来，已经很勇敢。", en: "Pausing at all is brave." },
    { zh: "今晚，对自己温柔一点。", en: "Be a little gentler with yourself tonight." },
    { zh: "心里的声音，值得被倾听。", en: "The voice inside is worth listening to." },
    { zh: "不完美的一天，也是一天。", en: "An imperfect day is still a day." },
    { zh: "你的脚步，可以再轻一些。", en: "Let your steps be a little lighter." },
    { zh: "此刻，你很安全。", en: "In this moment, you are safe." },
    { zh: "把紧绷的自己，松开一点。", en: "Loosen the tightness in you." },
    { zh: "今天的星光，为你而留。", en: "Tonight's starlight is kept for you." },
    { zh: "你所经历的，都有意义。", en: "All you've been through means something." },
    { zh: "先停下，再温柔地继续。", en: "Pause first, then go on gently." },
    { zh: "你的好，不需要被看见才成立。", en: "Your worth doesn't need an audience." },
    { zh: "让心，慢慢沉静下来。", en: "Let your heart settle, slowly." },
    { zh: "一点点进步，也是进步。", en: "A little progress is progress." },
    { zh: "你已经走了很远了。", en: "You've come such a long way." },
    { zh: "此刻，把世界调成静音。", en: "Mute the world, just for now." },
    { zh: "谢谢你，今天也认真活着。", en: "Thank you for living earnestly today." },
  ];

  // 50 soothing "rest" lines for the bottom
  const REST_QUOTES = [
    { zh: "你已经认真生活了一整天，现在可以放心休息了。", en: "You've lived this day fully — now you may rest." },
    { zh: "今天就到这里，剩下的交给明天。", en: "Let today end here; leave the rest to tomorrow." },
    { zh: "闭上眼睛，把一切都放下。", en: "Close your eyes and let everything go." },
    { zh: "你做得够多了，该休息了。", en: "You've done enough — time to rest." },
    { zh: "愿你今夜，睡得安稳。", en: "May you sleep soundly tonight." },
    { zh: "黑夜会接住所有的疲惫。", en: "The night will hold all your weariness." },
    { zh: "明天的事，明天再说。", en: "Tomorrow's matters can wait for tomorrow." },
    { zh: "此刻，你可以彻底松开。", en: "Right now, you can fully let go." },
    { zh: "晚安，温柔的人。", en: "Good night, gentle soul." },
    { zh: "把今天的重量，卸下来吧。", en: "Set down the weight of today." },
    { zh: "你值得一个安稳的夜晚。", en: "You deserve a peaceful night." },
    { zh: "月亮已经替你守夜了。", en: "The moon keeps watch for you now." },
    { zh: "安心睡吧，世界会等你。", en: "Sleep easy — the world will wait." },
    { zh: "今晚，不必再想任何事。", en: "Tonight, you needn't think of anything." },
    { zh: "让梦，带你去柔软的地方。", en: "Let dreams carry you somewhere soft." },
    { zh: "你已尽力，剩下的请交给夜。", en: "You've tried — leave the rest to the night." },
    { zh: "慢慢呼吸，慢慢入睡。", en: "Breathe slowly, drift slowly to sleep." },
    { zh: "今天辛苦了，好好睡。", en: "You worked hard today — sleep well." },
    { zh: "星星会替你记住今天。", en: "The stars will remember today for you." },
    { zh: "放下手机，拥抱困意。", en: "Put the phone down, welcome the sleepiness." },
    { zh: "愿温柔，伴你入眠。", en: "May tenderness see you to sleep." },
    { zh: "这一天，被好好收下了。", en: "This day has been gently received." },
    { zh: "你不必撑到最后一刻。", en: "You don't have to hold on till the very end." },
    { zh: "夜深了，该交给梦了。", en: "It's late — time to hand over to dreams." },
    { zh: "今晚的你，可以什么都不做。", en: "Tonight, you may do nothing at all." },
    { zh: "把烦恼，留在今天。", en: "Leave your worries in today." },
    { zh: "安静地，谢谢自己。", en: "Quietly, thank yourself." },
    { zh: "愿你被柔软的梦包围。", en: "May soft dreams surround you." },
    { zh: "休息，也是一种努力。", en: "Resting is its own kind of effort." },
    { zh: "灯灭之后，只剩温柔。", en: "After the light goes out, only gentleness remains." },
    { zh: "今天的句号，画得很好。", en: "You ended today just right." },
    { zh: "让身体，沉进床里吧。", en: "Let your body sink into the bed." },
    { zh: "明早醒来，又是新的一天。", en: "When you wake, it's a brand-new day." },
    { zh: "你已经足够好了，睡吧。", en: "You are enough — go to sleep." },
    { zh: "把心交给夜晚保管。", en: "Leave your heart in the night's keeping." },
    { zh: "愿你今夜无梦，或好梦。", en: "May tonight be dreamless, or full of good dreams." },
    { zh: "一切都会慢慢变好的。", en: "Everything will slowly get better." },
    { zh: "收下今晚的状态，晚安。", en: "Your day is logged — good night." },
    { zh: "现在，轮到你被照顾了。", en: "Now it's your turn to be cared for." },
    { zh: "闭眼前，对自己说声辛苦了。", en: "Before sleep, tell yourself: well done." },
    { zh: "夜很长，足够你好好歇息。", en: "The night is long enough to truly rest." },
    { zh: "让今天，温柔地落幕。", en: "Let today fall gently to a close." },
    { zh: "你好好走过了今天，真好。", en: "You walked gently through today — how lovely." },
    { zh: "把疲惫，泡进夜色里。", en: "Soak your tiredness in the night." },
    { zh: "愿好梦，轻轻找到你。", en: "May good dreams find you softly." },
    { zh: "现在，只需要好好睡。", en: "For now, just sleep well." },
    { zh: "你已经很棒了，晚安。", en: "You did great — good night." },
    { zh: "卸下今天，迎接安眠。", en: "Lay down today, welcome sleep." },
    { zh: "让呼吸，带你进入梦乡。", en: "Let your breath lead you into dreams." },
    { zh: "晚安，愿你被世界温柔以待。", en: "Good night — may the world be gentle with you." },
  ];

  /* ───────────────────────── storage ───────────────────────── */
  const LS_ENTRIES = "gentle-night.entries";
  const LS_THEME = "gentle-night.theme";

  function loadEntries() {
    try { return JSON.parse(localStorage.getItem(LS_ENTRIES)) || []; }
    catch { return []; }
  }
  function saveEntries(e) { localStorage.setItem(LS_ENTRIES, JSON.stringify(e)); }

  function dateKey(d) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }
  const todayKey = () => dateKey(new Date());
  function parseDate(s) { const [y, m, d] = s.split("-").map(Number); return new Date(y, m - 1, d); }

  function upsertToday(scores) {
    const entries = loadEntries();
    const k = todayKey();
    const rec = { date: k, ...scores };
    const i = entries.findIndex((x) => x.date === k);
    if (i >= 0) entries[i] = rec; else entries.push(rec);
    entries.sort((a, b) => (a.date < b.date ? -1 : 1));
    saveEntries(entries);
    return entries;
  }
  function todayEntry() { return loadEntries().find((e) => e.date === todayKey()); }

  function entriesInRange(days) {
    const cutoff = new Date(); cutoff.setHours(0, 0, 0, 0);
    cutoff.setDate(cutoff.getDate() - (days - 1));
    return loadEntries()
      .filter((e) => parseDate(e.date) >= cutoff)
      .sort((a, b) => (a.date < b.date ? -1 : 1)); // oldest first → newest land on top
  }

  /* ───────────────────────── color helpers ───────────────────────── */
  const h2 = (n) => clamp(Math.round(n), 0, 255).toString(16).padStart(2, "0");
  function lerpHex(a, b, t) {
    const ar = parseInt(a.slice(1, 3), 16), ag = parseInt(a.slice(3, 5), 16), ab = parseInt(a.slice(5, 7), 16);
    const br = parseInt(b.slice(1, 3), 16), bg = parseInt(b.slice(3, 5), 16), bb = parseInt(b.slice(5, 7), 16);
    return `#${h2(ar + (br - ar) * t)}${h2(ag + (bg - ag) * t)}${h2(ab + (bb - ab) * t)}`;
  }
  function hexToRgba(hex, a) {
    const r = parseInt(hex.slice(1, 3), 16), g = parseInt(hex.slice(3, 5), 16), b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r},${g},${b},${a})`;
  }
  function lerp3(arr, score) {
    const s = clamp(score, 1, 5);
    return s <= 3 ? lerpHex(arr[0], arr[1], (s - 1) / 2) : lerpHex(arr[1], arr[2], (s - 3) / 2);
  }
  function scoreColors(metric, score) {
    const r = RAMP[metric];
    const deep = lerp3(r.d, score);
    return {
      light: lerp3(r.l, score),
      mid: lerp3(r.m, score),
      deep,
      glow: hexToRgba(deep, 0.5),
    };
  }

  /* ───────────────────────── physics packing ───────────────────────── */
  // Drop each bead and let it rest on the floor or atop placed beads (circle rest).
  function packDrop(W, H, radii) {
    const placed = [];
    for (const r of radii) {
      let best = null;
      for (let attempt = 0; attempt < 28; attempt++) {
        const x = r + Math.random() * (W - 2 * r);
        let y = H - r; // floor
        for (const p of placed) {
          const dx = x - p.x, sum = r + p.r;
          if (Math.abs(dx) < sum) {
            const dy = Math.sqrt(sum * sum - dx * dx);
            y = Math.min(y, p.y - dy); // rest on top of p
          }
        }
        // settle into the deepest available pocket (largest y)
        if (best === null || y > best.y) best = { x, y };
      }
      placed.push({ x: best.x, y: best.y, r });
    }
    return placed;
  }

  // gentle twinkling sparkle cluster for top-level (score 5) beads/orbs
  function addSpark(el, size, top, left) {
    const s = document.createElement("i");
    s.className = "glint";
    s.style.width = s.style.height = size + "%";
    s.style.top = top + "%";
    s.style.left = left + "%";
    s.style.animationDelay = (Math.random() * 2).toFixed(2) + "s";
    s.style.animationDuration = (2.1 + Math.random() * 0.8).toFixed(2) + "s";
    el.appendChild(s);
  }
  // a little constellation of stars; `big` (orbs) gets one extra
  function sparkle(el, big) {
    addSpark(el, big ? 54 : 56, 0, 8);     // main star, upper-left
    addSpark(el, big ? 32 : 34, 52, 56);   // secondary, lower-right
    addSpark(el, big ? 26 : 24, 40, 22);   // tertiary, center
  }

  function sampleEven(arr, k) {
    if (arr.length <= k) return arr;
    const out = [], step = arr.length / k;
    for (let i = 0; i < k; i++) out.push(arr[Math.floor(i * step)]);
    return out;
  }

  /* ───────────────────────── render: jars ───────────────────────── */
  let currentRange = "7天";

  function renderJars() {
    const days = RANGE_DAYS[currentRange];
    let entries = entriesInRange(days);
    if (entries.length > BEAD_CAP) {
      console.info(`Gentle Night: ${entries.length} entries in range, showing ${BEAD_CAP} sampled beads.`);
      entries = sampleEven(entries, BEAD_CAP);
    }

    $$(".jar").forEach((jar) => {
      const metric = jar.dataset.jar;
      const glass = $(".jar-glass", jar);
      const fill = $(".jar-fill", jar);
      fill.innerHTML = "";

      const W = glass.clientWidth || 120;
      const H = glass.clientHeight || 200;
      const N = entries.length;
      jar.classList.toggle("jar-empty", N === 0);
      if (N === 0) return;

      // bead radius scales down as the jar gets crowded
      const base = W * 0.16;
      const r = clamp(base * Math.sqrt(16 / N), W * 0.058, W * 0.17);
      const radii = entries.map(() => r * (0.86 + Math.random() * 0.3));
      const placed = packDrop(W, H, radii);

      entries.forEach((e, i) => {
        const p = placed[i];
        const c = scoreColors(metric, e[metric] ?? 3);
        const el = document.createElement("span");
        el.className = "bead";
        el.style.setProperty("--b-light", c.light);
        el.style.setProperty("--b-mid", c.mid);
        el.style.setProperty("--b-deep", c.deep);
        el.style.setProperty("--b-glow", c.glow);
        const d = radii[i] * 2;
        el.style.width = el.style.height = d + "px";
        el.style.left = (p.x - radii[i]) + "px";
        el.style.top = (p.y - radii[i]) + "px";
        el.style.opacity = (0.9 + Math.random() * 0.1).toFixed(2);
        el.style.animation = `beadRise .5s ${i * 9}ms both cubic-bezier(.34,1.4,.6,1)`;
        el.title = `${e.date} · ${e[metric]}/5`;
        if ((e[metric] ?? 0) >= 5) { el.classList.add("bead--star"); sparkle(el); }
        fill.appendChild(el);
      });
    });
  }

  /* ───────────────────────── render: insights ───────────────────────── */
  function renderInsights() {
    const entries = entriesInRange(RANGE_DAYS[currentRange]);
    METRICS.forEach((metric) => {
      const p = $(`.insight.i-${metric} p`);
      if (!p) return;
      const vals = entries.map((e) => e[metric]).filter((v) => typeof v === "number");
      if (!vals.length) { p.textContent = INSIGHTS[metric].none; return; }
      const avg = vals.reduce((a, b) => a + b, 0) / vals.length;
      const bucket = avg >= 3.5 ? "high" : avg >= 2.0 ? "mid" : "low";
      p.textContent = INSIGHTS[metric][bucket];
    });
  }

  /* ───────────────────────── render: quotes ───────────────────────── */
  function setQuote(el, pool) {
    if (!el) return;
    const q = pool[Math.floor(Math.random() * pool.length)];
    const en = Math.random() < 0.5;
    el.textContent = en ? q.en : q.zh;
    el.classList.toggle("q-en", en);
  }
  function renderQuotes() {
    setQuote($("#heroQuote"), HERO_QUOTES);
    setQuote($("#restQuote"), REST_QUOTES);
  }

  /* ───────────────────────── date ───────────────────────── */
  const WEEK = ["日", "一", "二", "三", "四", "五", "六"];
  function renderDate() {
    const d = new Date();
    const el = $("#heroDate");
    if (el) el.innerHTML = `${d.getMonth() + 1}月${d.getDate()}日 &nbsp;星期${WEEK[d.getDay()]}`;
  }

  /* ───────────────────────── orbs ───────────────────────── */
  function readScores() {
    const scores = {};
    $$(".card").forEach((card) => {
      const sel = $(".orb.is-on", card);
      scores[card.dataset.metric] = sel ? +sel.dataset.value : 3;
    });
    return scores;
  }
  function applyScores(scores) {
    $$(".card").forEach((card) => {
      const val = scores[card.dataset.metric];
      const target = $(`.orb[data-value="${val}"]`, card);
      if (target) selectOrb(card, target);
    });
  }

  function haptic(el) {
    el.animate(
      [{ transform: "scale(1.25)" }, { transform: "scale(1.12)" }],
      { duration: 260, easing: "cubic-bezier(.34,1.56,.64,1)" }
    );
  }

  // paint a selected orb to preview the exact bead it will drop (colour = score)
  function paintOrb(orb, metric) {
    const v = +orb.dataset.value;
    const c = scoreColors(metric, v);
    orb.style.background =
      `radial-gradient(circle at 36% 26%, rgba(255,255,255,0.92) 2%, rgba(255,255,255,0) 40%),` +
      `radial-gradient(circle at 50% 46%, ${c.light}, ${c.mid} 74%, ${c.deep})`;
    orb.style.boxShadow = `0 0 24px ${c.glow}, inset 0 -3px 7px ${hexToRgba(c.deep, 0.28)}`;
    orb.style.borderColor = "rgba(255,255,255,0.95)";
    orb.querySelectorAll(".glint").forEach((s) => s.remove());
    if (v >= 5) sparkle(orb, true); // 闪亮的你
  }
  function clearOrb(orb) {
    orb.style.background = "";
    orb.style.boxShadow = "";
    orb.style.borderColor = "";
    orb.querySelectorAll(".glint").forEach((s) => s.remove());
  }
  function selectOrb(card, orb) {
    const metric = card.dataset.metric;
    $$(".orb", card).forEach((o) => {
      const on = o === orb;
      o.classList.toggle("is-on", on);
      o.setAttribute("aria-checked", on ? "true" : "false");
      if (on) paintOrb(o, metric); else clearOrb(o);
    });
  }

  $$(".card").forEach((card) => {
    const orbs = $$(".orb", card);
    orbs.forEach((orb) => {
      const num = document.createElement("span");
      num.className = "num";
      num.textContent = orb.dataset.value;
      orb.appendChild(num);
      // paint any orb that starts selected (HTML defaults)
      if (orb.classList.contains("is-on")) paintOrb(orb, card.dataset.metric);
      orb.addEventListener("click", () => {
        selectOrb(card, orb);
        haptic(orb);
      });
    });
  });

  /* ───────────────────────── good night (submit) ───────────────────────── */
  const gn = $("#goodnight");
  const hint = $("#goodnightHint");
  const gnText = $(".gn-text", gn);

  function showHint(saved) {
    const dark = document.documentElement.getAttribute("data-theme") === "dark";
    if (saved) {
      hint.textContent = dark ? "🌙 今晚的状态，已经收好啦 🌙" : "💛 今晚的状态，已经收好啦 🌙";
    }
    hint.classList.add("show");
  }

  /* ---- gentle synthesized sounds (Web Audio, no files) ---- */
  let _ac = null;
  function audio() {
    try {
      _ac = _ac || new (window.AudioContext || window.webkitAudioContext)();
      if (_ac.state === "suspended") _ac.resume();
    } catch { _ac = null; }
    return _ac;
  }
  function tone({ freq, dur = 0.2, vol = 0.08, type = "sine", cutoff = 2200, when = 0 }) {
    const c = audio(); if (!c) return;
    const t = c.currentTime + when;
    const o = c.createOscillator(), g = c.createGain(), f = c.createBiquadFilter();
    o.type = type; o.frequency.value = freq;
    f.type = "lowpass"; f.frequency.value = cutoff;
    o.connect(f); f.connect(g); g.connect(c.destination);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.start(t); o.stop(t + dur + 0.03);
  }
  // soft water-drop "plip" (a gentle marimba-ish blip)
  function sndDrop(freq) { tone({ freq, dur: 0.22, vol: 0.07, type: "sine", cutoff: 2400 }); tone({ freq: freq / 2, dur: 0.16, vol: 0.03, type: "sine", cutoff: 1100 }); }
  // soft wooden "tup" when the lid seals
  function sndSeal() { tone({ freq: 168, dur: 0.16, vol: 0.1, type: "triangle", cutoff: 700 }); }
  // airy closing chime
  function sndChime() { tone({ freq: 880, dur: 0.5, vol: 0.05, type: "sine", cutoff: 3200 }); tone({ freq: 1320, dur: 0.6, vol: 0.035, type: "sine", cutoff: 3200, when: 0.08 }); }

  // a glass jar appears on Tonight, the three beads drop in, the lid seals, then it floats away
  function dropIntoJar(scores) {
    const overlay = document.createElement("div");
    overlay.className = "drop-overlay";
    overlay.innerHTML =
      '<div class="drop-jar"><div class="drop-glass"><div class="drop-glass-overlay"></div></div><div class="drop-cork"></div></div>';
    document.body.appendChild(overlay);
    const jarEl = $(".drop-jar", overlay);
    const cork = $(".drop-cork", overlay);

    overlay.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 220, easing: "ease" });
    jarEl.animate(
      [{ transform: "translateY(16px) scale(.96)", opacity: 0 }, { transform: "none", opacity: 1 }],
      { duration: 320, easing: "cubic-bezier(.34,1.4,.6,1)", fill: "backwards" }
    );

    const SIZE = 42;
    const rests = [[42, 198], [110, 198], [76, 172]]; // pile: two on the floor, one nestled on top
    const order = ["mood", "body", "tomorrow"];
    const STEP = 230, FALL = 620, START = 320;

    order.forEach((metric, i) => {
      const c = scoreColors(metric, scores[metric]);
      const [cx, cy] = rests[i];
      const b = document.createElement("div");
      b.className = "drop-bead";
      b.style.cssText =
        `width:${SIZE}px;height:${SIZE}px;left:${cx - SIZE / 2}px;top:${cy - SIZE / 2}px;` +
        `background:radial-gradient(circle at 36% 28%,rgba(255,255,255,.92) 2%,rgba(255,255,255,0) 40%),` +
        `radial-gradient(circle at 50% 46%,${c.light},${c.mid} 74%,${c.deep});` +
        `box-shadow:0 0 14px ${c.glow}, inset 0 -3px 6px ${hexToRgba(c.deep, 0.25)};`;
      if ((scores[metric] ?? 0) >= 5) { b.classList.add("bead--star"); b.style.setProperty("--b-glow", c.glow); sparkle(b); }
      jarEl.appendChild(b);

      const start = START + i * STEP;
      b.animate(
        [
          { transform: "translateY(-250px) scale(1)", opacity: 0, offset: 0 },
          { opacity: 1, offset: 0.12 },
          { transform: "translateY(7px) scaleY(.86)", offset: 0.74 },
          { transform: "translateY(-5px) scaleY(1.04)", offset: 0.88 },
          { transform: "translateY(0) scaleY(1)", offset: 1 },
        ],
        { duration: FALL, delay: start, easing: "cubic-bezier(.45,.05,.55,1)", fill: "backwards" }
      );
      setTimeout(() => sndDrop(523 * Math.pow(2, i / 12)), start + FALL * 0.74);
    });

    const corkAt = START + order.length * STEP + 240;
    cork.animate(
      [
        { transform: "translateX(-50%) translateY(-42px)", opacity: 0, offset: 0 },
        { opacity: 1, offset: 0.3 },
        { transform: "translateX(-50%) translateY(3px)", offset: 0.8 },
        { transform: "translateX(-50%) translateY(0)", offset: 1 },
      ],
      { duration: 360, delay: corkAt, easing: "cubic-bezier(.34,1.5,.6,1)", fill: "both" }
    );
    setTimeout(() => sndSeal(), corkAt + 360 * 0.8);

    const outAt = corkAt + 520;
    jarEl.animate(
      [{ transform: "none", opacity: 1 }, { transform: "translateY(-36px) scale(.85)", opacity: 0 }],
      { duration: 560, delay: outAt, easing: "cubic-bezier(.4,0,.2,1)", fill: "forwards" }
    );
    overlay.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 380, delay: outAt + 200, easing: "ease", fill: "forwards" });
    setTimeout(() => sndChime(), outAt + 120);
    setTimeout(() => overlay.remove(), outAt + 640);
    return outAt + 640;
  }

  let submitting = false;
  gn.addEventListener("click", () => {
    if (submitting) return;
    submitting = true;
    const scores = readScores();
    upsertToday(scores);
    const total = dropIntoJar(scores);
    showHint(true);
    gn.animate(
      [{ transform: "scale(1)" }, { transform: "scale(.97)" }, { transform: "scale(1)" }],
      { duration: 400, easing: "ease" }
    );
    renderJars();
    renderInsights();
    setTimeout(() => { submitting = false; }, total);
  });

  /* ───────────────────────── theme ───────────────────────── */
  const root = document.documentElement;
  const toggle = $("#themeToggle");
  const ttIcon = $(".tt-icon", toggle);

  function applyTheme(t, persist) {
    const dark = t === "dark";
    root.setAttribute("data-theme", t);
    ttIcon.textContent = dark ? "☀️" : "🌙";
    document.body.classList.toggle("show-nums", dark);
    gnText.textContent = dark ? "晚安啦" : "Good night";
    const m = $("meta[name=theme-color]");
    if (m) m.setAttribute("content", dark ? "#0c1026" : "#f3e9dc");
    if (persist) { try { localStorage.setItem(LS_THEME, t); } catch {} }
  }
  const sysDark = window.matchMedia("(prefers-color-scheme: dark)");
  toggle.addEventListener("click", () => {
    applyTheme(root.getAttribute("data-theme") === "dark" ? "light" : "dark", true);
    toggle.animate(
      [{ transform: "scale(1) rotate(0)" }, { transform: "scale(.85) rotate(-25deg)" }, { transform: "scale(1) rotate(0)" }],
      { duration: 360, easing: "ease" }
    );
  });
  // if the user hasn't manually chosen, keep following the system theme live
  if (sysDark.addEventListener) {
    sysDark.addEventListener("change", (e) => {
      let chosen = null; try { chosen = localStorage.getItem(LS_THEME); } catch {}
      if (!chosen) applyTheme(e.matches ? "dark" : "light", false);
    });
  }

  /* ───────────────────────── tabs ───────────────────────── */
  const tabs = $$(".tab");
  const pages = $$(".page");
  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      const target = tab.dataset.tab;
      tabs.forEach((t) => t.classList.toggle("is-active", t === tab));
      pages.forEach((p) => p.classList.toggle("is-active", p.dataset.page === target));
      if (target === "trends") {
        renderJars();
        renderInsights();
        startPhysics();
        requestMotionPermission();
      }
    });
  });

  /* ───────────────────────── range pills ───────────────────────── */
  $$(".range-pill").forEach((pill) => {
    pill.addEventListener("click", () => {
      $$(".range-pill").forEach((p) => p.classList.toggle("is-on", p === pill));
      currentRange = pill.dataset.range;
      renderJars();
      renderInsights();
      startPhysics();
    });
  });

  /* ───────────────────────── bead rise keyframes ───────────────────────── */
  const kf = document.createElement("style");
  kf.textContent = "@keyframes beadRise{from{transform:translateY(16px) scale(.4);opacity:0}to{transform:none}}";
  document.head.appendChild(kf);

  /* ═══════════════════════════════════════════════════════════
     Jar Physics — gravity-responsive bead motion
     Shake your phone → beads rattle inside the glass jars.
     Desktop fallback: subtle idle float animation.
     ═══════════════════════════════════════════════════════════ */
  const PHYS = {
    damping: 0.94,
    gravityScale: 580,
    restitution: 0.32,
    idleThreshold: 0.15,
  };

  let physJars = [];       // { jarEl, beads:[{el,x,y,vx,vy,r}], w, h, topR, botR }
  let physRaf = null;
  let motionG = { x: 0, y: 0.3 }; // default: gentle downward gravity
  let lastMotionT = 0;
  let hasSensor = false;

  /* ---- rounded-rect corner distance ---- */
  function cornerDist(bx, by, cx, cy, beadR, cornerR) {
    const dx = bx - cx, dy = by - cy;
    const d = Math.sqrt(dx * dx + dy * dy);
    return cornerR - beadR - d; // positive = still inside, negative = penetration
  }
  function pushOut(bead, cx, cy, nx, ny, margin) {
    bead.x = cx + nx * margin;
    bead.y = cy + ny * margin;
    const dot = bead.vx * nx + bead.vy * ny;
    if (dot < 0) {
      bead.vx -= (1 + PHYS.restitution) * dot * nx;
      bead.vy -= (1 + PHYS.restitution) * dot * ny;
    }
  }

  /* ---- collide bead vs jar walls (rounded rect) ---- */
  function jarCollide(b, jar) {
    const { w, h, topR, botR } = jar;
    const { x, y, r } = b;
    let collided = false;

    // top-left corner
    const tl = cornerDist(x, y, topR, topR, r, topR);
    if (tl < 0) {
      const d = Math.sqrt((x - topR) ** 2 + (y - topR) ** 2) || 0.01;
      pushOut(b, topR, topR, (x - topR) / d, (y - topR) / d, topR - r);
      collided = true;
    }
    // top-right corner
    const tr = cornerDist(x, y, w - topR, topR, r, topR);
    if (tr < 0) {
      const d = Math.sqrt((x - (w - topR)) ** 2 + (y - topR) ** 2) || 0.01;
      pushOut(b, w - topR, topR, (x - (w - topR)) / d, (y - topR) / d, topR - r);
      collided = true;
    }
    // bottom-left corner
    const bl = cornerDist(x, y, botR, h - botR, r, botR);
    if (bl < 0) {
      const d = Math.sqrt((x - botR) ** 2 + (y - (h - botR)) ** 2) || 0.01;
      pushOut(b, botR, h - botR, (x - botR) / d, (y - (h - botR)) / d, botR - r);
      collided = true;
    }
    // bottom-right corner
    const br = cornerDist(x, y, w - botR, h - botR, r, botR);
    if (br < 0) {
      const d = Math.sqrt((x - (w - botR)) ** 2 + (y - (h - botR)) ** 2) || 0.01;
      pushOut(b, w - botR, h - botR, (x - (w - botR)) / d, (y - (h - botR)) / d, botR - r);
      collided = true;
    }

    // straight walls (only when outside corner radius zone)
    const inTopCorner = y < topR && (x < topR || x > w - topR);
    const inBotCorner = y > h - botR && (x < botR || x > w - botR);

    if (!inTopCorner && !inBotCorner) {
      if (x - r < 0) { b.x = r; b.vx = Math.abs(b.vx) * PHYS.restitution; collided = true; }
      if (x + r > w) { b.x = w - r; b.vx = -Math.abs(b.vx) * PHYS.restitution; collided = true; }
      if (y - r < 0) { b.y = r; b.vy = Math.abs(b.vy) * PHYS.restitution; collided = true; }
      if (y + r > h) { b.y = h - r; b.vy = -Math.abs(b.vy) * PHYS.restitution;
        if (Math.abs(b.vy) < 2) b.vx *= 0.8; // floor friction
        collided = true;
      }
    }
    return collided;
  }

  /* ---- initialise physics for a single jar ---- */
  function initJarPhysics(jarEl) {
    const glass = jarEl.querySelector(".jar-glass");
    const fill = jarEl.querySelector(".jar-fill");
    const beads = fill.querySelectorAll(".bead");
    if (!beads.length) return;

    const w = glass.clientWidth;
    const h = glass.clientHeight;

    // CSS border-radius: 9px 9px 30px 30px
    const topR = 9, botR = 30;

    const pb = [];
    beads.forEach((el) => {
      const bw = parseFloat(el.style.width);
      const bl = parseFloat(el.style.left);
      const bt = parseFloat(el.style.top);
      const r = bw / 2;
      pb.push({ el, r, x: bl + r, y: bt + r, vx: 0, vy: 0 });
    });

    // deduplicate by jar
    physJars = physJars.filter((p) => p.jarEl !== jarEl);
    physJars.push({ jarEl, beads: pb, w, h, topR, botR });
  }

  /* ---- physics animation loop ---- */
  function physTick(ts) {
    if (!physTick._prev) physTick._prev = ts;
    const dt = Math.min((ts - physTick._prev) / 1000, 0.04);
    physTick._prev = ts;

    const idle = hasSensor
      ? ts - lastMotionT > 2500
      : false; // desktop: never goes idle (runs idle float)

    // Bail if idle & all beads at rest
    if (idle) {
      const anyMotion = physJars.some((j) =>
        j.beads.some((b) => Math.abs(b.vx) > PHYS.idleThreshold || Math.abs(b.vy) > PHYS.idleThreshold)
      );
      if (!anyMotion) {
        document.getElementById("jars")?.classList.remove("jars--shaking");
        physRaf = null;
        return;
      }
    }

    const gx = motionG.x * PHYS.gravityScale;
    const gy = motionG.y * PHYS.gravityScale;

    for (const jar of physJars) {
      for (const b of jar.beads) {
        b.vx += gx * dt;
        b.vy += gy * dt;
        b.vx *= PHYS.damping;
        b.vy *= PHYS.damping;
        b.x += b.vx * dt;
        b.y += b.vy * dt;
        jarCollide(b, jar);

        // clamp to jar bounds (safety)
        b.x = clamp(b.x, b.r, jar.w - b.r);
        b.y = clamp(b.y, b.r, jar.h - b.r);

        b.el.style.left = b.x - b.r + "px";
        b.el.style.top = b.y - b.r + "px";
      }
    }

    physRaf = requestAnimationFrame(physTick);
  }

  function startPhysics() {
    // Wait for bead rise animations to complete, then init
    setTimeout(() => {
      $$(".jar").forEach((jar) => initJarPhysics(jar));
      if (!physRaf) {
        physTick._prev = performance.now();
        physRaf = requestAnimationFrame(physTick);
      }
    }, 650);
  }

  /* ---- gyro / accelerometer ---- */
  function onMotion(e) {
    const g = e.accelerationIncludingGravity;
    if (!g || g.x == null) return;
    hasSensor = true;
    motionG.x = clamp(g.x / 9.81, -1, 1);
    motionG.y = clamp(g.y / 9.81, -1, 1);
    lastMotionT = performance.now();
    // add a gentle visual cue that shaking is working
    if (Math.abs(g.x) > 3 || Math.abs(g.y) > 5) {
      document.getElementById("jars")?.classList.add("jars--shaking");
    }
  }

  function requestMotionPermission() {
    if (typeof DeviceMotionEvent === "undefined") return;
    if (typeof DeviceMotionEvent.requestPermission === "function") {
      // iOS 13+ — request silently
      DeviceMotionEvent.requestPermission()
        .then((r) => {
          if (r === "granted") {
            window.addEventListener("devicemotion", onMotion, { passive: true });
            hasSensor = true;
          }
        })
        .catch(() => {});
    } else {
      // Android / desktop — just listen
      window.addEventListener("devicemotion", onMotion, { passive: true });
      hasSensor = true;
    }
  }

  /* ───────────────────────── init ───────────────────────── */
  let savedTheme = null;
  try { savedTheme = localStorage.getItem(LS_THEME); } catch {}
  applyTheme(savedTheme || (sysDark.matches ? "dark" : "light"), false);

  renderDate();
  renderQuotes();

  const t = todayEntry();
  if (t) { applyScores(t); showHint(false); }

  requestAnimationFrame(() => requestAnimationFrame(() => { renderJars(); renderInsights(); }));
  window.addEventListener("resize", renderJars);
})();
