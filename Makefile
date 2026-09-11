# halfshell's install layout, and the one thing every package builds on — a
# PKGBUILD, a Nix derivation, an RPM spec, or a checkout and sudo.
#
#   make              fill the install paths into the launcher and the unit
#   make check        check what make made
#   make install      install under PREFIX, /usr/local unless told otherwise
#   make uninstall    remove what install put there
#   make run          run the shell straight from this checkout
#   make clean        remove build/
#
# Two different questions, two variables. PREFIX — and the directories below,
# which default from it — is where the files will live when the shell runs,
# and is written into the launcher and the unit. DESTDIR is where install
# writes them now: the staging root a package is made from. It is written
# into nothing, so a package can be built without touching /usr.
#
#   make PREFIX=/usr
#   make PREFIX=/usr DESTDIR="$pkgdir" install
#
# Paths are substituted with sed and quoted with single quotes, so none of
# them may contain a ' or a |.

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
SYSTEMDUSERUNITDIR ?= $(PREFIX)/lib/systemd/user

# halfshell's own directory, which install and uninstall replace wholesale:
# that is what stops files an older layout installed from lingering beside a
# newer one. So it can't be pointed anywhere else — a directory that is
# rm -rf'd has to be one nothing else lives in.
override PKGDATADIR = $(DATADIR)/halfshell

# The Quickshell binary the launcher runs. A bare name is looked up on PATH
# each time the launcher runs; Nix wants an absolute store path instead.
QS ?= qs

# Overridable because packagers override it: RPM's %make_install passes
# INSTALL="install -p" to keep timestamps.
INSTALL ?= install
INSTALL_PROGRAM ?= $(INSTALL) -m 755
INSTALL_DATA ?= $(INSTALL) -m 644

# What goes in PKGDATADIR: the QML, and cava.conf. Found rather than listed,
# so a new component is installed without anyone remembering to add it here.
# Matched by extension, so nothing else in a development checkout is — such
# as the .qmlls.ini symlink Quickshell makes there, which points into
# $XDG_RUNTIME_DIR and means nothing on any other machine.
#
# No config.json, ever: the defaults are in Config.qml, and the only
# config.json is the user's own, in ~/.config/halfshell.
SHELL_FILES := $(sort $(shell find quickshell -type f \( -name '*.qml' -o -name '*.conf' \) -printf '%P\n'))

GENERATED := build/halfshell build/halfshell.service

SUBSTITUTE = sed -e 's|@PKGDATADIR@|$(PKGDATADIR)|g' -e 's|@BINDIR@|$(BINDIR)|g' -e 's|@QS@|$(QS)|g'

.PHONY: all check install uninstall run clean FORCE
.DELETE_ON_ERROR:

all: $(GENERATED)

# The values baked into the generated files, in a file that is only
# rewritten when one of them changes. Everything generated depends on it, so
# `make` with one PREFIX and then `make install` with another — which a
# PKGBUILD's build() and package() can easily do — rebuilds the launcher and
# the unit rather than installing ones that point at the wrong place.
build/substitutions: FORCE
	@mkdir -p build
	@printf '%s\n' '$(PKGDATADIR)' '$(BINDIR)' '$(QS)' > $@.new
	@if cmp -s $@.new $@; then rm $@.new; else mv $@.new $@; fi

build/halfshell: bin/halfshell.in build/substitutions
	$(SUBSTITUTE) $< > $@

build/halfshell.service: systemd/halfshell.service.in build/substitutions
	$(SUBSTITUTE) $< > $@

# What a package build can check without a display: the launcher parses, and
# nothing was left unsubstituted in it or the unit.
check: all
	sh -n build/halfshell
	@if grep -n '@[A-Z]*@' $(GENERATED); then echo 'unsubstituted placeholders above' >&2; exit 1; fi

# -D makes each file's directories on the way, so the layout under
# quickshell/ is copied as it is, however deep it goes.
install: all
	$(INSTALL_PROGRAM) -D build/halfshell '$(DESTDIR)$(BINDIR)/halfshell'
	$(INSTALL_DATA) -D build/halfshell.service '$(DESTDIR)$(SYSTEMDUSERUNITDIR)/halfshell.service'
	rm -rf '$(DESTDIR)$(PKGDATADIR)'
	for file in $(SHELL_FILES); do $(INSTALL_DATA) -D quickshell/"$$file" '$(DESTDIR)$(PKGDATADIR)'/"$$file" || exit; done

uninstall:
	rm -f '$(DESTDIR)$(BINDIR)/halfshell' '$(DESTDIR)$(SYSTEMDUSERUNITDIR)/halfshell.service'
	rm -rf '$(DESTDIR)$(PKGDATADIR)'

run:
	$(QS) -p quickshell

clean:
	rm -rf build
