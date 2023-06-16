.PHONY: install, build, test

install: SHELL:=/bin/bash
install:
	@mix deps.get

install-test: SHELL:=/bin/bash
install-test:
	@mix deps.get --only test

build: SHELL:=/bin/bash
build: install
build:
	@mix compile

test: SHELL:=/bin/bash
test: install-test
test:
	@MIX_ENV=test mix test
