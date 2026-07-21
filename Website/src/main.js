import "./styles.css";

const icon = (name, className = "") => {
  const icons = {
    arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    phone: '<rect x="6" y="2" width="12" height="20" rx="3"/><path d="M10 18h4"/>',
    watch: '<rect x="6" y="6" width="12" height="12" rx="4"/><path d="M9 6V2h6v4M9 18v4h6v-4"/>',
    play: '<path d="m9 7 8 5-8 5V7Z" fill="currentColor" stroke="none"/>',
    menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    close: '<path d="m6 6 12 12M18 6 6 18"/>',
    sound: '<path d="M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4"/>',
    at: '<circle cx="12" cy="12" r="8"/><path d="M16 12v2a2 2 0 0 0 4 0v-2a8 8 0 1 0-3.2 6.4"/><circle cx="12" cy="12" r="3"/>',
    question: '<circle cx="12" cy="12" r="9"/><path d="M9.8 9a2.4 2.4 0 1 1 3.4 2.2c-.8.4-1.2.9-1.2 1.8M12 16.5h.01"/>',
    alert: '<path d="M12 3 2.8 20h18.4L12 3Z"/><path d="M12 9v4M12 16.5h.01"/>',
    transcript: '<path d="M6 3h9l3 3v15H6V3Z"/><path d="M14 3v4h4M9 11h6M9 15h6"/>',
    lock: '<rect x="5" y="10" width="14" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3"/>',
    cloud: '<path d="M6 18h11a4 4 0 0 0 .7-7.9A6 6 0 0 0 6.2 8.7 4.7 4.7 0 0 0 6 18Z"/><path d="m9 14 2 2 4-4"/>'
  };
  return `<svg class="icon ${className}" aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${icons[name]}</svg>`;
};

document.querySelector("#app").innerHTML = `
  <header class="site-header" data-header>
    <a class="brand" href="#top" aria-label="Mochi home">
      <span class="brand-mark"><img src="/mochi-mascot.png" alt="" /></span>
      <span>Mochi</span>
    </a>
    <nav class="desktop-nav" aria-label="Main navigation">
      <a href="#how-it-helps">How it helps</a>
      <a href="#built-with-care">Built with care</a>
      <a href="#technology">Technology</a>
    </nav>
    <a class="button button-small desktop-cta" href="#how-it-helps">See how it works</a>
    <button class="menu-button" type="button" aria-label="Open menu" aria-expanded="false" data-menu-button>
      ${icon("menu", "menu-open")}
      ${icon("close", "menu-close")}
    </button>
    <nav class="mobile-nav" aria-label="Mobile navigation" data-mobile-nav>
      <a href="#how-it-helps">How it helps</a>
      <a href="#built-with-care">Built with care</a>
      <a href="#technology">Technology</a>
      <a class="button button-small" href="#how-it-helps">See how it works</a>
    </nav>
  </header>

  <main id="main">
    <section class="hero section" id="top">
      <div class="hero-copy reveal">
        <h1>Stay in the<br />conversation.</h1>
        <p class="hero-lede">Mochi helps people who are hard of hearing follow what’s happening now—and confidently revisit what they missed later.</p>
        <div class="hero-actions">
          <a class="button" href="#how-it-helps">See how Mochi helps ${icon("arrow")}</a>
          <span class="device-line">${icon("phone")}${icon("watch")} For iPhone + Apple Watch</span>
        </div>
      </div>

      <div class="hero-product reveal" aria-label="Mochi live conversation preview">
        <div class="leaf-sketch leaf-one" aria-hidden="true"></div>
        <div class="phone-shell hero-phone">
          <div class="phone-screen">
            <div class="dynamic-island"></div>
            <div class="phone-bar"><span class="live-dot"></span><strong>Live conversation</strong><span>•••</span></div>
            <div class="caption-list">
              <article class="caption">
                <div><strong>Sam</strong><time>9:41</time></div>
                <p>Thanks for joining today. Let’s get started.</p>
              </article>
              <article class="caption">
                <div><strong>Jordan</strong><time>9:41</time></div>
                <p>Absolutely! I’ve been looking forward to this update.</p>
              </article>
              <article class="caption caption-active">
                <div><strong>Taylor</strong><time>9:42</time></div>
                <p>I’ll walk through the highlights first.</p>
              </article>
            </div>
            <div class="listening-bar">
              <div class="wave">${Array.from({ length: 21 }, (_, index) => `<i style="--h:${12 + ((index * 13) % 23)}px"></i>`).join("")}</div>
              <span><i></i> Live</span>
            </div>
          </div>
        </div>

        <div class="watch-shell hero-watch">
          <div class="watch-screen">
            <span class="watch-time">9:41</span>
            <span class="watch-avatar">J</span>
            <strong>Jordan<br />mentioned you</strong>
            <small>Tap to open</small>
          </div>
        </div>
        <img class="hero-mascot" src="/mochi-mascot.png" alt="Mochi, a hand-drawn white cat mascot" />
      </div>
    </section>

    <section class="workflow section" id="how-it-helps">
      <div class="workflow-intro reveal">
        <h2>Support for the<br />moment you’re in.</h2>
        <p>Follow the conversation live. Catch up without interrupting. Revisit the details with evidence you can check.</p>
      </div>
      <div class="workflow-steps reveal">
        <article>
          <span class="step-icon">${icon("sound")}</span>
          <h3>Follow now</h3>
          <p>See live captions in large, easy-to-read text.</p>
        </article>
        <span class="step-arrow">${icon("arrow")}</span>
        <article>
          <span class="step-icon">${icon("question")}</span>
          <h3>Catch me up</h3>
          <p>Get a private brief without stopping the room.</p>
        </article>
        <span class="step-arrow">${icon("arrow")}</span>
        <article>
          <span class="step-icon">${icon("transcript")}</span>
          <h3>Review with evidence</h3>
          <p>Return to speakers, timestamps, and recordings.</p>
        </article>
      </div>
    </section>

    <section class="moments section" aria-labelledby="moments-title">
      <div class="moments-visual reveal">
        <div class="phone-shell moments-phone">
          <div class="phone-screen">
            <div class="dynamic-island"></div>
            <div class="phone-bar phone-bar-simple"><span>‹</span><strong>Project sync</strong><span>⌁</span></div>
            <div class="mini-caption-list">
              <article><time>12:45</time><div><small>Taylor</small><p>Let’s get started. <mark>Jordan</mark>, can you share the latest numbers?</p></div></article>
              <article><time>12:47</time><div><small>Jordan</small><p>Sure thing. Overall we’re ahead of plan by 8%.</p></div></article>
              <article class="question-row"><time>12:48</time><div><small>Alex</small><p>Mochi, does Thursday at 10 work for the roadmap review?</p></div><span>?</span></article>
              <article><time>12:50</time><div><small>Priya</small><p>One more thing—security sign-off is due Friday.</p></div><span class="coral">!</span></article>
            </div>
            <div class="mini-listening">${icon("sound")} <span>Listening<br /><small>English</small></span><b></b></div>
          </div>
        </div>
        <div class="watch-shell moments-watch">
          <div class="watch-screen">
            <span class="watch-time">9:41</span>
            <img src="/mochi-mascot.png" alt="" />
            <strong>Jordan asked if<br />Thursday at 10 works.</strong>
            <small>View in iPhone</small>
          </div>
        </div>
      </div>
      <div class="moments-copy reveal">
        <h2 id="moments-title">More than a<br />wall of captions.</h2>
        <p>Mochi notices the conversational moments that matter: when your name is mentioned, when a question needs your response, and when a detail deserves a second look.</p>
        <ul class="signal-list">
          <li><span class="signal mint">${icon("at")}</span><strong>Name mentions</strong></li>
          <li><span class="signal mint">${icon("question")}</span><strong>Questions for you</strong></li>
          <li><span class="signal coral">${icon("alert")}</span><strong>Important details</strong></li>
        </ul>
      </div>
    </section>

    <section class="evidence section" id="built-with-care">
      <div class="evidence-heading reveal">
        <h2>AI that shows its work.</h2>
        <p>Catch-ups and recaps link back to real transcript moments, so you can check the speaker, timestamp, and recording instead of taking a summary on faith.</p>
      </div>
      <div class="evidence-demo reveal" data-evidence-demo>
        <div class="catchup-panel">
          <h3>Catch me up</h3>
          <button class="catchup-item active" type="button" data-evidence="question">
            <span><small>Open question</small>Jordan asked if Thursday at 10 works.</span>${icon("arrow")}
          </button>
          <button class="catchup-item" type="button" data-evidence="decision">
            <span><small>Decision</small>The team is ahead of plan by 8%.</span>${icon("arrow")}
          </button>
          <button class="catchup-item" type="button" data-evidence="action">
            <span><small>Action</small>Security sign-off is due Friday.</span>${icon("arrow")}
          </button>
        </div>
        <div class="transcript-panel">
          <div class="transcript-line"><time>12:45</time><span><small>Taylor</small>Let’s get started. Jordan, can you share the latest numbers?</span></div>
          <div class="transcript-line" data-line="decision"><time>12:47</time><span><small>Jordan</small>Sure thing. Overall we’re ahead of plan by 8%.</span></div>
          <div class="transcript-line active" data-line="question"><time>12:48</time><span><small>Alex</small>Mochi, does Thursday at 10 work for the roadmap review?</span></div>
          <div class="transcript-line" data-line="action"><time>12:50</time><span><small>Priya</small>One more thing—security sign-off is due Friday.</span></div>
        </div>
        <div class="source-panel" aria-live="polite">
          <p data-source-copy>Jordan asked if Thursday at 10 works.</p>
          <a href="#evidence-source" data-source-link>View in transcript ${icon("arrow")}</a>
          <div class="playback"><span data-source-time>12:48</span><div><i></i></div></div>
          <button type="button" class="play-button" data-play>${icon("play")} <span>Play from here</span></button>
        </div>
      </div>
    </section>

    <section class="privacy section" id="technology">
      <div class="privacy-heading reveal">
        <h2>Private by choice.<br />Helpful by design.</h2>
        <div class="privacy-sketch" aria-hidden="true">
          <i></i>${icon("lock")}<i></i>
        </div>
      </div>
      <div class="privacy-columns reveal">
        <article>
          <span>${icon("phone")}</span>
          <div><h3>On-device option</h3><p>Use multilingual Whisper captions locally when you want conversation audio to stay on your iPhone.</p></div>
        </article>
        <article>
          <span>${icon("cloud")}</span>
          <div><h3>Cloud when it helps</h3><p>OpenAI powers low-latency captions and grounded catch-ups when you choose the connected experience.</p></div>
        </article>
      </div>
      <p class="assistive-note reveal">Mochi is an assistive prototype, not a medical device or a replacement for professional captioning services.</p>
    </section>

    <section class="closing section">
      <div class="closing-copy reveal">
        <h2>The conversation keeps moving. Mochi helps you move with it.</h2>
        <div class="closing-actions">
          <a class="button button-mint" href="#top">See how Mochi works ${icon("arrow")}</a>
          <span class="device-line">${icon("phone")}${icon("watch")} Built for iPhone + Apple Watch</span>
        </div>
      </div>
      <div class="mascot-peek reveal"><img src="/mochi-mascot.png" alt="Mochi peeking around the edge" /></div>
    </section>
  </main>

  <footer class="site-footer">
    <a class="brand footer-brand" href="#top">
      <span class="brand-mark"><img src="/mochi-mascot.png" alt="" /></span>
      <span><strong>Mochi</strong><small>Stay in the conversation.</small></span>
    </a>
    <nav aria-label="Footer navigation">
      <a href="#how-it-helps">How it helps</a>
      <a href="#built-with-care">Built with care</a>
      <a href="#technology">Technology</a>
      <a href="#technology">Privacy</a>
    </nav>
    <p>Built with care for OpenAI Build Week.</p>
  </footer>
`;

const menuButton = document.querySelector("[data-menu-button]");
const mobileNav = document.querySelector("[data-mobile-nav]");

menuButton.addEventListener("click", () => {
  const open = menuButton.getAttribute("aria-expanded") === "true";
  menuButton.setAttribute("aria-expanded", String(!open));
  mobileNav.classList.toggle("open", !open);
});

mobileNav.querySelectorAll("a").forEach((link) => {
  link.addEventListener("click", () => {
    menuButton.setAttribute("aria-expanded", "false");
    mobileNav.classList.remove("open");
  });
});

const evidenceContent = {
  question: { copy: "Jordan asked if Thursday at 10 works.", time: "12:48" },
  decision: { copy: "The team is ahead of plan by 8%.", time: "12:47" },
  action: { copy: "Security sign-off is due Friday.", time: "12:50" }
};

const evidenceButtons = document.querySelectorAll("[data-evidence]");
const sourceCopy = document.querySelector("[data-source-copy]");
const sourceTime = document.querySelector("[data-source-time]");
const sourceLink = document.querySelector("[data-source-link]");

evidenceButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const key = button.dataset.evidence;
    evidenceButtons.forEach((item) => item.classList.toggle("active", item === button));
    document.querySelectorAll("[data-line]").forEach((line) => line.classList.toggle("active", line.dataset.line === key));
    sourceCopy.textContent = evidenceContent[key].copy;
    sourceTime.textContent = evidenceContent[key].time;
    sourceLink.onclick = (event) => {
      event.preventDefault();
      document.querySelector(`[data-line="${key}"]`).focus({ preventScroll: true });
    };
  });
});

const playButton = document.querySelector("[data-play]");
playButton.addEventListener("click", () => {
  const playing = playButton.classList.toggle("playing");
  playButton.querySelector("span").textContent = playing ? "Playing…" : "Play from here";
  window.setTimeout(() => {
    playButton.classList.remove("playing");
    playButton.querySelector("span").textContent = "Play from here";
  }, 2400);
});

const header = document.querySelector("[data-header]");
const updateHeader = () => header.classList.toggle("scrolled", window.scrollY > 20);
updateHeader();
window.addEventListener("scroll", updateHeader, { passive: true });

if ("IntersectionObserver" in window && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  document.querySelectorAll(".reveal").forEach((element) => observer.observe(element));
} else {
  document.querySelectorAll(".reveal").forEach((element) => element.classList.add("visible"));
}
