blockdown = `npm bin`/blockdown
injectcode = `npm bin`/injectcode
outputfiles = $(filter-out template.html,$(wildcard *.html))
posts = $(patsubst %.md,%.html,$(subst src/,,$(wildcard src/posts/*.md)))
tutorials = $(patsubst %.md,tutorial-%.html,$(subst src/tutorials/,,$(wildcard src/tutorials/*.md)))
samples = $(subst code/,js/samples/,$(wildcard code/*.js))
githubcontent = https://raw.githubusercontent.com
baseurl_remote ?= ${githubcontent}/rtc-io

all: clean $(posts)

$(posts):
	@mkdir -p posts
	@$(blockdown) template.html < src/$(patsubst %.html,%.md,$@) > $@

clean:
	@rm -rf index.html
	@rm -rf posts/
	@echo $(posts)
