toolname?=Sample
modtoolname=`echo $(toolname) | tr A-Z a-z`
ipaddr=`ipconfig getifaddr en0`

build:
	rm -rf public
	hugo
test:
	ls -a
local:
	hugo server --baseURL="$(ipaddr)"  --bind="0.0.0.0" -p 8000 -w --disableFastRender
dynpages:
	cd tools && \
	elm make --optimize --output=$(modtoolname).js ./src/$(toolname).elm && \
	uglifyjs $(modtoolname).js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | uglifyjs --mangle --output $(modtoolname).min.js && \
	mv $(modtoolname).min.js ../static/toolsjs/$(modtoolname).min.js && \
	rm $(modtoolname).js
	

