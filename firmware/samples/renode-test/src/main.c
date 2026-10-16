#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/printk.h>

#define BUTTON_NODE DT_ALIAS(sw0)
static const struct gpio_dt_spec button = GPIO_DT_SPEC_GET(BUTTON_NODE, gpios);

#define LED0_NODE DT_ALIAS(led0)
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

static struct gpio_callback button_cb_data;

/* Tracked here, not read back: on nRF an output pin's input buffer is disconnected,
 * so gpio_pin_get_dt() on the LED returns the same value either way.
 */
static bool led_on;

static void button_pressed_cb(const struct device *dev, struct gpio_callback *cb,
                              uint32_t pins)
{
    led_on = !led_on;
    gpio_pin_set_dt(&led, led_on);
    printk("Button pressed! LED is now %s\n", led_on ? "ON" : "OFF");
}

int main(void)
{
    int ret;

    printk("Board: %s\n", CONFIG_BOARD_TARGET);

    if (!device_is_ready(button.port) || !device_is_ready(led.port)) {
        printk("Error: GPIO port not ready\n");
        return 0;
    }

    ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE);
    if (ret != 0) {
        printk("Error %d: failed to configure LED\n", ret);
        return 0;
    }

    ret = gpio_pin_configure_dt(&button, GPIO_INPUT);
    if (ret != 0) {
        printk("Error %d: failed to configure button\n", ret);
        return 0;
    }

    ret = gpio_pin_interrupt_configure_dt(&button, GPIO_INT_EDGE_TO_ACTIVE);
    if (ret != 0) {
        printk("Error %d: failed to configure interrupt\n", ret);
        return 0;
    }

    gpio_init_callback(&button_cb_data, button_pressed_cb, BIT(button.pin));
    gpio_add_callback(button.port, &button_cb_data);

    printk("Ready. Press the button to toggle LED.\n");

    return 0;
}
