all:
	mix deps.get
	mix deps.compile
	mix escript.build
tests: all
	mix test --trace
plugins: all
	rm rabbitmq-plugins
	ln -s rabbitmqctl rabbitmq-plugins
