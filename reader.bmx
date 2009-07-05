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

Import brl.Stream
Import brl.LinkedList
Import brl.Map
Import cower.Charset
Import cower.Numerical

Import "handler.bmx"
Import "parser.bmx"
Import "jsonliterals.bmx"

Public

Type JObjectReader Extends JParserHandler
	Field _head:Object[]
	Field _headIdx:Int = -1
	
	' PRIVATE
	
	Method Push(o:Object)
		_headIdx :+ 1
		ExpandToFit(_headIdx+1)
		_head[_headIdx] = o
	End Method
	
	Method Peek:Object()
		Assert _headIdx>-1 Else "JReader#Peek: No objects on the stack"
		Return _head[_headIdx]
	End Method
	
	Method Pop()
		Assert _headIdx > -1 Else "JReader#Pop: Object stack underflow"
		_headIdx :- 1
	End Method
	
	Method ExpandToFit(n%)
		If n < _head.Length Then Return
		Local size% = Int(_head.Length*1.5)
		If n < size Then
			size = n
		EndIf
		_head = _head[..n]
	End Method
End Type
