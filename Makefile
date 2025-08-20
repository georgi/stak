SHELL := /bin/bash

.PHONY: lint fmt test install ci

FILES := stak test

lint:
	shellcheck $(FILES)
	shfmt -d -i 2 -ci -s $(FILES)

fmt:
	shfmt -w -i 2 -ci -s $(FILES)

test:
	chmod +x ./stak || true
	bash ./test

install:
	install -m 0755 stak /usr/local/bin/stak

ci: lint test


