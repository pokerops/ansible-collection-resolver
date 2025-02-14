.PHONY: ${MAKECMDGOALS}

PKGMAN = $$(if [ "$(HOST_DISTRO)" = "fedora" ]; then echo "dnf" ; else echo "apt-get"; fi)
MOLECULE_SCENARIO ?= install
MOLECULE_KVM_DISTRO ?= jammy
MOLECULE_KVM_IMAGE ?= https://cloud-images.ubuntu.com/${MOLECULE_KVM_DISTRO}/current/${MOLECULE_KVM_DISTRO}-server-cloudimg-amd64.img
GALAXY_API_KEY ?=
GITHUB_REPOSITORY ?= $$(git config --get remote.origin.url | cut -d':' -f 2 | cut -d. -f 1)
GITHUB_ORG = $$(echo ${GITHUB_REPOSITORY} | cut -d/ -f 1)
GITHUB_REPO = $$(echo ${GITHUB_REPOSITORY} | cut -d/ -f 2)
REQUIREMENTS = requirements.yml
ROLE_DIR = roles
ROLE_FILE = roles.yml
COLLECTION_NAMESPACE = $$(yq '.namespace' < galaxy.yml -r)
COLLECTION_NAME = $$(yq '.name' < galaxy.yml -r)
COLLECTION_VERSION = $$(yq '.version' < galaxy.yml -r)

all: install version lint test

test: lint
	MOLECULE_KVM_DISTRO=${MOLECULE_KVM_DISTRO} \
	MOLECULE_KVM_IMAGE=${MOLECULE_KVM_IMAGE} \
	poetry run molecule $@ -s ${MOLECULE_SCENARIO}

install:
	@sudo ${PKGMAN} install -y $$(if [[ "${HOST_DISTRO}" == "fedora" ]]; then echo libvirt-devel; else echo libvirt-dev; fi)
	@poetry install --no-root

lint: install
	poetry run yamllint .
	poetry run ansible-lint playbooks/

requirements: install
	@python --version
	@if [ -f ${ROLE_FILE} ]; then \
		yq '.roles[].name' -r < ${ROLE_FILE} | xargs -rI {} rm -rf roles/{} ; \
	fi
	@if [ -f ${ROLE_FILE} ]; then \
		poetry run ansible-galaxy role install \
			--force --no-deps \
			--roles-path ${ROLE_DIR} \
			--role-file ${ROLE_FILE} ; \
	fi
	@poetry run ansible-galaxy collection install \
		--force-with-deps .
	@\find ./ -name "*.ymle*" -delete

build: requirements
	@poetry run ansible-galaxy collection build --force

dependency create prepare converge idempotence side-effect verify destroy cleanup reset list:
	MOLECULE_KVM_DISTRO=${MOLECULE_KVM_DISTRO} \
	MOLECULE_KVM_IMAGE=${MOLECULE_KVM_IMAGE} \
	poetry run molecule $@ -s ${MOLECULE_SCENARIO}

ifeq (login,$(firstword $(MAKECMDGOALS)))
    LOGIN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    $(eval $(subst $(space),,$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))):;@:)
endif

login:
	poetry run molecule $@ -s ${MOLECULE_SCENARIO} ${LOGIN_ARGS}

ignore:
	@poetry run ansible-lint --generate-ignore

clean: destroy reset
	@poetry env remove $$(which python) >/dev/null 2>&1 || exit 0

publish: build
	poetry run ansible-galaxy collection publish --api-key ${GALAXY_API_KEY} \
		"${COLLECTION_NAMESPACE}-${COLLECTION_NAME}-${COLLECTION_VERSION}.tar.gz"

version:
	@poetry run molecule --version

debug: install version
	@poetry export --dev --without-hashes || exit 0
