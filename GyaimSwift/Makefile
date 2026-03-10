DERIVED_DATA = $(PWD)/.build

.PHONY: generate build install kill update test clean dmg

generate:
	xcodegen generate

build: generate
	xcodebuild build \
		-project Gyaim.xcodeproj \
		-scheme Gyaim \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA)

install: build
	rm -rf ~/Library/Input\ Methods/Gyaim.app
	cp -r $(DERIVED_DATA)/Build/Products/Debug/Gyaim.app ~/Library/Input\ Methods/

kill:
	-killall Gyaim

update: kill install

test: generate
	xcodebuild test \
		-project Gyaim.xcodeproj \
		-scheme GyaimTests \
		-derivedDataPath $(DERIVED_DATA)

clean:
	rm -rf $(DERIVED_DATA) Gyaim.xcodeproj

dmg: build
	hdiutil create -srcfolder $(DERIVED_DATA)/Build/Products/Release/Gyaim.app \
		-volname Gyaim -o Gyaim.dmg
