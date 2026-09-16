APP    = KeepAwake
BUNDLE = com.nhat.keepawake
UID   := $(shell id -u)

.PHONY: all build test install uninstall screenshot clean

all: build

## build + install KeepAwake.app to /Applications
build:
	./build.sh

## run the unit tests (plain executable — works with Command Line Tools alone)
test:
	swift run KeepAwakeTests

## alias for build (build.sh already installs to /Applications)
install: build

## quit, remove the app, LaunchAgent, and any stray caffeinate
uninstall:
	-pkill -f "$(APP).app/Contents/MacOS/$(APP)" 2>/dev/null || true
	-pkill -f "/usr/bin/caffeinate -dimu" 2>/dev/null || true
	-launchctl bootout gui/$(UID)/$(BUNDLE) 2>/dev/null || true
	rm -f "$(HOME)/Library/LaunchAgents/$(BUNDLE).plist"
	rm -rf "/Applications/$(APP).app"
	@echo "Uninstalled $(APP)."

## regenerate docs/screenshot.png from mockup.swift
screenshot:
	@mkdir -p build docs
	swiftc -O mockup.swift -o build/mockup
	./build/mockup docs/screenshot.png
	@echo "Wrote docs/screenshot.png"

## remove build artifacts
clean:
	rm -rf build .build
