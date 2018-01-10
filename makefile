build:
	rm -rf public
	hugo
test:
	ls -a
local:
	hugo server -w
