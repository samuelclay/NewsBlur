import re

class Tokenizer:
    """A simple regex-based whitespace tokenizer.
    It expects a string and can return all tokens lower-cased
    or in their existing case.
    """
    
    WORD_RE = re.compile('[^a-zA-Z-]+')

    def __init__(self, phrases, lower=False):
        self.phrases = phrases
        self.lower = lower
        
    def tokenize(self, doc):
        print doc
        formatted_doc = ' '.join(self.WORD_RE.split(doc))
        print formatted_doc
        for phrase in self.phrases:
            if phrase in formatted_doc:
                yield phrase
                
if __name__ == '__main__':
    phrases = ['Extra Extra', 'Streetlevel', 'House of the Day']
    tokenizer = Tokenizer(phrases)

    doc = 'Extra, Extra'
    tokenizer.tokenize(doc)