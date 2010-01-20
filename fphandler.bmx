Rem
Copyright (c) 2009 Noel R. Cower

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
EndRem

SuperStrict

Import "exception.bmx"
Import "handler.bmx"

Const JHandlerBase% = 0
Const JBeginParsing% = 0
Const JEndParsing% = 1
Const JObjectBeginHandler% = 2
Const JObjectKeyHandler% = 3
Const JObjectEndHandler% = 4
Const JArrayBeginHandler% = 5
Const JArrayEndHandler% = 6
Const JNumberValueHandler% = 7
Const JStringValueHandler% = 8
Const JBooleanValueHandler% = 9
Const JNullValueHandler% = 10
Const JErrorHandler% = 11
Const JHandlerCount% = JErrorHandler+1

' Passes messages onto callbacks vs. having its own means of handling events
Type JFPEventHandler Extends JEventHandler
	Field _context:Object
	Field _beginParse(ctx:Object)=Null
	Field _endParse(ctx:Object)=Null
	Field _objBegin(ctx:Object)=Null
	Field _objKey(key$, ctx:Object)=Null
	Field _objEnd(ctx:Object)=Null
	Field _arrBegin(ctx:Object)=Null
	Field _arrEnd(ctx:Object)=Null
	Field _numValue(n$, id%, ctx:Object)=Null
	Field _strValue(s$, ctx:Object)=Null
	Field _boolValue(b%, ctx:Object)=Null
	Field _nullValue(ctx:Object)=Null
	Field _error:Int(err:JParserException)=Null
	
	Method Init:JFPEventHandler()
		Return Self
	End Method
	
	Method InitWithContext:JFPEventHandler( ctx:Object )
		_context = ctx
		Return Self
	End Method
	
	Method InitWithHandlers:JFPEventHandler( handlers:Byte Ptr[], ctx:Object=Null )
		Assert handlers.Length <= JHandlerCount ..
			Else "JCallbackParser#InitWithHandlers: Invalid number of handlers (must be JHandlerCount or less)"
		
		_context = ctx
		
		For Local handler:Int = 0 Until handlers.Length
			SetHandler(handler, handlers[handler])
		Next
		
		Return Self
	End Method
	
	' Returns the previous handler
	Method SetHandler:Byte Ptr( handler%, cb:Byte Ptr )
		Assert JHandlerBase <= handler And handler < JHandlerCount ..
			Else "JCallbackParser#SetHandler: Invalid handler ID: "+handler
		
		Local orig:Byte Ptr
		Select handler
			Case JBeginParsing
				orig = _beginParse
				_beginParse = cb
			Case JEndParsing
				orig = _endParse
				_endParse = cb
			Case JObjectBeginHandler
				orig = _objBegin
				_objBegin = cb
			Case JObjectKeyHandler
				orig = _objKey
				_objKey = cb
			Case JObjectEndHandler
				orig = _objEnd
				_objEnd = cb
			Case JArrayBeginHandler
				orig = _arrBegin
				_arrBegin = cb
			Case JArrayEndHandler
				orig = _arrEnd
				_arrEnd = cb
			Case JNumberValueHandler
				orig = _numValue
				_numValue = cb
			Case JStringValueHandler
				orig = _strValue
				_strValue = cb
			Case JBooleanValueHandler
				orig = _boolValue
				_boolValue = cb
	        Case JNullValueHandler
				orig = _nullValue
				_nullValue = cb
			Case JErrorHandler
				orig = _error
				_error = cb
		End Select
		Return orig
	End Method
	
	Method GetHandler:Byte Ptr(handler%)
		Assert JHandlerBase <= handler And handler < JHandlerCount ..
			Else "JCallbackParser#GetHandler: Invalid handler ID: "+handler
		
		Select handler
			Case JBeginParsing
				Return _beginParse
			Case JEndParsing
				Return _endParse
			Case JObjectBeginHandler
				Return _objBegin
			Case JObjectKeyHandler
				Return _objKey
			Case JObjectEndHandler
				Return _objEnd
			Case JArrayBeginHandler
				Return _arrBegin
			Case JArrayEndHandler
				Return _arrEnd
			Case JNumberValueHandler
				Return _numValue
			Case JStringValueHandler
				Return _strValue
			Case JBooleanValueHandler
				Return _boolValue
	        Case JNullValueHandler
				Return _nullValue
			Case JErrorHandler
				Return _error
		End Select
	End Method
	
	' Parser state
	Method BeginParsing()
		If _beginParse Then
			_beginParse(_context)
		EndIf
	End Method
	
	Method EndParsing()
		If _endParse Then
			_endParse(_context)
		EndIf
	End Method
	
	
	' Object handler
	Method ObjectBegin()
		If _objBegin Then
			_objBegin(_context)
		EndIf
	End Method
	
	Method ObjectKey(name$)
		If _objKey Then
			_objKey(name, _context)
		EndIf
	End Method
	
	Method ObjectEnd()
		If _objEnd Then
			_objEnd(_context)
		EndIf
	End Method
	
	' Array handler
	Method ArrayBegin()
		If _arrBegin Then
			_arrBegin(_context)
		EndIf
	End Method
	
	Method ArrayEnd()
		If _arrEnd Then
			_arrEnd(_context)
		EndIf
	End Method
	
	' Values
	Method NumberValue(number$, isdecimal%)
		If _numValue Then
			_numValue(number, isdecimal, _context)
		EndIf
	End Method
	
	Method StringValue(value$)
		If _strValue Then
			_strValue(value, _context)
		EndIf
	End Method
	
	Method BooleanValue(value%)
		If _boolValue Then
			_boolValue(value, _context)
		EndIf
	End Method
	
	Method NullValue()
		If _nullValue Then
			_nullValue(_context)
		EndIf
	End Method
	
	' Error handling
	Method Error%(err:JParserException)
		If _error Then
			Return _error(err)
		EndIf
		Return False
	End Method
End Type