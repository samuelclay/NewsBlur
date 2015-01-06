modules = [
    'testUri',
    'testXmlEncoding',
    'testXmlEncodingDecode',
    'testMediaTypes',
    'testHowtoNs',
    'validtest',
]

if __name__ == '__main__':
    import os, sys, unittest

    srcdir = os.path.join(os.path.dirname(os.path.abspath(__file__)),'src')
    testdir = os.path.join(srcdir,'tests')
    sys.path.insert(0,srcdir)
    sys.path.insert(0,testdir)

    suite = unittest.TestSuite()
    for module in modules:
        suite.addTest(__import__(module).buildTestSuite())
    unittest.TextTestRunner().run(suite)
