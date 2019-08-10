LDFLAGS ?=
CFLAGS ?=
CC ?= $(CROSSCOMPILE)-gcc

ifeq ($(MIX_COMPILE_PATH),)
  $(error MIX_COMPILE_PATH should be set by elixir_make!)
endif

PREFIX = $(MIX_COMPILE_PATH)/../priv
DEFAULT_TARGETS ?= $(PREFIX) $(PREFIX)/djpeg

$(PREFIX):
	mkdir -p $@

clean:
	rm -rf $(DEFAULT_TARGETS)/*

.PHONY: clean
