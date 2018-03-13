all: lint test

lint:
	@echo "Running shellcheck"
	@./tests/lint.sh || exit 1

test:
	@echo "Running tests"
	@cd tests; ./tests.sh || exit 1
