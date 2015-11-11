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

## Sample Interaction

```
user1>> hubot hello
hubot>> hello!
```
