SuperStrict

Import brl.LinkedList
Import brl.Map
Import brl.Stream
Import brl.TextStream
Import cower.Charset
Import cower.Numerical

Import "jsonstring.bmx"
Import "handler.bmx"
Import "exception.bmx"

Private

Const JTokenObjectBegin:Int = 0
Const JTokenObjectEnd:Int = 1
Const JTokenArrayBegin:Int = 2
Const JTokenArrayEnd:Int = 3
Const JTokenString:Int = 4
Const JTokenNumber:Int = 5
Const JTokenTrue:Int = 6
Const JTokenFalse:Int = 7
Const JTokenNull:Int = 8
Const JTokenArraySep:Int = 9
Const JTokenValueSep:Int = 10
Const JTokenEof:Int = 11

Function Token:JToken(token%, start%, _end%)
	Local t:JToken = New JToken
	t.token = token
	t.start = start
	t.end_ = _end
	Return t
End Function

Type JToken
	Field token%
	Field start%
	Field end_%
End Type

Global JWhitespaceSet:TCharacterSet = TCharacterSet.ForWhitespace()
Global JFollowingLiteral:TCharacterSet = New TCharacterSet.InitWithString(" ~r~n~t},]")
Global JNumberStartingSet:TCharacterSet = New TCharacterSet.InitWithString(".1-9\-")
Global JDigitSet:TCharacterSet = New TCharacterSet.InitWithString("0-9.\-+eE")
Global JDoubleSet:TCharacterSet = New TCharacterSet.InitWithString("eE.\-+")

Public

Type JParser
	Const CObjBegin% = $7B
	Const CObjEnd% = $7D
	Const CArrBegin% = $5B
	Const CArrEnd% = $5D
	Const CQuote% = $22
	Const CColon% = $3A
	Const CComma% = $2C
	Const CEscape% = $5C
	Const CComment% = $2F
	Const Cf% = $66
	Const Ct% = $74
	Const Cn% = $6E
	
	Field _stream:TStream
	Field _strbuf$
	Field _offset:Int
	Field _lineOff:Int
	Field _line%
	Field _col%
	
	Field _curChar:Int
	
	Field _handler:JParserHandler
	
	' Creates a stream from the object
	' precondition: for streams that are not TTextStreams, the stream MUST implement ReadString and Size, and all characters must be .
	Method InitWithStream:JParser(url:Object, handler:JParserHandler = Null)
		_strbuf = ""
		_offset = 0
		
		_line = 1
		_col = 1
		
		_stream = ReadStream(url)
		
		SetHandler(handler)
		Return Self
	End Method
	
	Method InitWithString:JParser(str$, handler:JParserHandler = Null)
		_strbuf = str
		_offset = 0
		_line = 1
		_col = 1
		SetHandler(handler)
		Return Self
	End Method
	
	' returns the current handler
	Method GetHandler:JParserHandler() NoDebug
		Return _handler
	End Method
	
	' Returns the old handler
	Method SetHandler:JParserHandler( newhandler:JParserHandler ) NoDebug
		Local orig:JParserHandler = _handler
		_handler = newhandler
		Return orig
	End Method
	
	Method Parse()
		 ' setup buffer with at least one line, and see if there's anything in it
		If PeekChar(1) = -1 Then
			If _handler Then
				_handler.BeginParsing()
				_handler.EndParsing()
			EndIf
			Return
		EndIf
		_curChar = _strbuf[_offset] ' load first character
		Local tok:JToken = NextToken()
		If _handler Then
			_handler.BeginParsing()
			Try
				If tok.token <> JTokenEof Then
					ReadValue(tok)
				EndIf
				_handler.EndParsing()
			Catch error:JParserException
				If Not _handler.Error(error) Then
					Throw error
				EndIf
			End Try
		Else
			If tok.token <> JTokenEof Then
				ReadValue(tok)
			EndIf
		EndIf
	End Method
	
	' PRIVATE
	
	Method SkipWhitespace()
		While _curChar <> -1 And JWhitespaceSet.Contains(_curChar)
			GetChar()
		Wend
	End Method
	
	Method GetChar%() NoDebug
		While (_strbuf.Length-1) <= _offset
			If _stream And Not _stream.Eof() Then
				_strbuf = _strbuf+_stream.ReadLine()
				Continue
			EndIf
			Return -1
		Wend
		If _strbuf[_offset] = 10 Then
			_lineOff = _offset + 1
			_line :+ 1
			_col = 0
		EndIf
		_col :+ 1
		_offset :+ 1
		_curChar = _strbuf[_offset]
		Return _curChar
	End Method
	
	' Peaks @n chars ahead - if n is greater than the buffer size, it will add as many lines to the
	' buffer as is necessary until either EOF is reached or the buffer is large enough
	' A negative @n will cause an exception to be thrown
	Method PeekChar%(n%) NoDebug
		If n < 0 Then
			Throw JException.Create("JParser#PeekChar", "Negative peek offset is invalid", JInvalidOffsetError)
		EndIf
		
		Local off:Int = _offset+n
		While _strbuf.Length <= off
			If _stream And Not _stream.Eof() Then
				_strbuf :+ _stream.ReadLine()
				Continue
			EndIf
			Return -1
		Wend
		
		Return _strbuf[_offset+n]
	End Method
	
	Method Position%()
		Return _offset
	End Method
	
	Method Skip(n%) NoDebug
		If n < 0 Then
			Throw JException.Create("JParser#Skip", "Negative skip amount is invalid", JInvalidOffsetError)
		EndIf
		
		While n And GetChar() <> -1
			n :- 1
		Wend
	End Method
	
	Method CurrentLine$()
		Local nextEndline%
		For nextEndline = _lineOff Until _strbuf.Length
			If _strbuf[nextEndline] = 10 Then
				Exit
			EndIf
		Next
		Return _strbuf[_lineOff..nextEndLine]
	End Method
	
	Method ReadStringValue(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadStringValue", "Token is null", JNullTokenError)
		EndIf
		
		If tok.token <> JTokenString Then
			Throw ParserException("JParser#ReadStringValue", "Expected string literal, found "+StringForToken(tok), JInvalidTokenError, CurrentLine(), _line, _col)
		EndIf
		
		If _handler Then
			Local str$ = _strbuf[tok.start+1..tok.end_]
			Try
				str = DecodeJSONString(str)
			Catch ex:Object
				Throw ParserException("JParser#ReadStringValue", "Error decoding string literal", JMalformedStringError, CurrentLine(), _line, _col, ex)
			End Try
			_handler.StringValue(str)
		EndIf
	End Method
	
	Method ReadObjectKey(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadObjectKey", "Token is null", JNullTokenError)
		EndIf
		
		If tok.token <> JTokenString Then
			Throw ParserException("JParser#ReadObjectKey", "Expected string literal, found "+StringForToken(tok), JInvalidTokenError, CurrentLine(), _line, _col)
		EndIf

		If _handler Then
			Local str$ = _strbuf[tok.start+1..tok.end_]
			Try
				str = DecodeJSONString(str)
			Catch ex:Object
				Throw ParserException("JParser#ReadObjectKey", "Error decoding string literal", JMalformedStringError, CurrentLine(), _line, _col, ex)
			End Try
			_handler.ObjectKey(str)
		EndIf
	End Method
	
	Method ReadArrayValue(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadArrayValue", "Token is null", JNullTokenError)
		EndIf
		
		If tok.token <> JTokenArrayBegin Then
			Throw ParserException("JParser#ReadArrayValue", "Expected [, found "+StringForToken(tok), JInvalidTokenError, CurrentLine(), _line, _col)
		EndIf
		
		If _handler Then _handler.ArrayBegin()
		
		tok = NextToken()
		If tok.token = JTokenArrayEnd Then
			If _handler Then _handler.ArrayEnd()
			Return
		EndIf
		
		ReadValue(tok)
		
		While True
			tok = NextToken()
			Select tok.token
				Case JTokenArraySep
					ReadValue(NextToken())
				Case JTokenArrayEnd
					If _handler Then _handler.ArrayEnd()
					Exit
				Default
					Throw ParserException("JParser#ReadArrayValue", "Malformed array: "+StringForToken(tok), JMalformedArrayError, CurrentLine(), _line, _col)
			End Select
		Wend
	End Method
	
	Method ReadObjectValue(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadObjectValue", "Token is null", JNullTokenError)
		EndIf
		
		If tok.token <> JTokenObjectBegin Then
			Throw ParserException("JReaded#ReadObjectValue", "Expected {, found "+StringForToken(tok), JInvalidTokenError, CurrentLine(), _line, _col)
		EndIf
		
		If _handler Then _handler.ObjectBegin()
		
		Local valueread%=False
		
		While True
			tok = NextToken()
			
			If tok.token = JTokenEof Then
				Throw ParserException("JParser#ReadObjectValue", "Expected } or field but reached EOF", JInvalidTokenError, CurrentLine(), _line, _col)
			EndIf
			
			
			
			Select tok.token
				Case JTokenString
					If valueread Then
						Throw ParserException("JParser#ReadObjectValue", "Expected , but found string literal", JInvalidTokenError, CurrentLine(), _line, _col)
					EndIf
					
					
					ReadObjectKey(tok)
					NextToken(JTokenValueSep, ":")
					ReadValue(NextToken())
					valueread = True
						
				Case JTokenArraySep
					If Not valueread Then
						Throw ParserException("JParser#ReadObjectValue", "Expected } or name, found field separator", JInvalidTokenError, CurrentLine(), _line, _col)
					EndIf
					
					valueread = False
					
				Case JTokenObjectEnd
					If _handler Then _handler.ObjectEnd()
					Exit
					
				Default
					Throw ParserException("JParser#ReadObjectValue", "Invalid token "+StringForToken(tok), JInvalidTokenError, CurrentLine(), _line, _col)
			End Select
		Wend
	End Method
	
	Method ReadValue:Object(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadValue", "Token is null", JNullTokenError)
		EndIf
		
		
		Select tok.token
			Case JTokenObjectBegin
				ReadObjectValue(tok)
			Case JTokenArrayBegin
				ReadArrayValue(tok)
			Case JTokenString
				ReadStringValue(tok)
			Case JTokenNumber
				If _handler Then
					Local ext$ = _strbuf[tok.start..tok.end_+1]
					If JDoubleSet.FindInString(ext) <> -1 Then
						_handler.NumberValue(ext, True)
					Else
						_handler.NumberValue(ext, False)
					EndIf
				EndIf
			Case JTokenNull
				If _handler Then _handler.NullValue()
			Case JTokenTrue
				If _handler Then _handler.BooleanValue(True)
			Case JTokenFalse
				If _handler Then _handler.BooleanValue(False)
			Case JTokenEof
				Throw ParserException("JParser#ReadValue", "No value found; reached EOF", JInvalidTokenError, CurrentLine(), _line, _col)
			Default
				Throw ParserException("JParser#ReadValue", "Invalid token received "+StringForToken(tok), JInvalidTokenError, CurrentLine(), _line, _col)
		End Select
	End Method
	
	Method ReadStringToken()
		Local char% = GetChar()
		While char <> -1
			If char = CEscape Then
				GetChar()
			ElseIf char = CQuote Then
				Return
			EndIf
			
			char = GetChar()
		Wend
		Throw ParserException("JParser#ReadStringToken", "Encountered malformed string", JMalformedStringError, CurrentLine(), _line, _col)
	End Method
	
	Method ReadNumberToken()
		Local eFound%=False, decFound%=(_curChar=46)
		Local char% = PeekChar(1)
		While char <> -1
			If char = 46 Then
				If decFound Then
					Throw ParserException("JParser#ReadNumbertoken", "Malformed fractional component in number, fraction already defined", JMalformedNumberError, CurrentLine(), _line, _col)
				ElseIf eFound Then
					Throw ParserException("JParser#ReadNumbertoken", "Malformed fractional component in number, exponent already defined", JMalformedNumberError, CurrentLine(), _line, _col)
				EndIf
				decFound = True
			ElseIf char = 69 Or char = 101 Then	' "E" and "e"
				If eFound Then
					Throw ParserException("JParser#ReadNumbertoken", "Malformed exponent in number, exponent already defined", JMalformedNumberError, CurrentLine(), _line, _col)
				EndIf
				
				eFound = True
				GetChar()
				
				char = PeekChar(1)
				If char = 43 Or char = 45 Then ' "+" and "-"
					GetChar()
					char = PeekChar(1)
				EndIf
				
				If char < 48 Or 57 < char Then
					Throw ParserException("JParser#ReadNumberToken", "Malformed exponent in number", JMalformedNumberError, CurrentLine(), _line, _col)
				EndIf
				
				Continue
			ElseIf char < 48 Or 57 < char Then
				Exit
			EndIf
			
			GetChar() ' character was a valid number character, advance
			char = PeekChar(1)
		Wend
	End Method
	
	Method NextToken:JToken(require:Int=-1, expected$="")
		SkipWhitespace()
		
		Local char% = _curChar
		
		If char = -1 Then
			Return Token(JTokenEof, Position(), Position())
		EndIf
		
		Local tok:JToken = New JToken
		tok.start = Position()
		
		Select char
			Case CObjBegin
				tok.token = JTokenObjectBegin
			Case CObjEnd
				tok.token = JTokenObjectEnd
			Case CArrBegin
				tok.token = JTokenArrayBegin
			Case CArrEnd
				tok.token = JTokenArrayEnd
			Case CQuote
				tok.token = JTokenString
				ReadStringToken
			Case CComma
				tok.token = JTokenArraySep
			Case CColon
				tok.token = JTokenValueSep
			Case Ct
				If Matches("rue") Then
					tok.token = JTokenTrue
				Else
					Throw ParserException("JParser#NextToken", "Invalid literal", JInvalidLiteralError, CurrentLine(), _line, _col)
				EndIf
			Case Cf
				If Matches("alse") Then
					tok.token = JTokenFalse
				Else
					Throw ParserException("JParser#NextToken", "Invalid literal", JInvalidLiteralError, CurrentLine(), _line, _col)
				EndIf
			Case Cn
				If Matches("ull") Then
					tok.token = JTokenNull
				Else
					Throw ParserException("JParser#NextToken", "Invalid literal", JInvalidLiteralError, CurrentLine(), _line, _col)
				EndIf
			Default
				If JNumberStartingSet.Contains(char) Then
					tok.token = JTokenNumber
					ReadNumberToken
				Else
					Throw ParserException("JParser#NextToken", "Invalid character while parsing JSON string", JInvalidCharacterError, CurrentLine(), _line, _col)
				EndIf
		End Select
		
		tok.end_ = Position()
		GetChar()
		
		If require <> -1 And tok.token <> require Then
			If expected Then
				Throw ParserException("JParser#NextToken", "Expected token "+expected+", found "+StringForToken(tok), JInvalidTokenError, CurrentLine(), _line, _col)
			Else
				Throw ParserException("JParser#NextToken", "Invalid token "+StringForToken(tok), JInvalidTokenError, CurrentLine(), _line, _col)
			EndIf
		EndIf
		
		Return tok
	End Method
	
	Method Matches:Int(s$)
		For Local idx:Int = 0 Until s.Length
			If PeekChar(idx+1) <> s[idx] Then
				Return False
			EndIf
		Next
		Skip(s.Length)
		Return True
	End Method
	
	Method StringForToken$( tok:JToken )
		Select tok.token
			Case JTokenObjectBegin
				Return "{"
			Case JTokenObjectEnd
				Return "}"
			Case JTokenArrayBegin
				Return "["
			Case JTokenArrayEnd
				Return "]"
			Case JTokenString
				Return _strbuf[tok.start..tok.end_+1]
			Case JTokenNumber
				Return _strbuf[tok.start..tok.end_+1]
			Case JTokenTrue
				Return "true"
			Case JTokenFalse
				Return "false"
			Case JTokenNull
				Return "null"
			Case JTokenArraySep
				Return ","
			Case JTokenValueSep
				Return ":"
			Case JTokenEof
				Return "EOF"
			Default
				Throw ParserException("JParser#StringForToken", "Invalid token "+tok.token, JInvalidTokenError, CurrentLine(), _line, _col)
		End Select
	End Method
End Type

