KDRFC   = kramdown-rfc
XML2RFC = xml2rfc --v3
IDDIFF  = iddiff
IDNITS  = idnits
MKDIR   = mkdir -p
CURL    = curl
GIT     = git
RM      = rm -f

SRCFILE = draft.md

DISTDIR = dist
PREVDIR = $(DISTDIR)/previous_version

DOCNAME = $(shell grep "^docname:" $(SRCFILE) | sed 's/docname:[[:space:]]\([a-z0-9-]\{1,\}\).*/\1/')
REPLACES ?=

AUTH   = $(word 2,$(subst -, ,$(DOCNAME)))
VERNUM = $(lastword $(subst -, ,$(DOCNAME)))

ifneq ($(REPLACES),)
PREVNAME := $(REPLACES)
DIFFNAME := $(DOCNAME)-from-$(REPLACES)
else ifneq ($(VERNUM),00)
PREVNUM  := $(shell expr $(VERNUM) - 1 | awk '{printf "%02d",$$1}')
PREVNAME := $(shell echo $(DOCNAME) | sed 's/-[0-9][0-9]$$//')-$(PREVNUM)
DIFFNAME := $(DOCNAME)-from-$(PREVNUM)
endif

XMLFILE  = $(DISTDIR)/$(DOCNAME).xml
TXTFILE  = $(DISTDIR)/$(DOCNAME).txt
HTMLFILE = $(DISTDIR)/$(DOCNAME).html
PREVFILE = $(PREVDIR)/$(PREVNAME).txt
DIFFFILE = $(DISTDIR)/$(DIFFNAME).html

.PHONY: all xml txt html diff idnits tag bump git-isclean git-isdefault clean cleanall

all: txt

$(DISTDIR):
	@$(MKDIR) $@

$(PREVDIR):
	@$(MKDIR) $@

$(XMLFILE): $(SRCFILE) $(DISTDIR)
	@$(KDRFC) $< > $@
	@echo "Remember to run \"make tag\" after submitting this I-D to the datatracker."

$(TXTFILE): $(XMLFILE)
	@$(XML2RFC) --text $<

$(HTMLFILE): $(XMLFILE)
	@$(XML2RFC) --html $<

$(PREVFILE): $(PREVDIR)
ifeq ($(PREVNAME),)
	$(error Cannot find previous version)
endif
	@$(CURL) https://www.ietf.org/archive/id/$(PREVNAME).txt --output $@

$(DIFFFILE): $(PREVFILE) $(TXTFILE)
	@$(IDDIFF) $^ > $@
	@echo "Created diff file $@"

xml: $(XMLFILE)

txt: $(TXTFILE)

html: $(HTMLFILE)

diff: $(DIFFFILE)

idnits: $(XMLFILE)
	@$(IDNITS) $<

tag: git-isdefault git-isclean
	@$(GIT) tag -a $(DOCNAME) -m "Submitted document $(DOCNAME)"
	@echo "Tag $(DOCNAME) successfully created."
	@echo
	@echo "Don't forget to push it with:"
	@echo "   $(GIT) push --tags"
	@echo
	@echo "If not done already, you may delete the old revision branch with:"
	@echo "   $(GIT) branch -d revision/$(AUTH)-$(VERNUM); $(GIT) remote prune origin"
	@echo
	@echo "You may also initialize a new revision with:"
	@echo "   make bump"
	@echo

bump: git-isdefault git-isclean
	$(eval NEXTVERNUM := $(shell expr $(VERNUM) + 1 | awk '{printf "%02d",$$1}'))
	@$(GIT) checkout -b revision/$(AUTH)-$(NEXTVERNUM)
	@sed -i 's/^\(docname:[[:space:]][a-z0-9-]\{1,\}-\)[0-9]\{1,\}/\1$(NEXTVERNUM)/' $(SRCFILE)
	@$(GIT) add $(SRCFILE)
	@$(GIT) commit -m "bump to revision $(AUTH)-$(NEXTVERNUM)"
	@echo "Push the new branch with:"
	@echo "   $(GIT) push -u origin revision/$(AUTH)-$(NEXTVERNUM)"
	@echo

git-isclean:
	$(eval GITSTATUS := $(shell $(GIT) status --porcelain --untracked-files=no))
ifneq ($(GITSTATUS),)
	$(error Working directory is dirty)
endif

git-isdefault:
	$(eval GITBRANCH := $(shell $(GIT) rev-parse --abbrev-ref HEAD))
ifeq ($(filter $(GITBRANCH),master main),)
	$(error Not on master or main branch)
endif

clean:
	@$(RM) $(DISTDIR)/*.txt $(DISTDIR)/*.html $(DISTDIR)/*.xml

cleanall: clean
	@$(RM) $(PREVFILE)
	@rmdir $(PREVDIR) $(DISTDIR)