# renode-test

A button and an LED on the nRF52840 DK, tested in Renode by a Robot Framework file. The
test presses `sw0`, then checks both the UART line and the level on the `led0` pin. No
board needed, and nothing in the firmware exists only for the test.

```
renode-test/
├── CMakeLists.txt
├── prj.conf
├── run_nrf52.resc      the nRF52840 plus sw0 and led0, wired as on the DK
├── button_led.robot    first press turns led0 on, second turns it off
└── src/main.c          sw0 toggles led0
```

## Run it

```bash
cd apps/renode-test
```

```bash
west build -b nrf52840dk/nrf52840 -p
```

```bash
cd build && renode-test ../button_led.robot
```

`renode-test` writes `log.html`, `report.html`, `robot_output.xml` and `logs/` into the
directory it starts from, so running it from `build/` keeps them out of the source tree.

To press the button by hand, from `apps/renode-test`:

```bash
renode --console --disable-xwt -e "\$elf=@$PWD/build/zephyr/zephyr.elf; include @run_nrf52.resc; start"
```

Then `sysbus.gpio0.sw0 Press` and `sysbus.gpio0.sw0 Release` at the `(nrf52840)` prompt,
and `q` to quit. The first press after boot does nothing, see below.

## Expected outcome

```
+++++ Finished test 'button_led.Should Turn The LED On When sw0 Is Pressed' in 1.49 seconds with status OK
+++++ Finished test 'button_led.Should Turn The LED Off At The Second Press' in 0.81 seconds with status OK
Tests finished successfully :)
```

On a failure, `renode-test` prints every UART line the terminal tester saw and saves
Renode's log as `build/logs/<case>.fail0.log`.

## Things to know

**The `.resc` defines its own button and LED.** Renode's `nrf52840dk_nrf52840.repl` has
no `invert: true` on its buttons, so the active-low `sw0` reads as held from boot. The
`.resc` also leaves out `start`, so the test attaches its testers before the first line
is printed.

**The first press is lost.** Renode 1.17's GPIOTE model records the pin as low when the
driver sets up the channel, although it rests high, so the first high-to-low change is
not reported. `Boot The DK` presses and releases once to get past it. The real chip does
not do this.

## References

- [Renode testing with Robot](https://renode.readthedocs.io/en/latest/introduction/testing.html)
- [Robot Framework User Guide](https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html)
- [Renode platform description format](https://renode.readthedocs.io/en/latest/advanced/platform_description_format.html)
