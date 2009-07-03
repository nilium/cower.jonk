SuperStrict

Import "exception.bmx"

Type JParserHandler Abstract
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
