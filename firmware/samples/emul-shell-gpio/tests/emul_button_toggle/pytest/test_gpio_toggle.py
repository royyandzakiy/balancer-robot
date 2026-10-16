# Presses the emulated button through the test_btn shell command and checks the LED toggles.

import logging
from twister_harness import Shell, DeviceAdapter

logger = logging.getLogger(__name__)

# LED starts off. Two presses prove it toggles rather than sets.
EXPECTED_STATES = ('ON', 'OFF')


def test_button_toggle(shell: Shell):
    for expected in EXPECTED_STATES:
        lines = shell.exec_command('test_btn')
        # On real boards logging is deferred, so the LED line can arrive after the prompt.
        if f'LED is now {expected}' not in '\n'.join(lines):
            lines += shell._device.readlines_until(
                regex=f'LED is now {expected}', timeout=2
            )
        output = '\n'.join(lines)

        assert 'Test: Triggering emulated button press' in output
        assert f'Button pressed! LED is now {expected}' in output


# Same check on the raw serial line, without the shell fixture.
def test_button_toggle_dut(dut: DeviceAdapter):
    for expected in EXPECTED_STATES:
        dut.write(b'test_btn\n')
        lines = dut.readlines_until(regex=f'LED is now {expected}', timeout=2)
        output = '\n'.join(lines)

        assert 'Test: Triggering emulated button press' in output
        assert f'Button pressed! LED is now {expected}' in output
