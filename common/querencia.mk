# Shared rules for Querencia's Debian source packages (included by
# debian/rules; werkzeuge/paket-bauen.sh copies this file to debian/).
#
# Written for dpkg-buildpackage WITHOUT debhelper: the build machine has
# dpkg-dev, fakeroot and dpkg-shlibdeps but no debhelper, and nothing may be
# installed. Everything debhelper would do for these simple packages is done
# here explicitly (see querencia-packaging/BUILDING.md). Migrating to
# "dh $@" + debhelper-compat 13 later only replaces this file.
#
# The including debian/rules sets, before "include debian/querencia.mk":
#   QUERENCIA_KIND     rust | data | custom (custom: debian/rules defines
#                      the target querencia-build)
#   CARGO_FEATURES     extra cargo flags (rust; e.g. --no-default-features)
#   QUERENCIA_TEST     yes | no  (rust; cargo test unless DEB_BUILD_OPTIONS=nocheck)
# and defines the target "querencia-install" which installs into $(DESTDIR).
# Exactly one binary package per source package: $(PKG) = first in control.

SHELL := /bin/sh
export LC_ALL := C.UTF-8
unexport WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS

SOURCE := $(shell dpkg-parsechangelog -S Source)
VERSION := $(shell dpkg-parsechangelog -S Version)
UPSTREAM_VERSION := $(shell echo '$(VERSION)' | sed 's/-[^-]*$$//')
PKG := $(shell sed -n 's/^Package: *//p' debian/control | head -n 1)
DESTDIR := $(CURDIR)/debian/$(PKG)

NUMJOBS := $(patsubst parallel=%,%,$(filter parallel=%,$(DEB_BUILD_OPTIONS)))
NUMJOBS := $(if $(NUMJOBS),$(NUMJOBS),2)

# --- Rust ---------------------------------------------------------------
# Only the distribution's toolchain; never rustup proxies from ~/.cargo/bin
# (cargo looks up subcommands in $CARGO_HOME/bin, so CARGO_HOME is private).
# Build profile pkg.querencia.fremdrust (prototypes only): a newer toolchain
# outside the archive, given as QUERENCIA_RUST_BIN=<dir with cargo, rustc>.
ifneq (,$(filter pkg.querencia.fremdrust,$(DEB_BUILD_PROFILES)))
ifeq (,$(QUERENCIA_RUST_BIN))
$(error Profil pkg.querencia.fremdrust braucht QUERENCIA_RUST_BIN)
endif
RUST_BIN := $(QUERENCIA_RUST_BIN)
else
RUST_BIN := /usr/bin
endif
CARGO := $(RUST_BIN)/cargo
export RUSTC := $(RUST_BIN)/rustc
export RUSTDOC := $(RUST_BIN)/rustdoc
export CARGO_HOME := $(CURDIR)/debian/cargo-home
export CARGO_TARGET_DIR := $(CURDIR)/target
export CARGO_INCREMENTAL := 0
# Hardening from dpkg-buildflags (RUSTFLAGS has frame pointers; the linker
# flags come from LDFLAGS) and no build paths in the binaries.
LINK_ARGS := $(foreach f,$(filter -Wl%,$(shell dpkg-buildflags --get LDFLAGS)),-C link-arg=$(f))
export RUSTFLAGS := $(shell dpkg-buildflags --get RUSTFLAGS) $(LINK_ARGS) \
	--remap-path-prefix=$(CURDIR)=/usr/src/$(SOURCE)-$(UPSTREAM_VERSION) \
	--remap-path-prefix=$(CARGO_HOME)=/usr/share/cargo
# C/C++ code built by crates (cc crate: e.g. QuickJS in rquickjs-sys) gets
# the distribution flags too: hardening and -ffile-prefix-map, so no build
# path ends up in __FILE__ strings.
export CFLAGS := $(shell dpkg-buildflags --get CFLAGS)
export CXXFLAGS := $(shell dpkg-buildflags --get CXXFLAGS)
export CPPFLAGS := $(shell dpkg-buildflags --get CPPFLAGS)
CARGO_FLAGS := --release --frozen -j $(NUMJOBS) $(CARGO_FEATURES)

debian/cargo-home/config.toml:
	mkdir -p $(dir $@)
	test -d cargo-vendor || { echo "cargo-vendor/ fehlt (Komponente orig-cargo-vendor)"; exit 1; }
	printf '%s\n' '[source.crates-io]' 'replace-with = "vendored-sources"' \
		'[source.vendored-sources]' 'directory = "$(CURDIR)/cargo-vendor"' \
		'[net]' 'offline = true' >$@

debian/stamp-build: $(if $(filter rust,$(QUERENCIA_KIND)),debian/cargo-home/config.toml)
ifeq ($(QUERENCIA_KIND),rust)
	$(CARGO) --version
	$(RUSTC) --version
	$(CARGO) build $(CARGO_FLAGS)
ifeq (,$(filter nocheck,$(DEB_BUILD_OPTIONS)))
ifeq ($(QUERENCIA_TEST),yes)
	env -u WAYLAND_DISPLAY -u DISPLAY DBUS_SESSION_BUS_ADDRESS=disabled: \
		XDG_RUNTIME_DIR=$(CURDIR)/debian/test-runtime HOME=$(CURDIR)/debian/test-home \
		sh -c 'mkdir -p -m 0700 "$$XDG_RUNTIME_DIR" "$$HOME" && $(CARGO) test $(CARGO_FLAGS)'
endif
endif
endif
ifeq ($(QUERENCIA_KIND),custom)
	$(MAKE) -f debian/rules querencia-build
endif
	touch $@

# --- helpers for querencia-install ---------------------------------------
# Desktop file from the source tree for /usr: comment lines dropped (they
# describe the development VM), an absolute directory in Exec/TryExec
# stripped (packages install to /usr/bin), validated afterwards.
#   $(call desktop_install,<file in the tree>,<installed path>)
desktop_install = install -d $(dir $(2)) && \
	sed -E -e '/^[[:space:]]*\#/d' -e 's@^(Exec|TryExec)=/[^ ]*/@\1=@' $(1) >$(2) && \
	chmod 0644 $(2) && desktop-file-validate $(2)
# Restrict an installed desktop file to the Querencia session
# (OnlyShowIn=X-Querencia;, QD-074 K3): session tools that only work under
# labwc (screenshot, settings, shortcuts, volume, session dialog) stay out of
# GNOME and other desktops; MimeType lines are kept.
#   $(call desktop_nur_querencia,<installed path>)
desktop_nur_querencia = desktop-file-edit --remove-key=NotShowIn \
	--set-key=OnlyShowIn --set-value='X-Querencia;' $(1) && \
	grep -qx 'OnlyShowIn=X-Querencia;' $(1) && desktop-file-validate $(1)
# MetaInfo of one or more components from debian/metainfo/ (copied there by
# werkzeuge/paket-bauen.sh), validated with appstreamcli, <pkgname> = $(PKG).
#   $(call metainfo_install,<component id> …)
metainfo_install = DESTDIR=$(DESTDIR) QS_PAKETNAME=$(PKG) QS_METAINFO_QUELLE=debian/metainfo \
	bash debian/metainfo/metainfo-paket-installieren.sh $(1)
# The same for a MetaInfo file the upstream tree ships itself (preferred over
# the copy in debian/metainfo/).
#   $(call metainfo_install_from,<directory in the tree>,<component id> …)
metainfo_install_from = DESTDIR=$(DESTDIR) QS_PAKETNAME=$(PKG) QS_METAINFO_QUELLE=$(1) \
	bash debian/metainfo/metainfo-paket-installieren.sh $(2)
# gettext catalogs: every language in <po dir>/LINGUAS as
# /usr/share/locale/<lang>/LC_MESSAGES/<domain>.mo (English msgids,
# ENTSCHEIDUNGEN Nr. 16); the German catalog must exist.
#   $(call mo_install,<po dir>,<domain>)
mo_install = set -e; for l in $$(sed 's/\#.*//' $(1)/LINGUAS); do \
	install -d $(DESTDIR)/usr/share/locale/$$l/LC_MESSAGES; \
	msgfmt --check -o $(DESTDIR)/usr/share/locale/$$l/LC_MESSAGES/$(2).mo $(1)/$$l.po; done; \
	test -s $(DESTDIR)/usr/share/locale/de/LC_MESSAGES/$(2).mo
# User documentation of the source tree: CHANGELOG.md (as changelog.gz) and
# the files named in $(2) (default README.md), when present. BUILDING.md and
# TESTING.md describe the development VM and stay out of the package.
#   $(call doc_install,<directory in the tree>[,<files>])
# KI-Abschnitte (README „## KI-Hinweis“, COPYRIGHT-Absatz „KI-Hinweis:“)
# kommen nicht ins Paket (Vorgabe des Besitzers 21.10.2026, CLEAN-1
# Nachtrag 2; debian/doku/ki-abschnitt-entfernen.awk).
doc_install = set -e; d=$(DESTDIR)/usr/share/doc/$(PKG); install -d $$d; \
	for f in $(if $(2),$(2),README.md); do \
		if [ -f $(1)/$$f ]; then awk -f debian/doku/ki-abschnitt-entfernen.awk $(1)/$$f >$$d/$$f; \
			chmod 0644 $$d/$$f; fi; done; \
	if [ -f $(1)/CHANGELOG.md ]; then gzip -9nc $(1)/CHANGELOG.md >$$d/changelog.gz; fi

# --- generic binary package ---------------------------------------------

ARCH := $(shell sed -n '/^Package: *$(PKG)$$/,/^$$/s/^Architecture: *//p' debian/control)
# ELF files in the package, computed when the recipe line runs.
FIND_ELF = find $(DESTDIR) -type f -perm -u+x -exec sh -c 'head -c 4 "$$1" | grep -q ELF' _ {} \; -print

debian/stamp-binary: debian/stamp-build
	rm -rf $(DESTDIR)
	$(MAKE) -f debian/rules querencia-install DESTDIR=$(DESTDIR)
	# documentation every package carries
	install -d $(DESTDIR)/usr/share/doc/$(PKG)
	install -m 0644 debian/copyright $(DESTDIR)/usr/share/doc/$(PKG)/copyright
	gzip -9nc debian/changelog >$(DESTDIR)/usr/share/doc/$(PKG)/changelog.Debian.gz
	# Lintian-Ausnahmen mit Begründung (dh_lintian)
	if [ -f debian/$(PKG).lintian-overrides ]; then \
		install -D -m 0644 debian/$(PKG).lintian-overrides $(DESTDIR)/usr/share/lintian/overrides/$(PKG); fi
	chmod 0644 $(DESTDIR)/usr/share/doc/$(PKG)/changelog.Debian.gz
	# Manpages komprimiert, wie dh_compress
	if [ -d $(DESTDIR)/usr/share/man ]; then \
		find $(DESTDIR)/usr/share/man -type f ! -name '*.gz' -exec gzip -9n {} +; fi
ifeq (,$(filter nostrip,$(DEB_BUILD_OPTIONS)))
	for f in $$($(FIND_ELF)); do \
		strip --remove-section=.comment --remove-section=.note --strip-unneeded "$$f"; done
endif
	# permissions as debhelper's dh_fixperms would set them
	find $(DESTDIR) -type d -exec chmod 0755 {} +
	find $(DESTDIR) -type f ! -perm -u+x -exec chmod 0644 {} +
	find $(DESTDIR) -type f -perm -u+x -exec chmod 0755 {} +
	# control area
	install -d $(DESTDIR)/DEBIAN
	set -e; if [ -d $(DESTDIR)/etc ]; then \
		(cd $(DESTDIR) && find etc -type f | LC_ALL=C sort | sed 's|^|/|') >$(DESTDIR)/DEBIAN/conffiles; \
		chmod 0644 $(DESTDIR)/DEBIAN/conffiles; fi
	set -e; for s in preinst postinst prerm postrm config; do \
		if [ -f debian/$(PKG).$$s ]; then install -m 0755 debian/$(PKG).$$s $(DESTDIR)/DEBIAN/$$s; fi; done
	# debconf-Vorlagen (dh_installdebconf)
	if [ -f debian/$(PKG).templates ]; then \
		install -m 0644 debian/$(PKG).templates $(DESTDIR)/DEBIAN/templates; fi
	rm -f debian/$(PKG).substvars
	set -e; elf="$$($(FIND_ELF))"; if [ -n "$$elf" ]; then \
		dpkg-shlibdeps -Tdebian/$(PKG).substvars $$elf; fi
	(cd $(DESTDIR) && find . -type f ! -path './DEBIAN/*' -printf '%P\0' | LC_ALL=C sort -z | \
		xargs -0r md5sum) >$(DESTDIR)/DEBIAN/md5sums
	chmod 0644 $(DESTDIR)/DEBIAN/md5sums
	dpkg-gencontrol -p$(PKG) -P$(DESTDIR) -Tdebian/$(PKG).substvars
	# reproducible: no file newer than the changelog entry (SOURCE_DATE_EPOCH,
	# exported by dpkg-buildpackage), as dh_builddeb/strip-nondeterminism do
	if [ -n "$$SOURCE_DATE_EPOCH" ]; then \
		find $(DESTDIR) -newermt "@$$SOURCE_DATE_EPOCH" -exec touch -h -d "@$$SOURCE_DATE_EPOCH" {} +; fi
	touch $@

# --- dpkg-buildpackage targets ------------------------------------------
# One binary package per source: build/binary-arch act only for an
# architecture-dependent package, build/binary-indep only for "all".

ifeq ($(ARCH),all)
build-arch:
build-indep: debian/stamp-build
binary-arch:
binary-indep: debian/deb-built
else
build-arch: debian/stamp-build
build-indep:
binary-arch: debian/deb-built
binary-indep:
endif
build: debian/stamp-build
binary: debian/deb-built

debian/deb-built: debian/stamp-binary
	dpkg-deb --root-owner-group -Zxz --build $(DESTDIR) ..
	touch $@

clean::
	rm -f debian/stamp-build debian/stamp-binary debian/deb-built debian/files debian/*.substvars
	rm -rf debian/cargo-home debian/test-runtime debian/test-home $(DESTDIR) target

.PHONY: build build-arch build-indep binary binary-arch binary-indep clean querencia-install querencia-build
