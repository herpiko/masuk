.PHONY: build install clean release test

build:
	cargo build
	cp ./target/release/masuk .

release:
	cargo build --release

install:
	cargo install --path .

clean:
	cargo clean

test:
	cargo test

run:
	cargo run --

help:
	@echo "Available targets:"
	@echo "  build    - Build debug version"
	@echo "  release  - Build optimized release version"
	@echo "  install  - Install binary to ~/.cargo/bin"
	@echo "  clean    - Remove build artifacts"
	@echo "  test     - Run tests"
	@echo "  run      - Run in debug mode"
	@echo "  help     - Show this help message"
