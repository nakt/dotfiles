MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SKILLS_SRC   := $(abspath $(MAKEFILE_DIR)../.claude/skills)
LINK_DIR     := $(abspath $(MAKEFILE_DIR)skills)
CONFIG_SRC   := $(abspath $(MAKEFILE_DIR)config.toml)
CONFIG_OUT   := $(abspath $(MAKEFILE_DIR)config.local.toml)

SKILL_DIRS   := $(wildcard $(SKILLS_SRC)/*)
LINK_TARGETS := $(foreach d,$(SKILL_DIRS),$(LINK_DIR)/my-$(notdir $(d)))

.PHONY: all sync clean re-sync list export-config

all: sync

sync: $(LINK_TARGETS)

$(LINK_DIR)/my-%: $(SKILLS_SRC)/%
	ln -sfn $< $@

clean:
	rm -f $(LINK_DIR)/my-*

re-sync: clean sync

list:
	@ls -la $(LINK_DIR) | grep -- my- || echo "(no my-* links found)"

export-config:
	@tmp_file=$$(mktemp); \
	awk '\
		BEGIN { skip = 0 } \
		/^\[projects\./ { skip = 1; next } \
		/^\[/ { skip = 0 } \
		skip == 0 { print } \
	' "$(CONFIG_SRC)" > "$$tmp_file"; \
	if [ -f "$(CONFIG_OUT)" ] && cmp -s "$$tmp_file" "$(CONFIG_OUT)"; then \
		rm -f "$$tmp_file"; \
		printf "No changes in %s\n" "$(CONFIG_OUT)"; \
	else \
		mv "$$tmp_file" "$(CONFIG_OUT)"; \
		printf "Updated %s\n" "$(CONFIG_OUT)"; \
	fi
