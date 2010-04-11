# This module is part of the Divmod project and is Copyright 2003 Amir Bakhtiar:
# amir@divmod.org.  This is free software; you can redistribute it and/or
# modify it under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation.
#

from Tkinter import *
import tkFileDialog
import tkSimpleDialog
import tkMessageBox

import os

from util import Command, StatusBar, Notebook
from tester import TestView

class PoolView(Frame):
    def __init__(self, master=None, guesser=None, app=None):
        Frame.__init__(self, master, bg='lightblue3')
        self.pack()
        self.listView = Frame(self)
        self.listView.pack()
        bp = Button(self, text="New Pool", command=self.newPool)
        bp.pack(side=LEFT, anchor=SE)
        self.addLoadSave()
        self.columnHeadings()
        self.model = {}
        self.guesser = guesser
        self.app = app
        self.reload()

    def reload(self):
        self.listView.destroy()
        self.listView = Frame(self)
        self.listView.pack()
        for pool in self.guesser.poolNames():
            self.addPool(self.guesser.pools[pool])
        self.addPool(self.guesser.corpus, 'Total')

    def upload(self):
        pass
    
    def addLoadSave(self):
        frame = Frame(self)
        frame.pack(side=RIGHT)
        bp = Button(frame, text="Upload", command=self.upload, state=DISABLED)
        bp.pack(side=BOTTOM, fill=X)
        bp = Button(frame, text="Save", command=self.save)
        bp.pack(side=BOTTOM, fill=X)
        bp = Button(frame, text="Load", command=self.load)
        bp.pack(side=BOTTOM, fill=X)
    
    def addPool(self, pool, name=None):
        col=None
        tTok = IntVar()
        train = IntVar()
        line = Frame(self.listView)
        line.pack()
        if name is None:
            name = pool.name
            idx = self.guesser.poolNames().index(name)
            col = self.defaultColours()[idx]
        l = Label(line, text=name, anchor=W, width=10)
        l.grid(row=0, column=0)
        colourStripe = Label(line, text=' ', width=1, bg=col, anchor=W, relief=GROOVE)
        colourStripe.grid(row=0, column=1)
        train = IntVar()
        train.set(pool.trainCount)
        l = Label(line, textvariable=train, anchor=E, width=10, relief=SUNKEN)
        l.grid(row=0, column=2)
        uTok = IntVar()
        uTok.set(len(pool))
        l = Label(line, textvariable=uTok, anchor=E, width=12, relief=SUNKEN)
        l.grid(row=0, column=3)
        tTok = IntVar()
        tTok.set(pool.tokenCount)
        l = Label(line, textvariable=tTok, anchor=E, width=10, relief=SUNKEN)
        l.grid(row=0, column=4)
        self.model[name]=(pool, uTok, tTok, train)

    def refresh(self):
        for pool, ut, tt, train in self.model.values():
            ut.set(len(pool))
            tt.set(pool.tokenCount)
            train.set(pool.trainCount)

    def save(self):
        path = tkFileDialog.asksaveasfilename()
        if not path:
            return
        self.guesser.save(path)
        self.app.dirty = False

    def load(self):
        path = tkFileDialog.askopenfilename()
        if not path:
            return
        self.guesser.load(path)
        self.reload()
        self.app.dirty = False
    
    def newPool(self):
        p = tkSimpleDialog.askstring('Create Pool', 'Name for new pool?')
        if not p:
            return
        if p in self.guesser.pools:
            tkMessageBox.showwarning('Bad pool name!', 'Pool %s already exists.' % p)
        self.guesser.newPool(p)
        self.reload()
        self.app.poolAdded()
        self.app.status.log('New pool created: %s.' % p, clear=3)

    def defaultColours(self):
        return ['green', 'yellow', 'lightblue', 'red', 'blue', 'orange', 'purple', 'pink']

    def columnHeadings(self):
        # FIXME factor out and generalize
        title = Label(self, text='Pools', relief=RAISED, borderwidth=1)
        title.pack(side=TOP, fill=X)
        msgLine = Frame(self, relief=RAISED, borderwidth=1)
        msgLine.pack(side=TOP)
        currCol = 0
        colHeadings = [('Name', 10), ('', 1), ('Trained', 10), ('Unique Tokens', 12), ('Tokens', 10)]
        for cHdr, width in colHeadings:
            l = Label(msgLine, text=cHdr, width=width, bg='lightblue')
            l.grid(row=0, column=currCol)
            currCol += 1

            
class Trainer(Frame):
    def __init__(self, parent, guesser=None, itemClass=None):
        self.status = StatusBar(parent)
        self.status.pack(side=BOTTOM, fill=X)
        Frame.__init__(self, parent)
        self.pack(side=TOP, fill=BOTH)
        self.itemsPerPage = 20
        self.rows = []
        for i in range(self.itemsPerPage):
            self.rows.append(ItemRow())
        self.items = []
        self.files = []
        self.cursor = 0
        self.dirty = False
        if guesser is None:
            from reverend.thomas import Bayes
            self.guesser = Bayes()
        else:
            self.guesser = guesser
        if itemClass is None:
            self.itemClass = TextItem
        else:
            self.itemClass = itemClass
        for row in self.rows:
            row.summary.set('foo')
        self.initViews()

    def initViews(self):
        self.nb = Notebook(self)
##        frame1 = Frame(self.nb())
##        self.poolView = PoolView(frame1, guesser=self.guesser, app=self)
##        self.poolView.pack(side=TOP)
        frame2 = Frame(self.nb())
        self.poolView = PoolView(frame2, guesser=self.guesser, app=self)
        self.poolView.pack(side=TOP)
        self.listView = Canvas(frame2, relief=GROOVE)
        self.listView.pack(padx=3)
        bn = Button(self.listView, text="Load training", command=self.loadCorpus)
        bn.pack(side=RIGHT, anchor=NE, fill=X)
        self.columnHeadings()
        self.addNextPrev()
        
        frame3 = Frame(self.nb())
        self.testView = TestView(frame3, guesser=self.guesser, app=self)
        self.testView.pack()

        frame4 = Frame(self.nb())
        bp = Button(frame4, text="Quit", command=self.quitNow)
        bp.pack(side=BOTTOM)
        
        #self.nb.add_screen(frame1, 'Reverend')
        self.nb.add_screen(frame2, 'Training')
        self.nb.add_screen(frame3, 'Testing')
        self.nb.add_screen(frame4, 'Quit')
        

    def addNextPrev(self):
        npFrame = Frame(self.listView)
        npFrame.pack(side=BOTTOM, fill=X)
        bn = Button(npFrame, text="Prev Page", command=self.prevPage)
        bn.grid(row=0, column=0)
        bn = Button(npFrame, text="Next Page", command=self.nextPage)
        bn.grid(row=0, column=1)


    def loadCorpus(self):
        path = tkFileDialog.askdirectory()
        if not path:
            return
        self.loadFileList(path)
        self.displayItems()
        self.displayRows()

    def bulkTest(self):
        dirs = []
        for pool in self.guesser.poolNames():
            path = tkFileDialog.askdirectory()
            dirs.append((pool, path))
        for pool, path in dirs:
            print pool, path
            

    def displayList(self):
        for item in self.items:
            self.itemRow(item)
            
    def displayRows(self):
        for row in self.rows:
            self.displayRow(row)

    def loadFileList(self, path):
        listing = os.listdir(path)
        self.files = [os.path.join(path, file) for file in listing]
        self.cursor = 0

    def prevPage(self):
        self.cursor = max(0, self.cursor - self.itemsPerPage)
        self.displayItems()

    def nextPage(self):
        self.cursor = min(len(self.files), self.cursor + self.itemsPerPage)
        self.displayItems()
        
    def displayItems(self):
        theseFiles = self.files[self.cursor:self.cursor + self.itemsPerPage]
        items = []
        for file, row in zip(theseFiles, self.rows):
            fp = open(file, 'rb')
            try:
                item = self.itemClass.fromFile(fp)
            finally:
                fp.close()
            if item is None:
                continue
            items.append(item)
            guesses = self.guesser.guess(item)
            summary = item.summary()
            cols = item.columnDefs()
            s = ''
            for c, ignore in cols:
                s += summary[c] + ' '
            row.initialize(item, s, guesses, self.guesser.poolNames())
        self.items = items
        
    def quitNow(self):
        if self.dirty:
            if tkMessageBox.askyesno("You have unsaved changes!", "Quit without saving?"):
                self.quit()
        self.quit()

    def columnHeadings(self):
        # FIXME - Something better for columns and rows in general
        line = Frame(self.listView, relief=RAISED, borderwidth=1)
        line.pack(side=TOP, padx=2, pady=1)
        colHeadings = self.itemClass.columnDefs()
        currCol = 0
        for cHdr, width in colHeadings:
            l = Label(line, text=cHdr, width=width, bg='lightblue')
            l.grid(row=0, column=currCol)
            currCol += 1
        line = Frame(self)
        line.pack(fill=X)

    def training(self, row):
        sel = row.selection.get()
        self.guesser.train(sel, row.original)
        row.current = sel
        self.guessAll()

    def guessAll(self):
        self.poolView.refresh()
        pools = self.guesser.poolNames()
        for row in self.rows:
            row.setGuess(self.guesser.guess(row.original), pools)
            
    def displayRow(self, row, bgc=None):
        # UGH - REWRITE!
        line = Frame(self.listView, bg=bgc)
        line.pack(pady=1)
        row.line = line
        self.insertRadios(row)
        Label(line, text=row.summary.get(), textvariable=row.summary, width=60, bg=bgc,
              anchor=W).grid(row=0, column=2)
        #Label(line, text=row.guess, width=7, bg=bgc, anchor=W).grid(row=0, column=1)
        colourStripe = Label(line, text=' ', width=1, bg=bgc, anchor=W, relief=GROOVE)
        colourStripe.grid(row=0, column=1)
        line.colourStripe = colourStripe
        pools = self.guesser.poolNames()
        row.refreshColour(pools)

    def poolAdded(self):
        if not self.items:
            return
        pools = self.guesser.poolNames()
        for row in self.rows:
            for r in row.radios:
                r.destroy()
            self.insertRadios(row)
            row.refreshColour(pools)
        self.dirty = True

    def insertRadios(self, row):
        radioFrame = Frame(row.line)
        radioFrame.grid(row=0, column=0)
        currCol = 0
        radios = []
        v = row.selection
        ci = 0
        colours = row.defaultColours()
        pools = self.guesser.poolNames()
        for pool in pools:
            rb = Radiobutton(radioFrame, text=pool, variable=v, value=pool, command=Command(self.training, row), bg=None)
            rb.grid(row=0, column=currCol)
            radios.append(rb)
            currCol += 1
            ci += 1
        row.radios = radios
        

class TextItem(object):
    def __init__(self, text):
        self.text = text
        
    def summary(self):
        return {'Text': self.text}

    def columnNames(self):
        return ['Text']

    def lower(self):
        return self.text.lower()

    def fromFile(self, fp):
        """Return the first line of the file.
        """
        ti = self(fp.readline())
        return ti
    fromFile = classmethod(fromFile)


class ItemRow(object):
    def __init__(self, orig=None):
        self.line = None
        self.radios = []
        self.original = orig
        self.current = ''
        self.guess = []
        self.summary = StringVar()
        self.selection = StringVar()

    def initialize(self, item=None, summary='', guess=None, pools=[]):
        self.selection.set('')
        self.original = item
        self.summary.set(summary)
        self.setGuess(guess, pools)

    def setGuess(self, guess, pools):
        if not guess:
            guess = [['']]
        self.guess = guess
        self.selection.set(self.bestGuess())
        self.current = self.bestGuess()
        self.refreshColour(pools)

    def refreshColour(self, pools):
        col = None
        if self.guess[0][0] in pools:
            idx = pools.index(self.guess[0][0])
            col = self.defaultColours()[idx]
        if self.line:
            self.line.colourStripe.config(bg=col)

    def __repr__(self):
        return self.original.__repr__()

    def defaultColours(self):
        return ['green', 'yellow', 'lightblue', 'red', 'blue', 'orange', 'purple', 'pink']

    def bestGuess(self):
        if self.guess:
            return self.guess[0][0]
        else:
            return None



        
if __name__ == "__main__":
    root = Tk()
    root.title('Reverend Trainer')
    root.minsize(width=300, height=300)
    #root.maxsize(width=600, height=600)
    display = Trainer(root)
    root.mainloop()
