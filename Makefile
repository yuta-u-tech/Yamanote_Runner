SCHEME=YamanoteRunner
PROJECT=YamanoteRunner.xcodeproj
DERIVED_DATA=.build
SIMULATOR=iPhone 17
BUNDLE_ID=com.youbo0129ueno.YamanoteRunner

.PHONY: build test boot install launch launch-preview run run-preview clean

build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk iphonesimulator \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		build

test:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		test

boot:
	xcrun simctl boot "$(SIMULATOR)" || true

install:
	xcrun simctl install booted $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(SCHEME).app

launch:
	xcrun simctl launch booted $(BUNDLE_ID)

launch-preview:
	xcrun simctl launch booted $(BUNDLE_ID) -dummy

run: build boot install launch

run-preview: build boot install launch-preview

clean:
	rm -rf $(DERIVED_DATA)
