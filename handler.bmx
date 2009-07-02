SuperStrict

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
End Type
