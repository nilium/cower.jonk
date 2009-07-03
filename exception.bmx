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
	
	Function Create:JException(_method$, msg$, err%)
		Local ex:JException = New JException
		ex.error = err
		ex.message = msg
		ex.method_ = _method
		Return ex
	End Function
	
	Method ToString$()
		Return "["+error+"] "+method_+": "+message
	End Method
End Type

Type JParserException Extends JException
	Field lineNumber:Int
	Field column:Int
	Field line:String
	
	Method ToString$()
		Return "["+error+":"+lineNumber+","+column+"] "+method_+": "+message+"~n"+line+"~n"+RSet("^",column)
	End Method
End Type

Function ParserException:JParserException(_method:String, msg$, errorcode%, line:String, lineNumber:Int, column:Int)
	Local ex:JParserException = New JParserException
	ex.error = errorcode
	ex.lineNumber = lineNumber
	ex.column = column
	ex.line = line
	ex.message = msg
	ex.method_ = _method
	Return ex
End Function
