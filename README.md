# Rokapi

[Rokapi](https://en.wikipedia.org/wiki/Georgian_mythology#Spirits,_creatures,_and_other_beings) (როკაპი) is an evil spirit in Georgian mythology, chained to a column under the earth.

This is a tabletop-style adventure game narrated by an AI. You build a character, draw a fate card, and play scene by scene: the narrator writes the scene, offers two or three choices, you roll a d20, and the outcome is woven back into the story. Health, inventory and status effects carry through to the finale.

An LLM will happily write prose all day. The hard part is getting it to tell a story worth playing: one that holds an arc, respects the dice, and makes you want the next scene, rather than improvising a fresh reply every turn.

Rokapi is a Rails 8 application: vanilla Rails, Hotwire, SQLite. LLM calls go through [RubyLLM](https://rubyllm.com).


## How a game plays

1. **Setup.** Pick one of three fate cards, each a place, a trouble and a person at the heart of it, or draw again, or take one face down as a surprise. Then a tone (fun, balanced, dark) and a length (7, 12 or 18 scenes).
2. **Character.** Six races, six classes, six backgrounds, and points to spread across six stats.
3. **Scenes.** Every scene ends in two or three choices, each tied to a stat and a target number. You pick one and roll.
4. **Outcomes.** The narrator tells what the roll did and returns its effects: health, what you carry, status effects that weigh on later rolls.
5. **Finale.** The last scene is played like the others, and its roll tells the ending. Your rolls decide victory or defeat, and the last one counts twice.


## The narrator

The narrator does what a good game master does. Each fate card carries a hidden twist only the narrator sees; it settles what really happened and lets it come out a piece at a time. It writes each scene, offers choices that carry real stakes, takes the dice as they fall, and follows the consequences through to the end.

Every scene is written with the whole game in view. The narrator is one conversation per game: it has every scene played so far, your character as they stand right now, and where the story is, early, in the middle or late. The last scene knows what happened in the first.

Every call is logged with its cost. A finished game knows exactly what it cost to tell.


## Running it locally

- Ruby 4.0.1, then `bin/setup`.
- The narrator needs an OpenAI key in the credentials as `openai.api_key`.
- Login is by email with a one-time code; in development the mail is written to `tmp/mails/`.
- `bin/rokapi` plays the game against a running server, one UI step per command (`bin/rokapi help`).
- The iOS and Android apps live in `native/` (`native/README.md`).

### Narrating without an API key

In development, `NARRATOR_COMMAND` hands every narrator call to a command of your own instead of the API: `NARRATOR_COMMAND=~/bin/narrate bin/dev`. The command is run through the shell once per call and gets one JSON object on stdin: `system` (the instructions) and `prompt` (the conversation so far and the turn). It writes the reply to stdout, exactly as the model would write it, and exits 0. Whatever the command writes before it exits streams into the scene as it arrives. These calls are logged as model `understudy` at zero cost. Without the variable, and in every other environment, the narrator calls the API.



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
