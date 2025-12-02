# Makefile for wifi-location macOS app

APP_NAME = wifi-location
BUNDLE_NAME = $(APP_NAME).app
BINARY_NAME = wifi-location
BUILD_DIR = build
BUNDLE_DIR = $(BUILD_DIR)/$(BUNDLE_NAME)
CONTENTS_DIR = $(BUNDLE_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

# Go build flags
CGO_ENABLED = 1
GOARCH = $(shell uname -m | sed 's/x86_64/amd64/;s/arm64/arm64/')

.PHONY: all clean build install

all: build

build: clean
	@echo "Building $(APP_NAME) for macOS..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)

	@echo "Compiling Go binary with CGO..."
	CGO_ENABLED=$(CGO_ENABLED) GOOS=darwin GOARCH=$(GOARCH) \
		go build -o $(MACOS_DIR)/$(BINARY_NAME) .

	@echo "Copying Info.plist..."
	@cp Info.plist $(CONTENTS_DIR)/

	@echo "Setting executable permissions..."
	@chmod +x $(MACOS_DIR)/$(BINARY_NAME)

	@echo "✓ Build complete: $(BUNDLE_DIR)"

install: build
	@echo "Installing app bundle to ~/Applications/..."
	@mkdir -p ~/Applications
	@cp -r $(BUNDLE_DIR) ~/Applications/
	@codesign --force --deep --sign "Developer ID Application: Matthew Michie (TKW6ZHQF5Y)" ~/Applications/$(BUNDLE_NAME)

	@echo "Copying wrapper script to ~/bin/..."
	@cp launcher.sh ~/bin/$(BINARY_NAME)
	@chmod +x ~/bin/$(BINARY_NAME)
	@echo "✓ Installed app to ~/Applications/$(BUNDLE_NAME)"
	@echo "✓ Installed wrapper to ~/bin/$(BINARY_NAME)"

clean:
	@echo "Cleaning build directory..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Clean complete"

test: build
	@echo "Testing $(APP_NAME)..."
	@echo "Running app bundle..."
	@$(MACOS_DIR)/$(BINARY_NAME)

help:
	@echo "Available targets:"
	@echo "  make build   - Build the .app bundle"
	@echo "  make install - Build and install to ~/bin/bin/"
	@echo "  make clean   - Remove build artifacts"
	@echo "  make test    - Build and test the app"
	@echo "  make help    - Show this help message"
