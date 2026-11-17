# Deferred pointer handling

Based on [defer_pointer 0.0.2](https://github.com/gskinnerTeam/flutter-defer-pointer),
MIT licensed (see LICENSE).

The local copy orders hit targets by their render tree order rather than their
registration time. An AiScript game may create or update the background grid
after its positioned character; the character must still receive the tap.
