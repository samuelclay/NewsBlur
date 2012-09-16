NODE = node
NPM = npm
NODEUNIT = node_modules/nodeunit/bin/nodeunit
name = all

total: build_native

test: build_native
	$(NODEUNIT) ./test/node
	TEST_NATIVE=TRUE $(NODEUNIT) ./test/node

build_native:
	$(MAKE) -C ./ext all

build_native_debug:
	$(MAKE) -C ./ext all_debug

build_native_clang:
	$(MAKE) -C ./ext clang

build_native_clang_debug:
	$(MAKE) -C ./ext clang_debug

clean_native:
	$(MAKE) -C ./ext clean

clean:
	rm ./ext/bson.node
	rm -r ./ext/build

.PHONY: total
