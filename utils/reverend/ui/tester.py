# This module is part of the Divmod project and is Copyright 2003 Amir Bakhtiar:
# amir@divmod.org.  This is free software; you can redistribute it and/or
# modify it under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation.
#

from __future__ import generators
from Tkinter import *
import tkFileDialog
import tkSimpleDialog
import tkMessageBox
import os
import time

class TestView(Frame):
    def __init__(self, parent=None, guesser=None, app=None):
        Frame.__init__(self, parent)
        self.pack()
        self.guesser = guesser
        self.app = app
        self.size = 300
        self.setupViews()
        

    def setupViews(self):
        line = Frame(self, relief=RAISED, borderwidth=1)
        line.pack(side=TOP, padx=2, pady=1)
        colHeadings = [('Guesses', 8), ('Right', 8), ('Wrong', 8), ('Accuracy %', 10)]
        currCol = 0
        for cHdr, width in colHeadings:
            l = Label(line, text=cHdr, width=width, bg='lightblue')
            l.grid(row=0, column=currCol)
            currCol += 1
        line = Frame(self)
        line.pack(fill=X)

        iGuess = IntVar()
        iRight = IntVar()
        iWrong = IntVar()
        iAcc = IntVar()
        self.model = (iGuess, iRight, iWrong, iAcc)

        l = Label(line, textvariable=iGuess, anchor=E, width=8, relief=SUNKEN)
        l.grid(row=0, column=0)
        l = Label(line, textvariable=iRight, anchor=E, width=8, relief=SUNKEN)
        l.grid(row=0, column=1) 
        l = Label(line, textvariable=iWrong, anchor=E, width=8, relief=SUNKEN)
        l.grid(row=0, column=2)   
        l = Label(line, textvariable=iAcc, anchor=E, width=8, relief=SUNKEN)
        l.grid(row=0, column=3)   
        bp = Button(self, text="Run Test", command=self.runTest)
        bp.pack(side=BOTTOM)

        canvas = Canvas(self, width=self.size, height=self.size, bg='lightyellow')
        canvas.pack(expand=YES, fill=BOTH, side=BOTTOM)
        self.canvas = canvas
        
##        slid = Scale(self, label='Wrong', variable=iWrong, to=400, orient=HORIZONTAL, bg='red')
##        slid.pack(side=BOTTOM)
##        slid = Scale(self, label='Right', variable=iRight, to=400, orient=HORIZONTAL, bg='green')
##        slid.pack(side=BOTTOM)

    
    def runTest(self):
        # TODO - This is nasty re-write
        if len(self.guesser) == 0:
            tkMessageBox.showwarning('Underprepared for examination!',
                                     'Your guesser has had no training. Please train and retry.')
            return
        path = tkFileDialog.askdirectory()
        if not path:
            return
        answer = tkSimpleDialog.askstring('Which Pool do these items belong to?', 'Pool name?',
                                          parent=self.app)

        if not answer:
            return
        if answer not in self.guesser.pools:
            return
        
        de = DirectoryExam(path, answer, self.app.itemClass)
        testCount = len(de)
        scale = self.calcScale(testCount)
        x = 0
        y = 0
        cumTime = 0
        iGuess, iRight, iWrong, iAcc = self.model
        for m, ans in de:
            then = time.time()
            g = self.guesser.guess(m)
            cumTime += time.time() - then
            if g:
                g = g[0][0]
                iGuess.set(iGuess.get()+1)
                if g == ans:
                    col = 'green'
                    iRight.set(iRight.get()+1)
                else:
                    col = 'red'
                    iWrong.set(iWrong.get()+1)
                iAcc.set(round(100 * iRight.get()/float(iGuess.get()), 3))

            # Plot squares
            self.canvas.create_rectangle(x*scale,y*scale,(x+1)*scale,(y+1)*scale,fill=col)
            if not divmod(iGuess.get(),(int(self.size/scale)))[1]:
                # wrap
                x = 0
                y += 1
            else:
                x += 1
                
            self.update_idletasks()
        guesses = iGuess.get()
        self.app.status.log('%r guesses in %.2f seconds. Avg: %.2f/sec.' % (guesses, cumTime,
                                                                        round(guesses/cumTime, 2)))

    def calcScale(self, testCount):
        import math
        scale = int(self.size/(math.sqrt(testCount)+1))
        return scale
        
                
    
class DirectoryExam(object):
    """Creates a iterator that returns a pair at a time.
    (Item, correctAnswer). This Exam creates items from
    a directory and uses the same answer for each.
    """
    
    def __init__(self, path, answer, itemClass):
        self.path = path
        self.answer = answer
        self.itemClass = itemClass

    def __iter__(self):
        files = os.listdir(self.path)
        for file in files:
            fp = open(os.path.join(self.path, file), 'rb')
            try:
                item = self.itemClass.fromFile(fp)
            finally:
                fp.close()
            if item is None:
                continue
            yield (item, self.answer)

    def __len__(self):
        files = os.listdir(self.path)
        return len(files)
        
        
        
