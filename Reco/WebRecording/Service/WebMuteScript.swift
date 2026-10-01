//
//  WebMuteScript.swift
//  Reco
//

import Foundation

/// The script a take injects into the page at document start to silence it: the movie has no
/// sound, so a page playing offscreen would only reach the speakers, stuttering, while it renders.
///
/// Media elements are muted when they load, play, or are unmuted by the page. Web Audio reaches the
/// speakers through a silent gain.
enum WebMuteScript {

    static let source = #"""
    (() => {
      const mute = (media) => { if (media instanceof HTMLMediaElement && !media.muted) media.muted = true; };
      for (const type of ['loadstart', 'play', 'volumechange']) addEventListener(type, (event) => mute(event.target), true);
      // Media outside the document, e.g. `new Audio()`, whose events never reach the window
      const play = HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play = function () { mute(this); return play.call(this); };

      const silences = new WeakMap();
      const connect = AudioNode.prototype.connect;
      AudioNode.prototype.connect = function (target, ...rest) {
        if (!(target instanceof AudioDestinationNode)) return connect.call(this, target, ...rest);
        if (!silences.has(target)) {
          const silence = target.context.createGain();
          silence.gain.value = 0;
          connect.call(silence, target);
          silences.set(target, silence);
        }
        connect.call(this, silences.get(target), ...rest);
        return target;
      };
    })();
    """#
}
