all: docs ../docs/index.html

docs: $(patsubst %.xml,../docs/%.html, error/*.xml warning/*.xml info/*.xml)

../docs/%.html: %.xml
	./build-html-docs.py template.html ../docs $<

../docs/index.html: docs-index-header.html error/*.xml warning/*.xml info/*.xml docs-index-footer.html build-docs-index.py
	./build-docs-index.py
