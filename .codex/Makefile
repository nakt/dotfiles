MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SKILLS_SRC   := $(abspath $(MAKEFILE_DIR)../.claude/skills)
LINK_DIR     := $(abspath $(MAKEFILE_DIR)skills)

SKILL_DIRS   := $(wildcard $(SKILLS_SRC)/*)
LINK_TARGETS := $(foreach d,$(SKILL_DIRS),$(LINK_DIR)/my-$(notdir $(d)))

.PHONY: all sync clean re-sync list

all: sync

sync: $(LINK_TARGETS)

$(LINK_DIR)/my-%: $(SKILLS_SRC)/%
	ln -sfn $< $@

clean:
	rm -f $(LINK_DIR)/my-*

re-sync: clean sync

list:
	@ls -la $(LINK_DIR) | grep -- my- || echo "(no my-* links found)"
