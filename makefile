build: tester
	rm -rf public
	hugo
test:
	ls -a
local:
	hugo server -w --disableFastRender
dynpages:
	cd tools && \
		elm make --optimize --output=sample.js ./src/Sample.elm && \
		uglifyjs sample.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | uglifyjs --mangle --output sample.min.js && \
		mv sample.min.js ../static/sample/sample.min.js && \
		rm sample.js
tester:
	cd tools && echo test && \
	echo test2 && \
	echo test3
	

