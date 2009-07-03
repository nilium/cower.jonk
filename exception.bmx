SuperStrict

Import Brl.Retro

Const JInvalidTokenError%=1
Const JStreamReadError%=2
Const JNullTokenError%=3
Const JInvalidOffsetError%=4
Const JMalformedArrayError%=5
Const JMalformedStringError%=6
Const JMalformedNumberError%=7
Const JInvalidCharacterError%=8
Const JInvalidLiteralError%=9

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

Type JParserException Extends JException
	Field lineNumber:Int
	Field column:Int
	Field line:String
	
	Method ToString$()
		Local s$ = "["+error+":"+lineNumber+","+column+"] "+method_+": "+message+"~n"+line+"~n"+RSet("^",column)
		If inner Then
			Return s+"~n"+inner.ToString()
		EndIf
		Return s
	End Method
End Type

Function ParserException:JParserException(_method:String, msg$, errorcode%, line:String, lineNumber:Int, column:Int, inner:Object = Null)
	Local ex:JParserException = New JParserException
	ex.error = errorcode
	ex.lineNumber = lineNumber
	ex.column = column
	ex.line = line
	ex.message = msg
	ex.method_ = _method
	ex.inner = inner
	Return ex
End Function
