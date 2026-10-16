// Test-only shell command that presses the emulated button.
// Built into the test image only, never into the app.

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/gpio/gpio_emul.h>
#include <zephyr/shell/shell.h>

#define BUTTON_NODE DT_ALIAS(sw0)
static const struct gpio_dt_spec button = GPIO_DT_SPEC_GET(BUTTON_NODE, gpios);

static inline int button_active_raw(void)
{
    return (button.dt_flags & GPIO_ACTIVE_LOW) ? 0 : 1;
}

void trigger_emulated_button_press(void)
{
    const int active = button_active_raw();
    const int inactive = !active;

    gpio_emul_input_set(button.port, button.pin, inactive);
    k_sleep(K_MSEC(20));

    gpio_emul_input_set(button.port, button.pin, active);
    k_sleep(K_MSEC(50));

    gpio_emul_input_set(button.port, button.pin, inactive);
}

static int cmd_test_button(const struct shell *sh, size_t argc, char **argv)
{
    ARG_UNUSED(argc);
    ARG_UNUSED(argv);

    /* shell_print, not printk, so the line can't interleave with the shell echo. */
    shell_print(sh, "Test: Triggering emulated button press");

    trigger_emulated_button_press();
    return 0;
}

SHELL_CMD_REGISTER(test_btn, NULL, "Trigger emulated button press", cmd_test_button);
