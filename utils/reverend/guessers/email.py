# This module is part of the Divmod project and is Copyright 2003 Amir Bakhtiar:
# amir@divmod.org.  This is free software; you can redistribute it and/or
# modify it under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation.
#
        
from rfc822 import AddressList

from reverend.thomas import Bayes


class EmailClassifier(Bayes):

    def getTokens(self, msg):
        # Overide from parent
        # This should return a list of strings
        # which will be used as the key into
        # the table of token counts
        tokens = self.getHeaderTokens(msg)
        tokens += self.getBodyTokens(msg)
        
        # Get some tokens that are generated from the
        # header and the structure
        tokens += self.getMetaTokens(msg)
        return tokens

    def getBodyTokens(self, msg):
        text = self.getTextPlain(msg)
        if text is None:
            text =  ''
        tl = list(self._tokenizer.tokenize(text))
        return tl

    def getHeaderTokens(self, msg):
        subj = msg.get('subject','nosubject')
        text =  subj + ' '
        text +=  msg.get('from','fromnoone') + ' '
        text +=  msg.get('to','tonoone') + ' '
        text +=  msg.get('cc','ccnoone') + ' '
        tl = list(self._tokenizer.tokenize(text))
        return tl
          
    def getTextPlain(self, msg):
        for part in msg.walk():
            typ = part.get_content_type()
            if typ and typ.lower() == "text/plain":
                text = part.get_payload(decode=True)
                return text
        return None

    def getTextHtml(self, msg):
        for part in msg.walk():
            typ = part.get_content_type()
            if typ and typ.lower() == "text/html":
                text = part.get_payload(decode=False)
                return text
        return None

    def getMetaTokens(self, msg):
        r = []
        for f in ['Content-type', 'X-Priority', 'X-Mailer',
                  'content-transfer-encoding', 'X-MSMail-Priority']:
            r.append(f +':' + msg.get(f, 'None'))

        text = self.getTextPlain(msg)
        html = self.getTextHtml(msg)
            
        for stem, part in zip(['text','html'],[text,html]):
            if part is None:
                r.append(stem + '_None')
                continue
            else:
                r.append(stem + '_True')
        
            l = len(part.split())
            if l is 0:
                a = 'zero'
                r.append(stem + a)
            if l > 10000:
                a = 'more_than_10000'
                r.append(stem + a)
            if l > 1000:
                a = 'more_than_1000'
                r.append(stem + a)
            if l > 100:
                a = 'more_than_100'
                r.append(stem + a)

        t = msg.get('to','')
        at = AddressList(t).addresslist
        c = msg.get('cc','')
        ac = AddressList(c).addresslist
        
        if at > 5:
            r.append('to_more_than_5')
        if at > 10:
            r.append('to_more_than_10')
        if ac > 5:
            r.append('cc_more_than_5')
        if ac > 10:
            r.append('cc_more_than_10')
                
        return r
    
