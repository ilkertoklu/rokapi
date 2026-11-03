# Rokapi

[Rokapi](https://en.wikipedia.org/wiki/Georgian_mythology#Spirits,_creatures,_and_other_beings) (როკაპი) is an evil spirit in Georgian mythology, chained to a column under the earth.

This is a tabletop-style adventure game narrated by an AI. You build a character, draw a fate card, and play scene by scene: the narrator writes the scene, offers two or three choices, you roll a d20, and the outcome is woven back into the story. Health, inventory and status effects carry through to the finale.

An LLM will happily write prose all day. The hard part is getting it to tell a story worth playing: one that holds an arc, respects the dice, and makes you want the next scene, rather than improvising a fresh reply every turn.

Rokapi is a Rails 8 application: vanilla Rails, Hotwire, SQLite. LLM calls go through [RubyLLM](https://rubyllm.com).


## How a game plays

1. **Setup.** Pick a fate card: a place, a trouble and a person. Or take a surprise. Then pick a tone and a length.
2. **Character.** Pick a race, a class and a background, and spread points across six stats.
3. **Scenes.** Each scene ends in two or three choices. You pick one and roll.
4. **Outcomes.** The narrator tells what happened. Your health, items and statuses change with it.
5. **Finale.** The last roll ends the story. Your rolls decide if you win.


## The narrator

The narrator works like a good game master. Each fate card has a hidden twist that only the narrator knows, and the story reveals it bit by bit.

The narrator remembers every scene of the game, so the ending knows what happened at the start.

Every call is logged with its cost. A finished game knows exactly what it cost to tell.


## Running it locally

- Ruby 4.0.1, then `bin/setup`.
- The narrator needs an OpenAI key in the credentials as `openai.api_key`.
- Login is by email with a one-time code; in development the mail is written to `tmp/mails/`.
- `bin/rokapi` plays the game against a running server, one UI step per command (`bin/rokapi help`).
- The iOS and Android apps live in `native/` (`native/README.md`).

### Narrating without an API key

In development you can send narrator calls to your own command instead of the API: `NARRATOR_COMMAND=~/bin/narrate bin/dev`. The command reads a JSON object with `system` and `prompt` on stdin and writes the reply to stdout. These calls cost nothing. Without the variable, the narrator calls the API.



## Tests

```
bin/rails test
```

The suite stubs the LLM; no API key is needed and nothing is sent anywhere.


## Deployment

Rokapi deploys with [Kamal](https://kamal-deploy.org). The configuration in `config/deploy.yml` is a placeholder until the first production deploy.


## Status

Rokapi is a personal side project and very much in progress. Things change without notice. Ideas and bug reports are welcome; open an issue.


## License

Rokapi is released under the [PolyForm Noncommercial License 1.0.0](LICENSE.md).
