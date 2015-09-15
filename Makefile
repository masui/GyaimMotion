.PHONY: build
build:
	rake
ib:
	rake ib
cp:
	/bin/rm -r ~/Library/Input\ Methods/Gyaim.app
	cp -r build/MacOSX-10.10-Development/Gyaim.app ~/Library/Input\ Methods/
clean:
	rake clean
kill:
	-killall Gyaim
test:
	rake spec
dmg:
	/bin/rm -f Gyaim.dmg
	hdiutil create -srcfolder build/MacOSX-10.10-Development/Gyaim.app -volname Gyaim Gyaim.dmg
	scp Gyaim.dmg pitecan.com:/www/www.pitecan.com/tmp

all: clean ib build
update: kill cp


