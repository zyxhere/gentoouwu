# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# please keep this ebuild at EAPI 8 -- sys-apps/portage dep
EAPI=8

# please bump dev-python/ensurepip-setuptools along with this package!

DISTUTILS_USE_PEP517=standalone
PYTHON_TESTED=( python3_{11..14} pypy3_11 )
PYTHON_COMPAT=( "${PYTHON_TESTED[@]}" python3_{13,14}t )
PYTHON_REQ_USE="xml(+)"

inherit distutils-r1 pypi

DESCRIPTION="Collection of extensions to Distutils"
HOMEPAGE="
	https://github.com/pypa/setuptools/
	https://pypi.org/project/setuptools/
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 hppa ~loong ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86 ~arm64-macos ~x64-macos ~x64-solaris"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="
	dev-python/jaraco-collections[${PYTHON_USEDEP}]
	>=dev-python/jaraco-functools-4[${PYTHON_USEDEP}]
	>=dev-python/jaraco-text-3.7.0-r1[${PYTHON_USEDEP}]
	>=dev-python/more-itertools-8.12.0-r1[${PYTHON_USEDEP}]
	>=dev-python/packaging-24.2[${PYTHON_USEDEP}]
	>=dev-python/platformdirs-4.2.2[${PYTHON_USEDEP}]
	>=dev-python/wheel-0.44.0[${PYTHON_USEDEP}]
"
BDEPEND="
	${RDEPEND}
	test? (
		$(python_gen_cond_dep '
			>=dev-python/build-1.0.3[${PYTHON_USEDEP}]
			>=dev-python/ini2toml-0.14[${PYTHON_USEDEP}]
			>=dev-python/filelock-3.4.0[${PYTHON_USEDEP}]
			>=dev-python/jaraco-envs-2.2[${PYTHON_USEDEP}]
			>=dev-python/jaraco-path-3.7.2[${PYTHON_USEDEP}]
			>=dev-python/jaraco-test-5.5[${PYTHON_USEDEP}]
			dev-python/pip[${PYTHON_USEDEP}]
			dev-python/pyproject-hooks[${PYTHON_USEDEP}]
			dev-python/pytest[${PYTHON_USEDEP}]
			>=dev-python/pytest-home-0.5[${PYTHON_USEDEP}]
			dev-python/pytest-subprocess[${PYTHON_USEDEP}]
			dev-python/pytest-timeout[${PYTHON_USEDEP}]
			dev-python/pytest-xdist[${PYTHON_USEDEP}]
			>=dev-python/tomli-w-1.0.0[${PYTHON_USEDEP}]
			>=dev-python/virtualenv-20[${PYTHON_USEDEP}]
		' "${PYTHON_TESTED[@]}")
	)
"
# setuptools-scm is here because installing plugins apparently breaks stuff at
# runtime, so let's pull it early. See bug #663324.
#
# trove-classifiers are optionally used in validation, if they are
# installed.  Since we really oughtn't block them, let's always enforce
# the newest version for the time being to avoid errors.
# https://github.com/pypa/setuptools/issues/4459
PDEPEND="
	dev-python/setuptools-scm[${PYTHON_USEDEP}]
	>=dev-python/trove-classifiers-2024.10.16[${PYTHON_USEDEP}]
"

src_prepare() {
	local PATCHES=(
		# https://github.com/abravalheri/validate-pyproject/pull/221
		"${FILESDIR}/setuptools-75.6.0-disable-trove-classifiers.patch"
	)

	distutils-r1_src_prepare

	# remove bundled dependencies
	rm -r */_vendor || die
}

python_test() {
	if ! has "${EPYTHON}" "${PYTHON_TESTED[@]/_/.}"; then
		return
	fi

	local EPYTEST_DESELECT=(
		# broken by unbundling (e.g. installs self-wheel into venv)
		setuptools/tests/config/test_apply_pyprojecttoml.py::TestMeta
		setuptools/tests/test_distutils_adoption.py
		setuptools/tests/test_editable_install.py
		setuptools/tests/test_sdist.py::test_sanity_check_setuptools_own_sdist
		setuptools/tests/test_setuptools.py::test_wheel_includes_vendored_metadata
		setuptools/tests/test_virtualenv.py::test_no_missing_dependencies
		# TODO
		setuptools/tests/config/test_setupcfg.py::TestConfigurationReader::test_basic
		setuptools/tests/config/test_setupcfg.py::TestConfigurationReader::test_ignore_errors
		# TODO, probably some random package
		setuptools/tests/config/test_setupcfg.py::TestOptions::test_cmdclass
		# relies on -Werror
		setuptools/_static.py::setuptools._static.Dict
		setuptools/_static.py::setuptools._static.List
	)

	local EPYTEST_XDIST=1
	local -x PRE_BUILT_SETUPTOOLS_WHEEL=${DISTUTILS_WHEEL_PATH}
	local EPYTEST_PLUGINS=( pytest-{home,subprocess,timeout} )
	epytest -o tmp_path_retention_policy=all \
		-m "not uses_network" setuptools
}
