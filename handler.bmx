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

Type JEventHandler Abstract
	' Parser state
	Method BeginParsing() Abstract
	Method EndParsing() Abstract
	
	' Object handler
	Method ObjectBegin() Abstract
	Method ObjectKey(name$) Abstract
	Method ObjectEnd() Abstract
	
	' Array handler
	Method ArrayBegin() Abstract
	Method ArrayEnd() Abstract
	
	' Values
	Method NumberValue(number$, isdecimal%) Abstract
	Method StringValue(value$) Abstract
	Method BooleanValue(value%) Abstract
	Method NullValue() Abstract
	
	' Errors
	' Return True if the error was handled, false if not
	Method Error%(err:JParserException) Abstract
End Type
