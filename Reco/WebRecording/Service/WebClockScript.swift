//
//  WebClockScript.swift
//  Reco
//

import Foundation

/// The script a take injects into the page at document start, in the page's own world so its
/// globals are the ones the page uses. It gives the page a clock of its own, then lets the renderer
/// step it one frame at a time (spec 0005).
///
/// - The clock replaces `requestAnimationFrame`, `setTimeout`, `setInterval`, `Date` and
///   `performance.now`, and pauses and seeks the page's animations and transitions on the document
///   timeline. It follows real time until ``WebPageRenderer`` freezes it: a clock frozen while the
///   page loads broke linear.app.
/// - Timers set inside a timer wait at least 4 ms, as browsers make nested ones, so a zero-delay
///   chain can't spin forever inside one frame.
/// - An animation is finished, not just seeked, at its end, so `transitionend` and `animationend`
///   fire: a paused animation never ends by itself. One the page pauses, with `pause()` or CSS
///   `animation-play-state`, holds its time.
/// - A frame waits up to 5 s for the images in view and the fonts to load; what misses that isn't
///   waited for again.
/// - Media plays on the clock too (spec 0010, step 1): once frozen, every `<video>` and `<audio>` the
///   page plays is really paused, and each frame seeks the ones in view to where they'd be, looping
///   at their rate, waiting for `seeked` up to 5 s like images. `play()`, `pause()`, `paused`,
///   `timeupdate` and `ended` behave for the page as if it played. One with nothing loaded yet, like
///   `preload="none"`, is loaded first.
/// - `window.__reco` holds what the renderer calls: `frame(time, x, y, selectors)` freezes
///   the clock at the take's `time` on its first call, then steps it, and returns the selectors'
///   boxes and the page's height; it returns `null` while a new page is still loading.
///   `hold(x, y, selector)` seeks animations the pointer just started, names the cursor there and,
///   given the selector the cursor aims at, what covers its element at that point.
enum WebClockScript {

    static let source = #"""
    (() => {
      if (window.__reco) return;
      const realNow = performance.now.bind(performance);
      const realFrame = window.requestAnimationFrame.bind(window);
      const realTimeout = window.setTimeout.bind(window);
      const RealDate = Date;
      const epoch = RealDate.now() - realNow();
      let now = realNow();
      let base = null;
      let inTimer = false;
      let nextID = 1;
      const frames = new Map();
      const timers = new Map();
      const origins = new WeakMap();
      const stalled = new WeakSet();
      let fontsStalled = false;

      function ClockDate(...args) {
        if (!new.target) return new RealDate(epoch + now).toString();
        return Reflect.construct(RealDate, args.length ? args : [epoch + now], new.target);
      }
      ClockDate.prototype = RealDate.prototype;
      ClockDate.now = () => epoch + now;
      ClockDate.parse = RealDate.parse;
      ClockDate.UTC = RealDate.UTC;
      window.Date = ClockDate;
      performance.now = () => now;

      const tick = () => { if (base === null) advance(realNow()); };
      const pump = () => { if (base === null) { tick(); realFrame(pump); } };
      realFrame(pump);

      window.requestAnimationFrame = (callback) => { const id = nextID++; frames.set(id, callback); return id; };
      window.cancelAnimationFrame = (id) => { frames.delete(id); };
      const schedule = (callback, delay, args, repeats) => {
        const wait = Math.max(inTimer ? 4 : 0, Number(delay) || 0);
        const id = nextID++;
        timers.set(id, { due: now + wait, callback, args, interval: repeats ? Math.max(wait, 4) : 0 });
        if (base === null) realTimeout(tick, wait);
        return id;
      };
      window.setTimeout = (callback, delay, ...args) => schedule(callback, delay, args, false);
      window.setInterval = (callback, delay, ...args) => schedule(callback, delay, args, true);
      window.clearTimeout = window.clearInterval = (id) => { timers.delete(id); };

      const run = (callback, args) => {
        try { typeof callback === 'function' ? callback(...args) : (0, eval)(String(callback)); } catch (error) { console.error(error); }
      };

      function advance(to) {
        for (;;) {
          let id = 0, timer = null;
          for (const [key, candidate] of timers) {
            if (candidate.due <= to && (!timer || candidate.due < timer.due)) { id = key; timer = candidate; }
          }
          if (!timer) break;
          now = Math.max(now, timer.due);
          if (timer.interval) timer.due += timer.interval; else timers.delete(id);
          inTimer = true;
          run(timer.callback, timer.args);
          inTimer = false;
        }
        now = Math.max(now, to);
        const callbacks = [...frames.values()];
        frames.clear();
        for (const callback of callbacks) run(callback, [now]);
        syncAnimations();
      }

      // Pausing an animation to step it hides the page's own pauses, so they're kept here: pause()
      // and play() calls, and CSS animation-play-state read from the element's style
      const realPause = Animation.prototype.pause;
      const realPlay = Animation.prototype.play;
      const pausedByPage = new WeakSet();
      Animation.prototype.pause = function () { pausedByPage.add(this); return realPause.call(this); };
      Animation.prototype.play = function () { pausedByPage.delete(this); return realPlay.call(this); };
      const pausedByStyle = (animation) => {
        const target = animation.effect?.target;
        if (!(animation instanceof CSSAnimation) || !target) return false;
        const style = getComputedStyle(target, animation.effect.pseudoElement);
        const states = style.animationPlayState.split(', ');
        const index = style.animationName.split(', ').indexOf(animation.animationName);
        return index >= 0 && states[index % states.length] === 'paused';
      };

      function syncAnimations() {
        for (const animation of document.getAnimations()) {
          const rate = animation.playbackRate;
          if (animation.timeline !== document.timeline || !(rate > 0)) continue;
          const known = origins.has(animation);
          if (animation.playState === 'running') {
            // New, or played again by the page, it goes on from its current time. A new one starts
            // now once the clock is frozen; before, it keeps its real start
            origins.set(animation, now - (known || base === null ? (animation.currentTime ?? 0) / rate : 0));
            realPause.call(animation);
          } else if (!known || animation.playState === 'finished') {
            continue;
          } else if (pausedByPage.has(animation) || pausedByStyle(animation)) {
            // Held where the page paused it, to go on from there when it plays again
            origins.set(animation, now - animation.currentTime / rate);
            continue;
          }
          const local = (now - origins.get(animation)) * rate;
          const end = animation.effect ? animation.effect.getComputedTiming().endTime : Infinity;
          if (local >= end) animation.finish(); else animation.currentTime = local;
        }
      }

      // Media the page plays, once the clock is frozen: its time at clock time `at`
      const realMediaPlay = HTMLMediaElement.prototype.play;
      const realMediaPause = HTMLMediaElement.prototype.pause;
      const realPaused = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'paused').get;
      const playing = new Map();
      const mediaStalled = new WeakSet();
      const mediaLoading = new WeakSet();
      const start = (media) => {
        playing.set(media, { time: media.currentTime, at: now });
        realMediaPause.call(media);
      };
      HTMLMediaElement.prototype.play = function () {
        if (base === null) return realMediaPlay.call(this);
        if (!playing.has(this)) {
          start(this);
          for (const type of ['play', 'playing']) this.dispatchEvent(new Event(type));
        }
        return Promise.resolve();
      };
      HTMLMediaElement.prototype.pause = function () {
        if (!playing.delete(this)) return realMediaPause.call(this);
        this.dispatchEvent(new Event('pause'));
      };
      Object.defineProperty(HTMLMediaElement.prototype, 'paused', {
        configurable: true,
        get() { return playing.has(this) ? false : realPaused.call(this); }
      });

      // Where each playing medium in view should be at `now`: seeked there, waited for
      async function syncMedia() {
        // What started by itself, like an autoplay element that loaded after the freeze
        for (const media of document.querySelectorAll('video, audio')) {
          if (!playing.has(media) && !realPaused.call(media)) start(media);
        }
        const seeks = [];
        for (const [media, state] of playing) {
          let time = state.time + (now - state.at) / 1000 * (media.playbackRate || 1);
          const duration = media.duration;
          if (duration > 0 && Number.isFinite(duration)) {
            if (media.loop) {
              time %= duration;
            } else if (time >= duration) {
              playing.delete(media);
              media.currentTime = duration;
              media.dispatchEvent(new Event('ended'));
              continue;
            }
          }
          if (!media.isConnected || !(media instanceof HTMLVideoElement) || !inView(media)) continue;
          seeks.push(seek(media, time));
          media.dispatchEvent(new Event('timeupdate'));
        }
        if (!seeks.length) return;
        const timeout = new Promise((resolve) => realTimeout(resolve, 5000, false));
        if (await Promise.race([Promise.all(seeks).then(() => true), timeout])) return;
        for (const [media] of playing) if (media.seeking) mediaStalled.add(media);
      }

      // Resolves once `media` shows `time`; one that stalled before isn't waited for again
      const seek = (media, time) => new Promise((resolve) => {
        const go = () => {
          if (Math.abs(media.currentTime - time) < 0.0005 && !media.seeking) return resolve();
          media.addEventListener('seeked', resolve, { once: true });
          media.currentTime = time;
          if (mediaStalled.has(media)) resolve();
        };
        if (media.readyState >= HTMLMediaElement.HAVE_METADATA) return go();
        if (!mediaLoading.has(media)) {
          mediaLoading.add(media);
          media.preload = 'auto';
          if (media.networkState !== HTMLMediaElement.NETWORK_LOADING) media.load();
        }
        media.addEventListener('loadedmetadata', go, { once: true });
        if (mediaStalled.has(media)) resolve();
      });

      const settle = () => new Promise((resolve) => realFrame(() => realTimeout(resolve, 0)));
      const inView = (element) => {
        const box = element.getBoundingClientRect();
        return box.width > 0 && box.bottom > 0 && box.right > 0 && box.top < innerHeight && box.left < innerWidth;
      };

      // Images in view and fonts get up to 5 s a frame to load. What doesn't load in time isn't
      // waited for again, so a request that hangs can't stall every frame.
      async function loadInView() {
        fontsStalled &&= document.fonts.status === 'loading';
        const images = [...document.images].filter((image) => !image.complete && !stalled.has(image) && inView(image));
        const loads = images.map((image) => image.decode().catch(() => {}));
        if (!fontsStalled) loads.push(document.fonts.ready);
        const timeout = new Promise((resolve) => realTimeout(resolve, 5000, false));
        if (await Promise.race([Promise.all(loads).then(() => true), timeout])) return;
        for (const image of images) if (!image.complete) stalled.add(image);
        fontsStalled = document.fonts.status === 'loading';
      }

      const textFields = 'textarea, input:not([type]), ' +
        ['text', 'search', 'email', 'url', 'password', 'tel', 'number'].map((type) => `input[type=${type}]`).join(', ');

      function cursorAt(x, y) {
        const element = document.elementFromPoint(x, y);
        if (!element) return 'default';
        const cursor = getComputedStyle(element).cursor;
        if (cursor !== 'auto') return cursor;
        if (element.closest('a[href], area[href]')) return 'pointer';
        if (element.isContentEditable || element.matches(textFields)) return 'text';
        if (getComputedStyle(element).webkitUserSelect === 'none') return 'default';
        const caret = document.caretRangeFromPoint(x, y);
        if (caret && caret.startContainer.nodeType === Node.TEXT_NODE) {
          const range = document.createRange();
          range.selectNodeContents(caret.startContainer);
          for (const box of range.getClientRects()) {
            if (x >= box.left && x <= box.right && y >= box.top && y <= box.bottom) return 'text';
          }
        }
        return 'default';
      }

      const find = (selector) => { try { return document.querySelector(selector); } catch { return null; } };
      const describe = (element) => {
        const name = element.localName + (element.id ? '#' + element.id : '') + [...element.classList].slice(0, 2).map((name) => '.' + name).join('');
        const text = (element.getAttribute('aria-label') || element.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 40);
        return text ? `${name} ("${text}")` : name;
      };

      Object.defineProperty(window, '__reco', { value: {
        freeze(time) {
          if (base !== null) return;
          base = now - time * 1000;
          for (const media of document.querySelectorAll('video, audio')) if (!realPaused.call(media)) start(media);
        },
        async frame(time, scrollX, scrollY, selectors) {
          if (base === null && document.readyState !== 'complete') return null;
          this.freeze(time);
          advance(base + time * 1000);
          window.scrollTo({ left: scrollX, top: scrollY, behavior: 'instant' });
          await syncMedia();
          await settle();
          await loadInView();
          const boxes = {};
          for (const selector of selectors) {
            const element = find(selector);
            // One that isn't rendered, e.g. display: none, has no box, so the cursor goes to the target's point
            const box = element?.getClientRects().length ? element.getBoundingClientRect() : null;
            boxes[selector] = box ? [box.x, box.y, box.width, box.height] : null;
          }
          return { boxes, height: Math.max(document.documentElement.scrollHeight, document.body?.scrollHeight ?? 0) };
        },
        hold(x, y, selector) {
          syncAnimations();
          if (x === null) return { cursor: 'default', cover: null };
          // What gets the pointer instead of the target, like a menu an earlier hover left open
          const element = selector ? find(selector) : null;
          const hit = element ? document.elementFromPoint(x, y) : null;
          const cover = hit && !element.contains(hit) && !hit.contains(element) ? describe(hit) : null;
          return { cursor: cursorAt(x, y), cover };
        }
      } });
    })();
    """#
}
