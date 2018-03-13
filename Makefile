all: lint test

lint:
	@echo "Running shellcheck"
	@echo $(PWD)
	@ls
	@bash -c "tests/lint.sh" || exit 1

test:
	@echo "Running tests"
	@bash -c "cd tests; ./tests.sh" || exit 1
