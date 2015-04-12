# Seeds for epic runs

PokéBot comes with a built-in run recording feature that takes advantage of random number seeding to reproduce runs in their entirety. Any time the bot resets or beats the game, it logs a number to the Lua console that is the seed for the run. This seed allows you to easily share the run with others.

Have you found a seed that results in a run of 1:52:00 or better? [Let us know](https://github.com/kylecoburn/PokeBot/issues/4), and we’ll add it to the list!

| Time    | Frames | Seed         | Bot version | Found by                                     |
|---------|--------|--------------|-------------|----------------------------------------------|
| 1:50:36 | 398208 | `1428414915` | v1.4.0      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:37 | 398226 | `1428414915` | v1.3.0      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:55 | 399355 | `1428801658` | v1.4.0      | [Marcin1503](https://github.com/Marcin1503)  |

To reproduce any of these runs, set [`CUSTOM_SEED` in `main.lua`](https://github.com/kylecoburn/PokeBot/blob/0fd1258ca17f7d74edbac72fa0afc2b5c6d58bb3/main.lua#L5) to the seed number and run the bot.
