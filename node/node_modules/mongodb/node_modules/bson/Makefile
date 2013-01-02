NODE = node
NPM = npm
NODEUNIT = node_modules/nodeunit/bin/nodeunit

all:	clean node_gyp

test: clean node_gyp
	npm test

node_gyp: clean
	node-gyp configure build

clean:
	node-gyp clean

.PHONY: all
