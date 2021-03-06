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

Import Brl.Retro

Const JBufferAllocationError%=1
Const JBufferSizeError%=2
Const JInvalidCharacterError%=3
Const JInvalidEncodingError%=4
Const JInvalidLiteralError%=5
Const JInvalidOffsetError%=6
Const JInvalidOperationError%=7
Const JInvalidTokenError%=8
Const JMalformedArrayError%=9
Const JMalformedNumberError%=10
Const JMalformedStringError%=11
Const JNullStreamError%=12
Const JNullTokenError%=13
Const JStreamReadError%=14
Const JUnsupportedEncodingError%=15

' Generic exception, used where no specific exception is properly defined
Type JException
	Field error:Int
	Field message:String
	Field method_:String
	Field inner:Object ' inner exception object
	
	Function Create:JException(_method$, msg$, err%, inner:Object=Null)
		Local ex:JException = New JException
		ex.error = err
		ex.message = msg
		ex.method_ = _method
		ex.inner = inner
		Return ex
	End Function
	
	Method ToString$()
		Local s$ = "["+error+"] "+method_+": "+message
		If inner Then
			Return s+"~n"+inner.ToString()
		EndIf
		Return s
	End Method
End Type

' Used when parsing
Type JParserException Extends JException
	Field lineNumber:Int
	Field column:Int
	
	Method ToString$()
		Local s$ = "["+error+":"+lineNumber+","+column+"] "+method_+": "+message
		If inner Then
			Return s+"~n"+inner.ToString()
		EndIf
		Return s
	End Method
End Type

Function ParserException:JParserException(_method:String, msg$, errorcode%, lineNumber:Int, column:Int, inner:Object = Null)
	Local ex:JParserException = New JParserException
	ex.error = errorcode
	ex.lineNumber = lineNumber
	ex.column = column
	ex.message = msg
	ex.method_ = _method
	ex.inner = inner
	Return ex
End Function

' Used in encoding/decoding of JSON strings - error code is always JMalformedStringError
Type JMalformedStringException Extends JException
	Field string_:String
	Field index:Int
	
	Method ToString$()
		Local s$ = "["+error+":"+index+"] "+message+"~n"+string_+"~n"+RSet("^",index)
		If inner Then
			Return s+"~n"+inner.ToString()
		EndIf
		Return s
	End Method
End Type

Function MalformedStringException:JMalformedStringException(methd$, message$, str$, idx%, inner:Object=Null)
	Local ex:JMalformedStringException = New JMalformedStringException
	ex.inner = inner
	ex.error = JMalformedStringError
	ex.message = message
	ex.method_ = methd
	ex.string_ = str
	ex.index = idx
	Return ex
End Function
