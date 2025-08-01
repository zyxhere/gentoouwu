# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..14} )

inherit distutils-r1 llvm.org

DESCRIPTION="A stand-alone install of the LLVM suite testing tool"
HOMEPAGE="https://llvm.org/"

LICENSE="Apache-2.0-with-LLVM-exceptions UoI-NCSA"
SLOT="0"
KEYWORDS="amd64 arm arm64 ~loong ~mips ppc ppc64 ~riscv sparc x86"
IUSE="test"
RESTRICT="!test? ( test )"

# Tests require 'FileCheck' and 'not' utilities (from llvm)
BDEPEND="
	test? (
		dev-python/psutil[${PYTHON_USEDEP}]
		llvm-core/llvm
	)
"

LLVM_COMPONENTS=( llvm/utils/lit )
llvm.org_set_globals

# TODO: move the manpage generation here (from llvm-core/llvm)

src_prepare() {
	# flaky test
	# https://github.com/llvm/llvm-project/issues/72022
	rm tests/progress-bar.py || die

	cd "${WORKDIR}" || die
	distutils-r1_src_prepare
}

python_test() {
	local -x LIT_PRESERVES_TMP=1
	local litflags=$(get_lit_flags)
	./lit.py ${litflags//;/ } tests || die
}
