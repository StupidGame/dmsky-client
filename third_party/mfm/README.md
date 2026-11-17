# MFM renderer

Based on [mfm 1.0.11+2](https://github.com/shiosyakeyakini-info/mfm_renderer),
Copyright (c) 2023 sorairo, MIT licensed (see LICENSE).

The local copy adds the optional `onClickEv` callback for AiScript Play:
`$[clickable.ev=ID ...]` dispatches ID and keeps nested emoji and links from
consuming the tap. Play supplies a deferred pointer handler so positioned controls
remain interactive outside their original layout bounds.

Animation start timers are cancelled on disposal, and unchanged animation
parameters no longer restart the animation on every game state update.
