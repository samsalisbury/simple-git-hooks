SHELL := /usr/bin/env bash -euo pipefail -c 

SRC := src
COPYTHIS := copythis.githooks

FILES_TO_COPY := run.bash install

INPUTS := $(addprefix $(SRC)/,$(FILES_TO_COPY))
OUTPUTS := $(addprefix $(COPYTHIS)/,$(FILES_TO_COPY))

$(COPYTHIS)/%: $(SRC)/%
	cp -f $< $@

generate: $(OUTPUTS)
