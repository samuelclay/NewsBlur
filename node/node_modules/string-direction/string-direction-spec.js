/*
  Tests are written in Jasmine. 
  To run tests
    npm install
    npm test
*/

var numberText = '1234',
	ltrText = 'Hello, world!',
    rtlText = 'سلام دنیا',
	ltrWithNumberText = '99 Bottles Of Bear...',
	rtlWithNumberText = 'לקובע שלי 3 פינות',
    rtlMultilineText = 'שלום\nכיתה\nא\'',
    bidiText = 'Hello in Farsi is سلام',
    LTR_MARK = '\u200e',
    RTL_MARK = '\u200f';

describe('stringDirection', function(){
  if(typeof require === 'function') {
    var stringDirection = require('./index');
  }else{
    var stringDirection = window.stringDirection;
  }

  describe('#getDirection', function(){

    describe('when passing non-string variables', function(){

      it('should throw error with number', function(){
        expect(function(){
          stringDirection.getDirection(1)
        }).toThrow( new Error('TypeError getDirection expects strings') );
      });

      it('should throw error with boolean', function(){
        expect(function(){
          stringDirection.getDirection(false);
        }).toThrow( new Error('TypeError getDirection expects strings') );
      });

      it('should throw error with objects', function(){
        expect(function(){
          stringDirection.getDirection({});
        }).toThrow( new Error('TypeError getDirection expects strings') );
      });

      it('should throw error with function', function(){
        expect(function(){
          stringDirection.getDirection(function(){});
        }).toThrow( new Error('TypeError getDirection expects strings') );
      });

      it('should throw error with regex', function(){
        expect(function(){
          stringDirection.getDirection(/some/);
        }).toThrow( new Error('TypeError getDirection expects strings') );
      });

      it('should throw error with no argument', function(){
        expect(function(){
          stringDirection.getDirection();
        }).toThrow( new Error('TypeError missing argument') );
      });

    });

    describe('when passing string variables', function(){

      it('should return "" with empty string variable', function(){
        expect(stringDirection.getDirection('')).toBe('');
      });

      it('should return "ltr" with number variable', function(){
        expect(stringDirection.getDirection(numberText)).toBe('ltr');
      });

      it('should return "ltr" with ltr variable', function(){
        expect(stringDirection.getDirection(ltrText)).toBe('ltr');
      });

      it('should return "rtl" with rtl variable', function(){
        expect(stringDirection.getDirection(rtlText)).toBe('rtl');
      });

      it('should return "ltr" with ltr with number variable', function(){
        expect(stringDirection.getDirection(ltrWithNumberText)).toBe('ltr');
      });

      it('should return "rtl" with rtl with number variable', function(){
        expect(stringDirection.getDirection(rtlWithNumberText)).toBe('rtl');
      });

      it('should return "rtl" with rtl multiline variable', function(){
        expect(stringDirection.getDirection(rtlMultilineText)).toBe('rtl');
      });

      it('should return "bidi" with bidi variable', function(){
        expect(stringDirection.getDirection(bidiText)).toBe('bidi');
      });

      it('should return "ltr" with variables that has LTR mark', function(){
        expect(stringDirection.getDirection(LTR_MARK + ltrText)).toBe('ltr');
      });

      it('should return "ltr" with variables that has RTL mark', function(){
        expect(stringDirection.getDirection(RTL_MARK + ltrText)).toBe('rtl');
      });

    });

  });

  describe('#patch', function(){
    stringDirection.patch();

    describe('when calling on string variables', function(){

      it('should return "" with empty string variable', function(){
        expect(''.getDirection()).toBe('');
      });

      it('should return "ltr" with number variable', function(){
        expect(numberText.getDirection()).toBe('ltr');
      });

      it('should return "ltr" with ltr variables', function(){
        expect(ltrText.getDirection()).toBe('ltr');
      });

      it('should return "rtl" with rtl variables', function(){
        expect(rtlText.getDirection()).toBe('rtl');
      });

      it('should return "ltr" with ltr with number variable', function(){
        expect(ltrWithNumberText.getDirection()).toBe('ltr');
      });

      it('should return "rtl" with rtl with number variable', function(){
        expect(rtlWithNumberText.getDirection()).toBe('rtl');
      });

      it('should return "rtl" with rtl multiline variables', function(){
        expect(rtlMultilineText.getDirection()).toBe('rtl');
      });

      it('should return "bidi" with bidi variables', function(){
        expect(bidiText.getDirection()).toBe('bidi');
      });

      it('should return "ltr" with variables that has LTR mark', function(){
        expect((LTR_MARK + rtlText).getDirection()).toBe('ltr');
      });

      it('should return "ltr" with variables that has RTL mark', function(){
        expect((RTL_MARK + ltrText).getDirection()).toBe('rtl');
      });

    });

  });

});
