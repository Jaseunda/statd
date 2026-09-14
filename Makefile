PREFIX     ?= /usr/local
BINDIR      = $(DESTDIR)$(PREFIX)/bin
LIBDIR      = $(DESTDIR)$(PREFIX)/lib/statd

LIB_FILES   = lib/colors.sh \
               lib/render.sh \
               lib/sensors_linux.sh \
               lib/sensors_macos.sh \
               lib/sensors.sh \
               lib/llm.sh

.PHONY: all install uninstall check

all:
	@echo "statd is a shell script — nothing to compile."
	@echo "Run 'make install' to install to $(BINDIR)."

install: check
	install -d "$(BINDIR)" "$(LIBDIR)"
	install -m 755 statd "$(BINDIR)/statd"
	install -m 644 $(LIB_FILES) "$(LIBDIR)/"
	@echo "Installed statd to $(BINDIR)/statd"
	@echo "Installed libraries to $(LIBDIR)/"

uninstall:
	rm -f "$(BINDIR)/statd"
	rm -rf "$(LIBDIR)"
	@echo "Uninstalled statd"

check:
	@bash -n statd          && echo "OK  statd"
	@bash -n lib/colors.sh  && echo "OK  lib/colors.sh"
	@bash -n lib/render.sh  && echo "OK  lib/render.sh"
	@bash -n lib/sensors_linux.sh  && echo "OK  lib/sensors_linux.sh"
	@bash -n lib/sensors_macos.sh  && echo "OK  lib/sensors_macos.sh"
	@bash -n lib/sensors.sh && echo "OK  lib/sensors.sh"
	@bash -n lib/llm.sh     && echo "OK  lib/llm.sh"
