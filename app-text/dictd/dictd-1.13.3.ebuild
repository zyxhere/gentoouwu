# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools optfeature readme.gentoo-r1 systemd

DESCRIPTION="Dictionary Client/Server for the DICT protocol"
HOMEPAGE="https://www.dict.org/ https://sourceforge.net/projects/dict/"
SRC_URI="https://downloads.sourceforge.net/dict/${P}.tar.gz"

LICENSE="GPL-1+ GPL-2+"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~mips ~ppc ~ppc64 ~riscv ~sparc ~x86 ~amd64-linux ~x86-linux ~ppc-macos"
IUSE="dbi judy minimal selinux test"
RESTRICT="!test? ( test )"

RDEPEND="
	acct-group/dictd
	acct-user/dictd
	dev-libs/libmaa:=
	sys-apps/coreutils
	sys-libs/zlib
	selinux? ( sec-policy/selinux-dictd )
"
DEPEND="${RDEPEND}
	dbi? ( dev-db/libdbi )
	judy? ( dev-libs/judy )
"
BDEPEND="
	app-alternatives/lex
	app-alternatives/yacc
	sys-apps/gawk
"

DOC_CONTENTS="
	To start and use ${PN} you need to emerge at least one dictionary from
	the app-dicts category with the package name starting with 'dictd-'.
	${PN} will NOT start without at least one dictionary.\n
	\nIf you are running systemd, you will need to review the instructions
	explained in /etc/dict/dictd.conf comments.
"

PATCHES=(
	"${FILESDIR}"/dictd-1.10.11-colorit-nopp-fix.patch
	"${FILESDIR}"/dictd-1.12.0-build.patch
	"${FILESDIR}"/dictd-1.13.0-stack-smashing.patch # bug #908998
	"${FILESDIR}"/dictd-1.13.3-debian_fix_warnings.patch
	"${FILESDIR}"/dictd-1.13.3-libtool.patch # bug #818535
	"${FILESDIR}"/dictd-1.13.3-version.patch # bug #852884
	"${FILESDIR}"/dictd-1.13.3-rm_replace_strlfuncs.patch # bug #880531
)

src_prepare() {
	default

	eautoreconf
}

src_configure() {
	local myeconfargs=(
		$(use_with dbi plugin-dbi)
		$(use_with judy plugin-judy)
		--libexecdir="${EPREFIX}"/usr/$(get_libdir)/${PN}
		--sysconfdir="${EPREFIX}"/etc/dict
	)
	econf "${myeconfargs[@]}"
}

src_compile() {
	# -j1 for bug #743292
	if use minimal; then
		emake -j1 dictfmt dictzip dictzip
	else
		emake -j1
	fi
}

src_test() {
	use minimal && return 0 # All tests are for dictd which we don't build...

	if [[ ${EUID} -eq 0 ]]; then
		# If dictd is run as root user (-userpriv) it drops its privileges to
		# dictd user and group. Give dictd group write access to test directory.
		chown :dictd "${WORKDIR}" "${S}/test" || die
		chmod 770 "${WORKDIR}" "${S}/test" || die
	fi

	emake -j1 test
}

src_install() {
	if use minimal; then
		emake -j1 DESTDIR="${ED}" install.dictzip install.dict install.dictfmt
	else
		default

		# Don't install rfc2229.txt because it is non-free
		dodoc doc/{dicf.ms,rfc.ms,rfc.sh}
		dodoc doc/{security.doc,toc.ms}
		dodoc -r examples

		# conf files. For dict.conf see below.
		insinto /etc/dict
		for f in dictd.conf site.info colorit.conf; do
			doins "${FILESDIR}/1.10.11/${f}"
		done

		# startups for dictd
		newinitd "${FILESDIR}/1.10.11/dictd.initd" dictd
		newconfd "${FILESDIR}/1.10.11/dictd.confd" dictd
		systemd_dounit "${FILESDIR}"/${PN}.service
	fi

	find "${ED}" -name '*.la' -o -name '*.a' -delete || die

	insinto /etc/dict
	doins "${FILESDIR}"/1.10.11/dict.conf

	dodoc ANNOUNCE NEWS README TODO

	readme.gentoo_create_doc
}

pkg_postinst() {
	readme.gentoo_print_elog

	optfeature "character set conversions (dictl)"  app-text/recode

	if has_version sys-apps/systemd; then
		ewarn "The default location for dicts has changed! If you've modified your"
		ewarn "systemd units locally to point into /usr/lib/dict, please update it"
		ewarn "to point at /usr/share/dict now."
	fi
}
