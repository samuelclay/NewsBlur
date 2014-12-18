#!/bin/sh

PYTHON=${1:-${PYTHON:-python}}

# Run all project tests

cd "`dirname "$0"`"

${PYTHON} validtest.py

# Make sure XML encoding detection works
${PYTHON} tests/genXmlTestcases.py && python tests/testXmlEncoding.py

# Confirm that XML is decoded correctly
${PYTHON} tests/testXmlEncodingDecode.py

# Make sure media type checks are consistent
${PYTHON} tests/testMediaTypes.py

# Test URI equivalence
${PYTHON} tests/testUri.py

# Ensure check.cgi runs cleanly, at least for a GET
PYTHONPATH="`pwd`/tests:." REQUEST_METHOD=GET FEEDVALIDATOR_HOME="`pwd`/.." python - <../check.cgi >/dev/null || echo >&2 "check.cgi failed to run"
