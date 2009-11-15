import re
from pprint import pprint

class PhraseFilter:
    
    def __init__(self):
        self.phrases = {}
        
    def run(self, text, storyid):
        chunks = self.chunk(text)
        self.count_phrases(chunks, storyid)
    
    def print_phrases(self):
        pprint(self.phrases)
        
    def phrases(self):
        return self.phrases
        
    # ===========
    # = Chunker =
    # ===========
    
    def chunk(self, text):
        chunks = re.split('[^a-zA-Z-]+', text)[:-1]
        # chunks = self._lowercase(chunks)
        return chunks
        
    def _lowercase(self, chunks):
        return [c.lower() for c in chunks]
        
    # ==================
    # = Phrase Counter =
    # ==================
    
    def count_phrases(self, chunks, storyid):
        for l in range(1, len(chunks)):
            combinations = self._get_combinations(chunks, l)
            # print "Combinations: %s" % combinations
            for phrase in combinations:
                if phrase not in self.phrases:
                    self.phrases[phrase] = []
                if storyid not in self.phrases[phrase]:
                    self.phrases[phrase].append(storyid)
                
    def _get_combinations(self, chunks, length):
        combinations = []
        for i, chunk in enumerate(chunks):
            # 0,1,2,3,4,5,6 = 01 12 23 34 45 56
            combination = []
            for l in range(length):
                if i+l < len(chunks):
                    # print i, l, chunks[i+l], len(chunks)
                    combination.append(chunks[i+l])
            combinations.append(' '.join(combination))
        return combinations
    
    # =================
    # = Phrase Paring =
    # =================
    
    def pare_phrases(self):
        # Kill singles
        for phrase, counts in self.phrases.items():
            if len(counts) < 2:
                del self.phrases[phrase]
                
        # Kill repeats
        for phrase in self.phrases.keys():
            for phrase2 in self.phrases.keys():
                if phrase in self.phrases and len(phrase2) > len(phrase) and phrase in phrase2 and phrase != phrase2:
                    del self.phrases[phrase]
        
if __name__ == '__main__':
    phrasefilter = PhraseFilter()
    # phrasefilter.run('House of the Day: 123 Atlantic Ave. #3', 1)
    # phrasefilter.run('House of the Day: 456 Plankton St. #3', 4)
    # phrasefilter.run('Coop of the Day: 321 Pacific Ave.', 2)
    # phrasefilter.run('Coop of the Day: 456 Jefferson Ave.', 3)
    phrasefilter.run('Extra, Extra', 1)
    phrasefilter.run('Extra, Extra', 2)
    phrasefilter.run('Early Addition', 3)
    phrasefilter.run('Early Addition', 4)

    phrasefilter.pare_phrases()
    phrasefilter.print_phrases()
    