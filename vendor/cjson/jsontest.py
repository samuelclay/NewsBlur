#!/usr/bin/python
# -*- coding: latin2 -*-

## this test suite is an almost verbatim copy of the jsontest.py test suite
## found in json-py available from http://sourceforge.net/projects/json-py/
## Copyright (C) 2005  Patrick D. Logan

## 2007-03-15 - Viktor Ferenczi (python@cx.hu)
## Added unit tests for encoder/decoder extensions.
## Added throughput measurement.
## Typical values on a 3.0GHz Intel P4: about 8Mbytes/s

## 2007-04-02 - Viktor Ferenczi (python@cx.hu)
## Added unit test for encoding with automatic dict key to str conversion.

## 2007-05-04 - Viktor Ferenczi (python@cx.hu)
## Added unit tests for unicode encoding/decoding.
## More realistic, grid like data used for performance tests.

import re
import time
import math
import unittest
import datetime

import cjson
_exception = cjson.DecodeError

# The object tests should be order-independent. They're not.
# i.e. they should test for existence of keys and values
# with read/write invariance.

def _removeWhitespace(str):
    return str.replace(" ", "")

class JsonTest(unittest.TestCase):
    def testReadEmptyObject(self):
        obj = cjson.decode("{}")
        self.assertEqual({}, obj)

    def testWriteEmptyObject(self):
        s = cjson.encode({})
        self.assertEqual("{}", _removeWhitespace(s))

    def testReadStringValue(self):
        obj = cjson.decode('{ "name" : "Patrick" }')
        self.assertEqual({ "name" : "Patrick" }, obj)

    def testReadEscapedQuotationMark(self):
        obj = cjson.decode(r'"\""')
        self.assertEqual(r'"', obj)

#    def testReadEscapedSolidus(self):
#        obj = cjson.decode(r'"\/"')
#        self.assertEqual(r'/', obj)

    def testReadEscapedReverseSolidus(self):
        obj = cjson.decode(r'"\\"')
        self.assertEqual("\\", obj)

    def testReadEscapedBackspace(self):
        obj = cjson.decode(r'"\b"')
        self.assertEqual("\b", obj)

    def testReadEscapedFormfeed(self):
        obj = cjson.decode(r'"\f"')
        self.assertEqual("\f", obj)

    def testReadEscapedNewline(self):
        obj = cjson.decode(r'"\n"')
        self.assertEqual("\n", obj)

    def testReadEscapedCarriageReturn(self):
        obj = cjson.decode(r'"\r"')
        self.assertEqual("\r", obj)

    def testReadEscapedHorizontalTab(self):
        obj = cjson.decode(r'"\t"')
        self.assertEqual("\t", obj)

    def testReadEscapedHexCharacter(self):
        obj = cjson.decode(r'"\u000A"')
        self.assertEqual("\n", obj)
        obj = cjson.decode(r'"\u1001"')
        self.assertEqual(u'\u1001', obj)

    def testWriteEscapedQuotationMark(self):
        s = cjson.encode(r'"')
        self.assertEqual(r'"\""', _removeWhitespace(s))

    def testWriteEscapedSolidus(self):
        s = cjson.encode(r'/')
        #self.assertEqual(r'"\/"', _removeWhitespace(s))
        self.assertEqual('"/"', _removeWhitespace(s))

    def testWriteNonEscapedSolidus(self):
        s = cjson.encode(r'/')
        self.assertEqual(r'"/"', _removeWhitespace(s))

    def testWriteEscapedReverseSolidus(self):
        s = cjson.encode("\\")
        self.assertEqual(r'"\\"', _removeWhitespace(s))

    def testWriteEscapedBackspace(self):
        s = cjson.encode("\b")
        self.assertEqual(r'"\b"', _removeWhitespace(s))

    def testWriteEscapedFormfeed(self):
        s = cjson.encode("\f")
        self.assertEqual(r'"\f"', _removeWhitespace(s))

    def testWriteEscapedNewline(self):
        s = cjson.encode("\n")
        self.assertEqual(r'"\n"', _removeWhitespace(s))

    def testWriteEscapedCarriageReturn(self):
        s = cjson.encode("\r")
        self.assertEqual(r'"\r"', _removeWhitespace(s))

    def testWriteEscapedHorizontalTab(self):
        s = cjson.encode("\t")
        self.assertEqual(r'"\t"', _removeWhitespace(s))

    def testWriteEscapedHexCharacter(self):
        s = cjson.encode(u'\u1001')
        self.assertEqual(r'"\u1001"', _removeWhitespace(s))

    def testReadBadEscapedHexCharacter(self):
        self.assertRaises(_exception, self.doReadBadEscapedHexCharacter)

    def doReadBadEscapedHexCharacter(self):
        cjson.decode('"\u10K5"')

    def testReadBadObjectKey(self):
        self.assertRaises(_exception, self.doReadBadObjectKey)

    def doReadBadObjectKey(self):
        cjson.decode('{ 44 : "age" }')

    def testReadBadArray(self):
        self.assertRaises(_exception, self.doReadBadArray)

    def doReadBadArray(self):
        cjson.decode('[1,2,3,,]')
        
    def testReadBadObjectSyntax(self):
        self.assertRaises(_exception, self.doReadBadObjectSyntax)

    def doReadBadObjectSyntax(self):
        cjson.decode('{"age", 44}')

    def testWriteStringValue(self):
        s = cjson.encode({ "name" : "Patrick" })
        self.assertEqual('{"name":"Patrick"}', _removeWhitespace(s))

    def testReadIntegerValue(self):
        obj = cjson.decode('{ "age" : 44 }')
        self.assertEqual({ "age" : 44 }, obj)

    def testReadNegativeIntegerValue(self):
        obj = cjson.decode('{ "key" : -44 }')
        self.assertEqual({ "key" : -44 }, obj)
        
    def testReadFloatValue(self):
        obj = cjson.decode('{ "age" : 44.5 }')
        self.assertEqual({ "age" : 44.5 }, obj)

    def testReadNegativeFloatValue(self):
        obj = cjson.decode(' { "key" : -44.5 } ')
        self.assertEqual({ "key" : -44.5 }, obj)

    def testReadBadNumber(self):
        self.assertRaises(_exception, self.doReadBadNumber)

    def doReadBadNumber(self):
        cjson.decode('-44.4.4')

    def testReadSmallObject(self):
        obj = cjson.decode('{ "name" : "Patrick", "age":44} ')
        self.assertEqual({ "age" : 44, "name" : "Patrick" }, obj)        

    def testReadEmptyArray(self):
        obj = cjson.decode('[]')
        self.assertEqual([], obj)

    def testWriteEmptyArray(self):
        self.assertEqual("[]", _removeWhitespace(cjson.encode([])))

    def testReadSmallArray(self):
        obj = cjson.decode(' [ "a" , "b", "c" ] ')
        self.assertEqual(["a", "b", "c"], obj)

    def testWriteSmallArray(self):
        self.assertEqual('[1,2,3,4]', _removeWhitespace(cjson.encode([1, 2, 3, 4])))

    def testWriteSmallObject(self):
        s = cjson.encode({ "name" : "Patrick", "age": 44 })
        self.assertEqual('{"age":44,"name":"Patrick"}', _removeWhitespace(s))

    def testWriteFloat(self):
        self.assertEqual("3.44556677", _removeWhitespace(cjson.encode(3.44556677)))

    def testReadTrue(self):
        self.assertEqual(True, cjson.decode("true"))

    def testReadFalse(self):
        self.assertEqual(False, cjson.decode("false"))

    def testReadNull(self):
        self.assertEqual(None, cjson.decode("null"))

    def testWriteTrue(self):
        self.assertEqual("true", _removeWhitespace(cjson.encode(True)))

    def testWriteFalse(self):
        self.assertEqual("false", _removeWhitespace(cjson.encode(False)))

    def testWriteNull(self):
        self.assertEqual("null", _removeWhitespace(cjson.encode(None)))

    def testReadArrayOfSymbols(self):
        self.assertEqual([True, False, None], cjson.decode(" [ true, false,null] "))

    def testWriteArrayOfSymbolsFromList(self):
        self.assertEqual("[true,false,null]", _removeWhitespace(cjson.encode([True, False, None])))

    def testWriteArrayOfSymbolsFromTuple(self):
        self.assertEqual("[true,false,null]", _removeWhitespace(cjson.encode((True, False, None))))

    def testReadComplexObject(self):
        src = '''
    { "name": "Patrick", "age" : 44, "Employed?" : true, "Female?" : false, "grandchildren":null }
'''
        obj = cjson.decode(src)
        self.assertEqual({"name":"Patrick","age":44,"Employed?":True,"Female?":False,"grandchildren":None}, obj)

    def testReadLongArray(self):
        src = '''[    "used",
    "abused",
    "confused",
    true, false, null,
    1,
    2,
    [3, 4, 5]]
'''
        obj = cjson.decode(src)
        self.assertEqual(["used","abused","confused", True, False, None,
                          1,2,[3,4,5]], obj)

    def testReadIncompleteArray(self):
        self.assertRaises(_exception, self.doReadIncompleteArray)

    def doReadIncompleteArray(self):
        cjson.decode('[')

    def testReadComplexArray(self):
        src = '''
[
    { "name": "Patrick", "age" : 44,
      "Employed?" : true, "Female?" : false,
      "grandchildren":null },
    "used",
    "abused",
    "confused",
    1,
    2,
    [3, 4, 5]
]
'''
        obj = cjson.decode(src)
        self.assertEqual([{"name":"Patrick","age":44,"Employed?":True,"Female?":False,"grandchildren":None},
                          "used","abused","confused",
                          1,2,[3,4,5]], obj)

    def testWriteComplexArray(self):
        obj = [{"name":"Patrick","age":44,"Employed?":True,"Female?":False,"grandchildren":None},
               "used","abused","confused",
               1,2,[3,4,5]]
        self.assertEqual('[{"Female?":false,"age":44,"name":"Patrick","grandchildren":null,"Employed?":true},"used","abused","confused",1,2,[3,4,5]]',
                         _removeWhitespace(cjson.encode(obj)))


    def testReadWriteCopies(self):
        orig_obj = {'a':' " '}
        json_str = cjson.encode(orig_obj)
        copy_obj = cjson.decode(json_str)
        self.assertEqual(orig_obj, copy_obj)
        self.assertEqual(True, orig_obj == copy_obj)
        self.assertEqual(False, orig_obj is copy_obj)

    def testStringEncoding(self):
        s = cjson.encode([1, 2, 3])
        self.assertEqual(unicode("[1,2,3]", "utf-8"), _removeWhitespace(s))

    def testReadEmptyObjectAtEndOfArray(self):
        self.assertEqual(["a","b","c",{}],
                         cjson.decode('["a","b","c",{}]'))

    def testReadEmptyObjectMidArray(self):
        self.assertEqual(["a","b",{},"c"],
                         cjson.decode('["a","b",{},"c"]'))

    def testReadClosingObjectBracket(self):
        self.assertEqual({"a":[1,2,3]}, cjson.decode('{"a":[1,2,3]}'))

    def testEmptyObjectInList(self):
        obj = cjson.decode('[{}]')
        self.assertEqual([{}], obj)

    def testObjectWithEmptyList(self):
        obj = cjson.decode('{"test": [] }')
        self.assertEqual({"test":[]}, obj)

    def testObjectWithNonEmptyList(self):
        obj = cjson.decode('{"test": [3, 4, 5] }')
        self.assertEqual({"test":[3, 4, 5]}, obj)

    def testWriteLong(self):
        self.assertEqual("12345678901234567890", cjson.encode(12345678901234567890))
        
    def testEncoderExtension(self):
        def dateEncoder(d):
            assert isinstance(d, datetime.date)
            return 'new Date(Date.UTC(%d,%d,%d))'%(d.year, d.month, d.day)
        self.assertEqual(cjson.encode([1,datetime.date(2007,1,2),2], extension=dateEncoder), '[1, new Date(Date.UTC(2007,1,2)), 2]')
        self.assertRaises(cjson.EncodeError, lambda: cjson.encode(1, extension=0))

    def testDecoderExtension(self):
        re_date=re.compile('^new\sDate\(Date\.UTC\(.*?\)\)')
        def dateDecoder(json,idx):
            json=json[idx:]
            m=re_date.match(json)
            if not m: raise 'cannot parse JSON string as Date object: %s'%json[idx:]
            args=cjson.decode('[%s]'%json[18:m.end()-2])
            dt=datetime.date(*args)
            return (dt,m.end())
        self.assertEqual(cjson.decode('[1, new Date(Date.UTC(2007,1,2)), 2]', extension=dateDecoder), [1,datetime.date(2007,1,2),2])
        self.assertEqual(cjson.decode('[1, new Date(Date.UTC( 2007, 1 , 2 )) , 2]', extension=dateDecoder), [1,datetime.date(2007,1,2),2])
        self.assertRaises(cjson.DecodeError, lambda: cjson.decode('1', extension=0))

    def testEncodeKey2Str(self):
        d={'1':'str 1', 1:'int 1', 3.1415:'pi'}
        self.assertRaises(cjson.EncodeError, lambda: cjson.encode(d))
        # NOTE: decode needed for order invariance
        self.assertEqual(cjson.decode(cjson.encode(d, key2str=True)),
            {"1": "str 1", "1": "int 1", "3.1415": "pi"})

    def testUnicodeEncode(self):
        self.assertEqual(cjson.encode({u'b':2}), '{"b": 2}')
        self.assertEqual(cjson.encode({'o"':u'öőüű'}), r'{"o\"": "\u00f6\u0151\u00fc\u0171"}')
        self.assertEqual(cjson.encode('öőüű', encoding='latin2'), r'"\u00f6\u0151\u00fc\u0171"') 
        self.assertRaises(cjson.EncodeError, lambda: cjson.encode('öőüű', encoding='ascii'))

    def testUnicodeDecode(self):
        self.assertEqual(cjson.decode('{"b": 2}', all_unicode=True), {u'b':2})
        self.assertEqual(cjson.decode(r'{"o\"": "\u00f6\u0151\u00fc\u0171"}'), {'o"':u'öőüű'})
        self.assertEqual(cjson.decode(r'{"o\"": "\u00f6\u0151\u00fc\u0171"}', encoding='latin2'), {'o"':'öőüű'})
        self.assertEqual(cjson.decode(ur'"\u00f6\u0151\u00fc\u0171"', all_unicode=True), u'öőüű')
        self.assertEqual(cjson.decode(r'"\u00f6\u0151\u00fc\u0171"', encoding='latin2'), 'öőüű')
        self.assertRaises(cjson.DecodeError, lambda: cjson.decode('"öőüű"', encoding='ascii'))
            
    def testUnicodeEncodeDecode(self):
        for s in ('abc', 'aáé', 'öőüű'):
            self.assertEqual(cjson.decode(cjson.encode(s)), s.decode('latin1'))

def measureEncoderThroughput(data):
    bytes=0
    st=time.time()
    cnt=0
    while True:
        dt=time.time()-st
        if dt>=0.5 and cnt>9: break
        bytes+=len(cjson.encode(data))
        cnt+=1
    return int(bytes/1024/dt)

def measureDecoderThroughput(data):
    json=cjson.encode(data)
    bytes=0
    st=time.time()
    cnt=0
    while True:
        dt=time.time()-st
        if dt>=0.5 and cnt>9: break
        cjson.decode(json)
        bytes+=len(json)
        cnt+=1
    return int(math.floor(bytes/dt/1024.0+0.5))

def measureThroughput():
    # Try to imitate realistic data, for example a large grid of records
    data=[
        dict([
            ('cell(%d,%d)'%(x,y), (
                None, False, True, 0, 1,
                x+y, x*y, math.pi, math.pi*x*y,
                'str(%d,%d)%s'%(x,y,'#'*(x/10)),
                u'unicode[%04X]:%s'%(x*y,unichr(x*y)),
            ))
            for x in xrange(y)
        ])
        for y in xrange(1,100)
    ]
    json=cjson.encode(data)
    print 'Test data: tuples in dicts in a list, %d bytes as JSON string'%len(json)
    print 'Encoder throughput: ~%d kbyte/s'%measureEncoderThroughput(data)
    print 'Decoder throughput: ~%d kbyte/s'%measureDecoderThroughput(data)

def main():
    try:
        unittest.main()
        #suite = unittest.TestLoader().loadTestsFromTestCase(JsonTest)
        #unittest.TextTestRunner(verbosity=2).run(suite)
    finally:
        measureThroughput()

if __name__ == '__main__':
    main()
