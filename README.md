# hubot-at-oncall

Listens for any mentions of @oncall, looks up the primary on call in PagerDuty, and mentions them to bring their attention to the issue.

See [`src/at-oncall.coffee`](src/at-oncall.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-at-oncall --save`

Then add **hubot-at-oncall** to your `external-scripts.json`:

```json
[
  "hubot-at-oncall"
]
```

## Sample Interactions

```
malcom>> There appears to be something wrong with the engine. @oncall
hubot>> @kaylee ^^^^
kaylee>> Not to fret Cap'n. I'm on it.
```
