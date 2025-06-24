.PHONY: ${MAKECMDGOALS}

MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))

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

LOGIN_ARGS ?=

all: install version lint test

test: lint
	ANSIBLE_COLLECTIONS_PATH=$(MAKEFILE_DIR) \
	MOLECULE_KVM_DISTRO=${MOLECULE_KVM_DISTRO} \
	MOLECULE_KVM_IMAGE=${MOLECULE_KVM_IMAGE} \
	uv run molecule $@ -s ${MOLECULE_SCENARIO}

install:
	@uv sync

lint: install
	uv run yamllint . -c .yamllint
	ANSIBLE_COLLECTIONS_PATH=$(MAKEFILE_DIR) \
	uv run ansible-lint playbooks/

requirements: install
	@python --version
	@if [ -f ${ROLE_FILE} ]; then \
		yq '.roles[].name' -r < ${ROLE_FILE} | xargs -rI {} rm -rf roles/{} ; \
	fi
	@if [ -f ${ROLE_FILE} ]; then \
		uv run ansible-galaxy role install \
			--force --no-deps \
			--roles-path ${ROLE_DIR} \
			--role-file ${ROLE_FILE} ; \
	fi
	ANSIBLE_COLLECTIONS_PATH=$(MAKEFILE_DIR) \
	uv run ansible-galaxy collection install \
		--force-with-deps .
	@\find ./ -name "*.ymle*" -delete

build: requirements
	@uv run ansible-galaxy collection build --force

ifeq (login,$(firstword $(MAKECMDGOALS)))
    LOGIN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    $(eval $(subst $(space),,$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))):;@:)
endif

dependency create prepare converge idempotence side-effect verify destroy cleanup reset list:
	ANSIBLE_COLLECTIONS_PATH=$(MAKEFILE_DIR) \
	MOLECULE_KVM_DISTRO=${MOLECULE_KVM_DISTRO} \
	MOLECULE_KVM_IMAGE=${MOLECULE_KVM_IMAGE} \
	uv run molecule $@ -s ${MOLECULE_SCENARIO} ${LOGIN_ARGS}

ignore:
	@uv run ansible-lint --generate-ignore

clean: destroy reset
	@uv env remove $$(which python) >/dev/null 2>&1 || exit 0

publish: build
	uv run ansible-galaxy collection publish --api-key ${GALAXY_API_KEY} \
		"${COLLECTION_NAMESPACE}-${COLLECTION_NAME}-${COLLECTION_VERSION}.tar.gz"

version:
	@uv run molecule --version

debug: install version
	@uv export --dev --without-hashes || exit 0
