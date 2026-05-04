APP_NAME := caffinate
BUNDLE := build/$(APP_NAME).app
CONTENTS := $(BUNDLE)/Contents
MACOS := $(CONTENTS)/MacOS
RESOURCES := $(CONTENTS)/Resources
EXECUTABLE := $(MACOS)/$(APP_NAME)
SDK := $(shell xcrun --sdk macosx --show-sdk-path)
ARCH := $(shell uname -m)
DEPLOYMENT_TARGET ?= 13.0

.PHONY: build run clean

build:
	mkdir -p "$(MACOS)"
	mkdir -p "$(RESOURCES)"
	cp Sources/caffinate/Info.plist "$(CONTENTS)/Info.plist"
	cp Resources/caffinate.icns "$(RESOURCES)/caffinate.icns"
	swiftc \
		-module-cache-path build/ModuleCache \
		-sdk "$(SDK)" \
		-target "$(ARCH)-apple-macosx$(DEPLOYMENT_TARGET)" \
		-framework AppKit \
		-framework IOKit \
		-framework ServiceManagement \
		Sources/caffinate/main.swift \
		Sources/caffinate/AppDelegate.swift \
		-o "$(EXECUTABLE)"
	plutil -lint "$(CONTENTS)/Info.plist"
	xattr -cr "$(BUNDLE)"
	codesign --force --sign - "$(BUNDLE)" || codesign --remove-signature "$(BUNDLE)"

run: build
	open "$(BUNDLE)"

clean:
	rm -rf build
