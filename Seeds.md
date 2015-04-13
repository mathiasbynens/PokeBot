# Seeds for epic runs

PokéBot comes with a built-in run recording feature that takes advantage of random number seeding to reproduce runs in their entirety. Any time the bot resets or beats the game, it logs a number to the Lua console that is the seed for the run. This seed allows you to easily share the run with others.

Have you found a seed that results in a run of 1:51:30 or better using the bot’s default settings? [Let us know](https://github.com/kylecoburn/PokeBot/issues/4), and we’ll add it to the list!

| Time    | Frames  | Seed         | Nidoran name | Bot version | Found by                                     |
|---------|---------|--------------|--------------|-------------|----------------------------------------------|
| 1:50:11 | 396,858 | `1428898417` | ,            | v1.4.2      | ThePokéBot                                   |
| 1:50:22 | 397,352 | `1428414915` | A            | v1.4.2      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:36 | 398,208 | `1428414915` | A            | v1.4.0      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:37 | 398,226 | `1428414915` | A            | v1.3.0      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:51 | 399,076 | `1428414915` | A            | v1.4.1      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:55 | 399,355 | `1428801658` | A            | v1.4.0      | [Marcin1503](https://github.com/Marcin1503)  |
| 1:50:41 | 398,509 | `1428873163` | A            | v1.4.1      | [Marcin1503](https://github.com/Marcin1503)  |

To reproduce any of these runs, set [`CUSTOM_SEED` in `main.lua`](https://github.com/kylecoburn/PokeBot/blob/27aa1dcd2cec1bbe25607fa346836f63b349ad5f/main.lua#L5) to the seed number, `NIDORAN_NAME` to the matching name, and run the bot.
