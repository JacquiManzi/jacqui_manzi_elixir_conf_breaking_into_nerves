LDFLAGS ?=
CFLAGS ?=
CC ?= $(CROSSCOMPILE)-gcc
subsystem:
		cd ./src/libjpeg && $(MAKE)
