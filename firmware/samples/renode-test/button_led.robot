*** Variables ***
# ${CURDIR} is this file's folder, so renode-test can run from any directory.
${ELF}                        @${CURDIR}/build/zephyr/zephyr.elf
${RESC}                       @${CURDIR}/run_nrf52.resc

*** Keywords ***
Boot The DK
    Execute Command           $elf=${ELF}
    Execute Command           include ${RESC}
    Create Terminal Tester    sysbus.uart0
    Create LED Tester         sysbus.gpio0.led0
    Start Emulation
    Wait For Line On Uart     Ready. Press the button to toggle LED.
    # Renode 1.17's GPIOTE model misses the first press on a pin that rests high.
    # This press and release absorbs it; the first Assert LED State checks the firmware missed it.
    Execute Command           sysbus.gpio0.sw0 Press
    Execute Command           sysbus.gpio0.sw0 Release

*** Test Cases ***
Should Turn The LED On When sw0 Is Pressed
    Boot The DK
    Assert LED State          false
    Execute Command           sysbus.gpio0.sw0 Press
    Wait For Line On Uart     Button pressed! LED is now ON
    Assert LED State          true

Should Turn The LED Off At The Second Press
    Boot The DK
    Execute Command           sysbus.gpio0.sw0 Press
    Wait For Line On Uart     Button pressed! LED is now ON
    Execute Command           sysbus.gpio0.sw0 Release
    Execute Command           sysbus.gpio0.sw0 Press
    Wait For Line On Uart     Button pressed! LED is now OFF
    Assert LED State          false
