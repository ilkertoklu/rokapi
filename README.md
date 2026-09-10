# Rokapi

[Rokapi](https://en.wikipedia.org/wiki/Georgian_mythology#Spirits,_creatures,_and_other_beings) (როკაპი) is an evil spirit in Georgian mythology, chained to a column under the earth.

This is a tabletop-style adventure game narrated by an AI. You build a character, pick a quest, and play scene by scene: the narrator writes the scene, offers three choices, you roll a d20, and the outcome is woven back into the story. Health, inventory and status effects carry through to the finale.

An LLM will happily write prose all day. The hard part is getting it to tell a story worth playing: one that holds an arc, respects the dice, and makes you want the next scene, rather than improvising a fresh reply every turn.

Rokapi is a Rails 8 application: vanilla Rails, Hotwire, SQLite. LLM calls go through [RubyLLM](https://rubyllm.com).


## How a game plays

1. **Setup.** Choose a quest (two hand-written ones, or "surprise" and let the narrator invent a world), a tone (fun, balanced, dark) and a length (7, 12 or 18 scenes).
2. **Character.** Six races, six classes, six backgrounds, and points to spread across six stats.
3. **Story bible.** Before the first scene, the narrator plans the whole arc: who wants what, where it goes wrong, how it can end. Every later scene is written against that plan.
4. **Scenes.** Every scene but the last ends in three choices, each tied to a stat and a target number. You pick one and roll.
5. **Outcomes.** The narrator resolves the roll in a sentence or two and returns structured effects: health, items gained or lost, status effects that modify later rolls.
6. **Finale.** The last scene closes the story. The bible wrote two endings at the start; your rolls decide which one you get.


## The narrator

The narrator does what a good game master does. Before the first scene it plans the adventure: who wants what, what stands in the way, how it could end well and how it could end badly. Then it writes each scene, offers choices that carry real stakes, takes the dice as they fall, and follows the consequences through to the end it set up.

Every scene is written with the whole game in view. The narrator gets the plan, your character as they stand right now, and every scene played so far in full: the text, the choice you made, the roll and what came of it. The last scene knows what happened in the first.

Every call is logged with its cost. A finished game knows exactly what it cost to tell.


## Running it locally

- Ruby 4.0.1, then `bin/setup`.
- The narrator needs an OpenAI key in the credentials as `openai.api_key`.
- Login is by email with a one-time code; in development it lands in the log.
- `script/playtest.rb` plays a whole game from the command line.


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
