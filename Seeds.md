# Seeds for epic runs

PokéBot comes with a built-in run recording feature that takes advantage of random number seeding to reproduce runs in their entirety. Any time the bot resets or beats the game, it logs a number to the Lua console that is the seed for the run. This seed allows you to easily share the run with others. A screenshot is also saved to the `Gameboy\Screenshots` folder in the `Bizhawk` directory.

Have you found a seed that results in a run of 1:51:30 or better using the bot’s default settings, on the latest version? [Let us know](https://github.com/kylecoburn/PokeBot/issues/4), and we’ll add it to the list!

| Time    | Frames  | Seed         | Nidoran name | Bot version | Found by                                     |
|---------|---------|--------------|--------------|-------------|----------------------------------------------|
| 1:48:55 | 392,144 | `1428943783` | A            | v1.4.2      | [KriPet](https://github.com/KriPet)          |
| 1:49:45 | 395,108 |   `91780872` | A            | v1.4.2      | [Mathias](https://mathiasbynens.be/)         |
| 1:49:52 | 395,566 | `1429090390` | A            | v1.4.2      | [Marcin1503](https://github.com/Marcin1503)  |
| 1:50:14 | 396,858 | `1428898417` | ,            | v1.4.2      | ThePokéBot                                   |
| 1:50:22 | 397,352 | `1428414915` | A            | v1.4.2      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:36 | 398,208 | `1428414915` | A            | v1.4.0      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:37 | 398,226 | `1428414915` | A            | v1.3.0      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:39 | 398,349 |   `91764336` | A            | v1.4.2      | [Mathias](https://mathiasbynens.be/)         |
| 1:50:41 | 398,509 | `1428873163` | A            | v1.4.1      | [Marcin1503](https://github.com/Marcin1503)  |
| 1:50:51 | 399,076 | `1428414915` | A            | v1.4.1      | [Gofigga](http://www.twitch.tv/gofigga)      |
| 1:50:51 | 399,085 |   `91806208` | A            | v1.4.2      | [Mathias](https://mathiasbynens.be/)         |
| 1:50:55 | 399,355 | `1428801658` | A            | v1.4.0      | [Marcin1503](https://github.com/Marcin1503)  |
| 1:51:01 | 399,694 |   `91807360` | A            | v1.4.2      | [Mathias](https://mathiasbynens.be/)         |
| 1:51:07 | 400,057 |   `91688624` | A            | v1.4.2      | [Mathias](https://mathiasbynens.be/)         |
| 1:51:23 | 400,988 |   `91753768` | A            | v1.4.2      | [Mathias](https://mathiasbynens.be/)         |

To reproduce any of these runs, set [`CUSTOM_SEED` in `main.lua`](https://github.com/kylecoburn/PokeBot/blob/27aa1dcd2cec1bbe25607fa346836f63b349ad5f/main.lua#L5) to the seed number, `NIDORAN_NAME` to the matching name, and run the bot.
