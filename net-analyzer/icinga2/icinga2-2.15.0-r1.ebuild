# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake eapi9-ver

# https://bugs.gentoo.org/960527#c9
CMAKE_QA_COMPAT_SKIP=1

if [[ ${PV} != 9999 ]]; then
	SRC_URI="https://github.com/Icinga/icinga2/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm64 ~x86"
else
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Icinga/icinga2.git"
fi

DESCRIPTION="Distributed, general purpose, network monitoring engine"
HOMEPAGE="https://icinga.com/"

LICENSE="GPL-2"
SLOT="0"
IUSE="console jumbo-build mail mariadb minimal +mysql +plugins postgres test systemd"
RESTRICT="!test? ( test )"

# Add accounts to DEPEND because of fowners in src_install
DEPEND="
	dev-libs/openssl:=
	dev-libs/boost:=[context]
	console? ( dev-libs/libedit )
	mariadb? ( dev-db/mariadb-connector-c:= )
	mysql? ( dev-db/mysql-connector-c:= )
	postgres? ( dev-db/postgresql:= )
	dev-libs/yajl:=
	acct-user/icinga
	acct-group/icinga
	acct-group/icingacmd
"
BDEPEND="
	app-alternatives/yacc
	app-alternatives/lex
"
RDEPEND="
	${DEPEND}
	acct-group/nagios
	plugins? ( || (
		net-analyzer/monitoring-plugins
		net-analyzer/nagios-plugins
	) )
	mail? ( virtual/mailx )
"

REQUIRED_USE="!minimal? ( || ( mariadb mysql postgres ) )"

src_configure() {
	local mycmakeargs=(
		-DICINGA2_UNITY_BUILD=$(usex jumbo-build)
		-DCMAKE_INSTALL_SYSCONFDIR=/etc
		-DCMAKE_INSTALL_LOCALSTATEDIR=/var
		-DICINGA2_SYSCONFIGFILE=/etc/conf.d/icinga2
		-DICINGA2_PLUGINDIR="/usr/$(get_libdir)/nagios/plugins"
		-DICINGA2_USER=icinga
		-DICINGA2_GROUP=icingacmd
		-DICINGA2_COMMAND_GROUP=icingacmd
		-DICINGA2_RUNDIR=/run
		-DINSTALL_SYSTEMD_SERVICE_AND_INITSCRIPT=ON
		-DUSE_SYSTEMD=$(usex systemd)
		-DICINGA2_WITH_TESTS=$(usex test)
		-DLOGROTATE_HAS_SU=ON
		# only appends -flto
		-DICINGA2_LTO_BUILD=OFF
	)

	# default to off if minimal, allow the flags to be set otherwise
	if use minimal; then
		mycmakeargs+=(
			-DICINGA2_WITH_MYSQL=OFF
			-DICINGA2_WITH_PGSQL=OFF
		)
	else
		mycmakeargs+=(
			-DICINGA2_WITH_PGSQL=$(usex postgres)
			-DICINGA2_WITH_MYSQL=$(usex mysql yes $(usex mariadb))
		)
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	newinitd "${FILESDIR}"/icinga2.initd-3 icinga2

	if use mysql || use mariadb; then
		docinto schema
		newdoc "${WORKDIR}"/icinga2-${PV}/lib/db_ido_mysql/schema/mysql.sql mysql.sql
		docinto schema/upgrade
		dodoc "${WORKDIR}"/icinga2-${PV}/lib/db_ido_mysql/schema/upgrade/*
	fi
	if use postgres; then
		docinto schema
		newdoc "${WORKDIR}"/icinga2-${PV}/lib/db_ido_pgsql/schema/pgsql.sql pgsql.sql
		docinto schema/upgrade
		dodoc "${WORKDIR}"/icinga2-${PV}/lib/db_ido_pgsql/schema/upgrade/*
	fi

	# See messiness in bug #638686
	keepdir /etc/icinga2
	keepdir /var/lib/icinga2/api/log
	keepdir /var/lib/icinga2/api/repository
	keepdir /var/lib/icinga2/api/zones
	keepdir /var/lib/icinga2/api/zones-stage
	keepdir /var/lib/icinga2/certificate-requests
	keepdir /var/lib/icinga2/certs
	keepdir /var/log/icinga2
	keepdir /var/log/icinga2/compat
	keepdir /var/log/icinga2/compat/archives
	keepdir /var/log/icinga2/crash
	keepdir /var/spool/icinga2/perfdata
	keepdir /var/spool/icinga2/tmp

	rm -r "${D}/run" || die "failed to remove /run"
	rm -r "${D}/var/cache" || die "failed to remove /var/cache"

	fowners -R icinga:icinga /etc/icinga2
	fperms 0750 /etc/icinga2
	fowners icinga:icinga /var/lib/icinga2
	fowners -R icinga:icingacmd /var/lib/icinga2/api
	fowners -R icinga:icingacmd /var/lib/icinga2/certificate-requests
	fowners -R icinga:icingacmd /var/lib/icinga2/certs
	fowners icinga:icinga /var/spool/icinga2
	fowners icinga:icinga /var/spool/icinga2/perfdata
	fowners icinga:icingacmd /var/log/icinga2

	fperms ug+rwX,o-rwx /etc/icinga2
	fperms ug+rwX,o-rwx /var/lib/icinga2
	fperms ug+rwX,o-rwx /var/spool/icinga2
	fperms ug+rwX,o-rwx /var/log/icinga2

	insinto /usr/share/vim/vimfiles
	doins -r "${WORKDIR}"/${P}/tools/syntax/vim/ftdetect
	doins -r "${WORKDIR}"/${P}/tools/syntax/vim/syntax

	insinto /usr/share/nano
	doins "${WORKDIR}"/${P}/tools/syntax/nano/icinga2.nanorc
}

pkg_postinst() {
	if [[ "${PV}" != 9999 ]] && ver_replacing -lt "${PV}"; then
		elog "DB IDO schema upgrade may be required."
		elog "https://www.icinga.com/docs/icinga2/latest/doc/16-upgrading-icinga-2/"
	fi
}
