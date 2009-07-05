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

Type JDebugParserHandler Extends JParserHandler
	Field _wrap:JParserHandler

	' Parser state
	Method BeginParsing()
		DebugLog "Parsing beginning"
		If _wrap Then _wrap.BeginParsing()
	End Method
	
	Method EndParsing()
		DebugLog "Parsing ended"
		If _wrap Then _wrap.EndParsing()
	End Method


	' Object handler
	Method ObjectBegin()
		DebugLog "Object beginning parsed"
		If _wrap Then _wrap.ObjectBegin()
	End Method

	Method ObjectKey(name$)
		DebugLog "Object key parsed [key=~q"+name+"~q]"
		If _wrap Then _wrap.ObjectKey(name)
	End Method

	Method ObjectEnd()
		DebugLog "Object ending parsed"
		If _wrap Then _wrap.ObjectEnd()
	End Method


	' Array handler
	Method ArrayBegin()
		DebugLog "Array beginning parsed"
		If _wrap Then _wrap.ArrayBegin()
	End Method

	Method ArrayEnd()
		DebugLog "Array ending parsed"
		If _wrap Then _wrap.ArrayEnd()
	End Method


	' Values
	Method NumberValue(number$, isdecimal%)
		DebugLog "Number value parsed [number=>~q"+number+"~q, isdecimal=>"+isdecimal+"]"
		If _wrap Then _wrap.NumberValue(number, isdecimal)
	End Method

	Method StringValue(value$)
		DebugLog "String value parsed [string=>~q"+value+"~q]"
		If _wrap Then _wrap.StringValue(value)
	End Method

	Method BooleanValue(value%)
		DebugLog "Boolean value parsed [bool=>"+value+"]"
		If _wrap Then _wrap.BooleanValue(value)
	End Method

	Method NullValue()
		DebugLog "Null value parsed"
		If _wrap Then _wrap.NullValue()
	End Method


	' Errors
	Method Error%(err:JParserException)
		DebugLog "Error occurred~n"+ToString()
		If _wrap And _wrap.Error(err) Then
			DebugLog "Error handled"
			Return True
		EndIf
		DebugLog "Error not handled"
		Return False
	End Method
End Type
