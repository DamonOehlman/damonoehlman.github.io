# tools
blockdown = `npm bin`/blockdown
injectcode = `npm bin`/injectcode

# gather the posts that we are going to build
posts = $(patsubst %.md,%.html,$(subst src/,,$(wildcard src/posts/*.md)))

all: clean index.html $(posts)

index.html:
	@echo "generating index"
	@$(blockdown) template.html < src/index.md > index.html

$(posts):
	@mkdir -p posts
	@echo "generating $@"
	@$(blockdown) template.html < src/$(patsubst %.html,%.md,$@) > $@

clean:
	@rm -rf index.html
	@rm -rf posts/
