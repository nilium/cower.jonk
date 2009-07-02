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
