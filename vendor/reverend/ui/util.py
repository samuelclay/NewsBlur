# This module is part of the Divmod project and is Copyright 2003 Amir Bakhtiar:
# amir@divmod.org.  This is free software; you can redistribute it and/or
# modify it under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation.
#

from Tkinter import *

class StatusBar(Frame):
    """Courtesy of Fredrik Lundh.
    """

    def __init__(self, master):
        Frame.__init__(self, master)
        self.label = Label(self, bd=1, relief=SUNKEN, anchor=W)
        self.label.pack(fill=X)

    def set(self, format, *args):
        self.label.config(text=format % args)
        self.label.update_idletasks()

    def clear(self):
        self.label.config(text="")
        self.label.update_idletasks()

    def log(self, text, clear=0):
        # Clear after clear seconds
        self.set('%s', text)
        if clear:
            self.label.after(clear * 1000, self.clear)

    
class Command:
    """Courtesy of Danny Yoo
    http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/66521
    """
    def __init__(self, callback, *args, **kwargs):
        self.callback = callback
        self.args = args
        self.kwargs = kwargs

    def __call__(self):
        return apply(self.callback, self.args, self.kwargs)
    
class Notebook:
    """Courtesy of Iuri Wickert
    http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/188537
    """
    
    # initialization. receives the master widget
    # reference and the notebook orientation
    def __init__(self, master, side=LEFT):
        self.active_fr = None
        self.count = 0
        self.choice = IntVar(0)

        # allows the TOP and BOTTOM
        # radiobuttons' positioning.
        if side in (TOP, BOTTOM):
            self.side = LEFT
        else:
            self.side = TOP

        # creates notebook's frames structure
        self.rb_fr = Frame(master, borderwidth=2, relief=RIDGE)
        self.rb_fr.pack(side=side, fill=BOTH)
        self.screen_fr = Frame(master, borderwidth=2, relief=RIDGE)
        self.screen_fr.pack(fill=BOTH)
            

    # return a master frame reference for the external frames (screens)
    def __call__(self):
        return self.screen_fr

            
    # add a new frame (screen) to the (bottom/left of the) notebook
    def add_screen(self, fr, title):
        b = Radiobutton(self.rb_fr, text=title, indicatoron=0, \
            variable=self.choice, value=self.count, \
            command=lambda: self.display(fr))
        b.pack(fill=BOTH, side=self.side)
        
        # ensures the first frame will be
        # the first selected/enabled
        if not self.active_fr:
            fr.pack(fill=BOTH, expand=1)
            self.active_fr = fr

        self.count += 1
            
            
    # hides the former active frame and shows 
    # another one, keeping its reference
    def display(self, fr):
        self.active_fr.forget()
        fr.pack(fill=BOTH, expand=1)
        self.active_fr = fr

