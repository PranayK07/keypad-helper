# Build and host checks only. Intentionally no flash/install/bootloader target.
SDCC ?= sdcc
HOST_CC ?= clang
PYTHON ?= python3
CFLAGS = -mmcs51 --model-small --no-xinit-opt --nooverlay --xram-loc 0x0100 --xram-size 0x0300 --code-size 0x3800 -Isrc -DF_CPU=16000000
SOURCES = main.c src/delay.c src/neo.c src/usb_descr.c src/usb_handler.c src/usb_hid.c src/lighting_protocol.c src/input_state.c
OBJECTS = $(patsubst %.c,build/%.rel,$(SOURCES))
.PHONY: all test clean
all: build/keypad-helper-rgb.hex build/keypad-helper-rgb.bin
build/%.rel: %.c $(wildcard src/*.h)
	@mkdir -p $(dir $@)
	$(SDCC) $(CFLAGS) -c $< -o $@
build/keypad-helper-rgb.ihx: $(OBJECTS)
	$(SDCC) $(CFLAGS) $(OBJECTS) -o $@
build/keypad-helper-rgb.hex build/keypad-helper-rgb.bin: build/keypad-helper-rgb.ihx tools/package.py tools/check_map.py
	$(PYTHON) tools/check_map.py build/keypad-helper-rgb
	$(PYTHON) tools/package.py $< build/keypad-helper-rgb

test:
	@mkdir -p build
	$(HOST_CC) -std=c99 -Wall -Wextra -Werror -fsanitize=address,undefined -Isrc tests/test_core.c src/lighting_protocol.c src/input_state.c -o build/test-core
	./build/test-core
	$(PYTHON) tests/check_descriptors.py
clean:
	rm -rf build
