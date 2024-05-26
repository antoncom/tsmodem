#!/bin/sh

echo -e '{"proto":"ubus","uuid":"","obj":"tsmodem.driver","method":"send_at","params":{"command":"\x1a"}}' >> /tmp/wspipeout.fifo

