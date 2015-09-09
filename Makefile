.PHONY: build
build:
	rake
ib:
	rake ib
cp:
	cp -r build/MacOSX-10.10-Development/Gyaim.app ~/Library/Input\ Methods/
clean:
	rake clean
kill:
	-killall Gyaim

all: clean ib build
update: kill cp


