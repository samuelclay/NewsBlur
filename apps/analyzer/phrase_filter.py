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
        
    def get_phrases(self):
        return self.phrases.keys()
        
    # ===========
    # = Chunker =
    # ===========
    
    def chunk(self, text):
        chunks = [t.strip() for t in re.split('[^a-zA-Z-]+', text) if t]
        # chunks = self._lowercase(chunks)
        return chunks
        
    def _lowercase(self, chunks):
        return [c.lower() for c in chunks]
        
    # ==================
    # = Phrase Counter =
    # ==================
    
    def count_phrases(self, chunks, storyid):
        for l in range(1, len(chunks)+1):
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
                continue
            if len(phrase) < 4:
                del self.phrases[phrase]
                continue
                
        # Kill repeats
        for phrase in self.phrases.keys():
            for phrase2 in self.phrases.keys():
                if phrase in self.phrases and len(phrase2) > len(phrase) and phrase in phrase2 and phrase != phrase2:
                    del self.phrases[phrase]
        
if __name__ == '__main__':
    phrasefilter = PhraseFilter()
    phrasefilter.run('House of the Day: 123 Atlantic Ave. #3', 1)
    phrasefilter.run('House of the Day: 456 Plankton St. #3', 4)
    phrasefilter.run('Coop of the Day: 321 Pacific St.', 2)
    phrasefilter.run('Streetlevel: 393 Pacific St.', 11)
    phrasefilter.run('Coop of the Day: 456 Jefferson Ave.', 3)
    phrasefilter.run('Extra, Extra', 5)
    phrasefilter.run('Extra, Extra', 6)
    phrasefilter.run('Early Addition', 7)
    phrasefilter.run('Early Addition', 8)
    phrasefilter.run('Development Watch', 9)
    phrasefilter.run('Streetlevel', 10)
    
    phrasefilter.pare_phrases()
    phrasefilter.print_phrases()
    