deps:
	go get -u github.com/ernestio/bash-nats

dev-deps:
	jruby -S bundle install

lint:
	jruby -S bundle exec rubocop

test:
	jruby -S bundle exec rspec spec
