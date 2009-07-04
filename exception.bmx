SuperStrict

Import Brl.Retro

Const JBufferAllocationError%=1
Const JInvalidCharacterError%=2
Const JInvalidEncodingError%=3
Const JInvalidLiteralError%=4
Const JInvalidOffsetError%=5
Const JInvalidTokenError%=6
Const JMalformedArrayError%=7
Const JMalformedNumberError%=8
Const JMalformedStringError%=9
Const JNullStreamError%=10
Const JNullTokenError%=11
Const JStreamReadError%=12
Const JUnsupportedEncodingError%=13

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
