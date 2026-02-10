.PHONY: serve drafts build clean post draft publish install test

# Start local server
serve:
	bundle exec jekyll serve

# Start local server with drafts
drafts:
	bundle exec jekyll serve --drafts

# Build the site
build:
	bundle exec jekyll build

# Clean generated files
clean:
	bundle exec jekyll clean

# Create a new post: make post NAME="my-post-title"
post:
	bundle exec jekyll post "$(NAME)"

# Create a new draft: make draft NAME="my-draft-title"
draft:
	bundle exec jekyll draft "$(NAME)"

# Publish a draft: make publish NAME="my-draft-title"
publish:
	bundle exec jekyll publish "$(NAME)"

# Install dependencies
install:
	bundle install

# Run HTML proofer
test:
	bundle exec htmlproofer _site
