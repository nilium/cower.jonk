SuperStrict

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

Function Token:JToken(token%)
	Local t:JToken = New JToken
	t.token = token
	Return t
End Function

Const JTOKENBUFFER_INITIAL_SIZE% = 48
Const JTOKENBUFFER_MULTIPLIER! = 1.75!

Type JToken
	Field token%
	Field buffer:Short Ptr=Null, bufSize%=0, bufLen%=0
	Field _bufS$=Null
	
	Method Delete() NoDebug
		If buffer Then
			MemFree(buffer)
		EndIf
	End Method
	
	Method BufferChar(c%)
		If Not buffer Then
			' create buffer
			bufSize = JTOKENBUFFER_INITIAL_SIZE
			buffer = Short Ptr(MemAlloc(bufSize*2))
			bufLen = 0
		ElseIf bufLen = bufSize Then
			Local newsize% = Ceil(bufSize*JTOKENBUFFER_MULTIPLIER)
			If newSize < bufLen Then
				newSize = Ceil(bufLen*JTOKENBUFFER_MULTIPLIER) ' try to 
			EndIf
			
			Local temp:Short Ptr = Short Ptr(MemAlloc(newSize*2))
			If temp = Null Then
				Throw JException.Create("JToken#BufferChar", "Unable to allocate buffer of size "+(newSize*2)+" bytes", JBufferAllocationError)
			EndIf
			
			bufSize = newSize
			MemCopy(temp, buffer, bufLen*2)
			MemFree(buffer)
			buffer = temp
		EndIf
		buffer[bufLen]=c
		bufLen:+1
	End Method
	
	Method ToString$()
		If _bufS And (Not buffer Or _bufS.Length = bufLen) Then
			Return _bufS
		EndIf
		_bufS = String.FromShorts(buffer, bufLen%)
		MemFree(buffer)
		buffer = Null
		Return _bufS
	End Method
End Type

Global JWhitespaceSet:TCharacterSet = TCharacterSet.ForWhitespace()
Global JFollowingLiteral:TCharacterSet = New TCharacterSet.InitWithString(" ~r~n~t},]")
Global JNumberStartingSet:TCharacterSet = New TCharacterSet.InitWithString(".1-9\-")
Global JDigitSet:TCharacterSet = New TCharacterSet.InitWithString("0-9.\-+eE")
Global JDoubleSet:TCharacterSet = New TCharacterSet.InitWithString("eE.\-+")

Public

Const JSONEncodingLATIN1%=1
Const JSONEncodingUTF8%=2
Const JSONEncodingUTF16BE%=3
Const JSONEncodingUTF16LE%=4
Const JSONEncodingUTF32%=5				' Unsupported!  Will cause an exception to be thrown.

Type JParser
	' Single characters to match against
	Const CObjBegin% = $7B			' { object begin
	Const CObjEnd% = $7D			' } object end
	Const CArrBegin% = $5B			' [ array begin
	Const CArrEnd% = $5D			' ] array end
	Const CQuote% = $22				' string beginning/ending
	Const CColon% = $3A				' value separator
	Const CComma% = $2C				' array/member separator
	Const CEscape% = $5C			' Escape character (\)
'	Const CComment% = $2F			' Unused: match against // comments
	Const Cf% = $66					' 'f' for false literals
	Const Ct% = $74					' 't' for true literals
	Const Cn% = $6E					' 'n' for null literals
	
	' Initial length of the parser's buffer in Shorts
	Const JPARSERBUFFER_INITIAL_SIZE%=32
	' Amount by which to multiply the size of the parser's buffer when expanding it
	Const JPARSERBUFFER_MULTIPLIER!=1.75!
	
	' Optional stream
	Field _stream:TTextStream=Null
	' Buffer
	Field _strbuf:Short Ptr=Null
	Field _strbuf_size:Int=0			' The size of the buffer in Shorts
	Field _strbuf_length:Int=0			' The number of characters in the buffer that can be read
	Field _offset:Int=0					' Offset into the buffer
	' Debugging info
	Field _line%=0						' Line number
	Field _col%=0						' Column number
	
	Field _curChar:Int=-1				' Cached value of the current character
	
	Field _handler:JParserHandler=Null	' Event handler
	
	Method Delete()
		If _strbuf Then
			MemFree(_strbuf)
		EndIf
	End Method
	
	' Creates a stream from the object and uses it to buffer characters when needed
	' Encoding defaults to UTF-8 unless specified otherwise
	' internally, this processes JSON using UTF-16BE
	'
	' bufferLength specifies the length of the buffer in wide characters (UTF-16) - the buffer will
	' be, at minimum, bufferLength*2 bytes in size, and may grow over time in certain circumstances.
	' Buffer sizes of zero or less
	Method InitWithStream:JParser(url:Object, handler:JParserHandler = Null, encoding%=JSONEncodingUTF8, bufferLength%=JParser.JPARSERBUFFER_INITIAL_SIZE)
		If encoding = JSONEncodingUTF32 Then
			Throw JException.Create("JParser#InitWithStream", "UTF-32 encoding is not supported", JUnsupportedEncodingError)
		ElseIf encoding < JSONEncodingUTF8 Or JSONEncodingUTF32 < encoding Then
			Throw JException.Create("JParser#InitWithStream", "Invalid encoding option specified", JInvalidEncodingError)
		ElseIf bufferLength <= 0 Then
			Throw JException.Create("JParser#InitWithStream", "Invalid buffer size for initializing parser with stream", JBufferSizeError)
		EndIf
		
		_curChar = -1
		
		_offset = 0
		_strbuf_length = 0
		
		_line = 1
		_col = 1
		
		Local rstream:TStream = ReadStream(url)
		If Not rstream Then
			Throw JException.Create("JParser#InitWithStream", "Unable to open stream for reading", JStreamReadError)
		EndIf
		' first, see if a textstream was already passed
		_stream = TTextStream.Create(rstream, encoding)
		
		' Set up the buffer
		_strbuf_size = bufferLength
		_strbuf = Short Ptr(MemAlloc(_strbuf_size*2))
		If _strbuf = Null Then
			Throw JException.Create("JParser#InitWithStream", "Unable to allocate buffer of size "+(_strbuf_size*2)+" bytes", JBufferAllocationError)
		EndIf
		_offset = 0
		
		Rem
		' random code to test to see if URL was already a TTextStream.. decided against using it
		' for now - leaving it in 'cause I don't know if I'll re-use it later
		_stream = TTextStream(url)
		If Not _stream And url Then
			Local rstream:TStream = ReadStream(url)
			_stream = TTextStream(rstream)
			If Not _stream And rstream Then
				_stream = TTextStream.Create(rstream, encoding)
			EndIf
		EndIf
		If Not _stream Then
			Throw JException.Create("JParser#InitWithStream", "Unable to open stream for reading", JStreamReadError)
		EndIf
		EndRem
		
		SetHandler(handler)
		
		Return Self
	End Method
	
	Method InitWithString:JParser(str$, handler:JParserHandler = Null)
		
		_curChar = -1
		
		If _strbuf Then
			MemFree(_strbuf)
		EndIf
		
		_strbuf = str.ToWString()
		_strbuf_length = str.Length
		_strbuf_size = _strbuf_length+1
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
	
	' If passException is True, will pass on exceptions to the ParserHandler, otherwise something
	' else will have to catch them.
	'
	' Defaults to False because you should only use passExceptions when you think there might be a
	' user error or something and you'd want to give them an error dialog or something.
	Method Parse(passExceptions%=False)
		 ' setup buffer with at least one line, and see if there's anything in it
		GetChar()
		If _curChar = -1 Then
			If _handler Then
				_handler.BeginParsing()
				_handler.EndParsing()
			EndIf
			Return
		EndIf
		
		Local tok:JToken = NextToken()
		
		If _handler Then
			_handler.BeginParsing()
		EndIf
		
		If tok.token <> JTokenArrayBegin And tok.token <> JTokenObjectBegin And tok.token <> JTokenEof Then
			' as defined in rfc4627, a JSON text must begin with an object or array
			Local ex:JParserException = ParserException("JToken#Parse", "Text does not begin with an object or array", JInvalidTokenError, _line, _col)
			If Not _handler Or Not _handler.Error(ex) Then
				Throw ex
			EndIf
		EndIf
		
		If _handler And passExceptions Then
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
			ReadValue(tok)
			_handler.EndParsing()
		ElseIf tok.token <> JTokenEof Then
			ReadValue(tok)
		EndIf
	End Method
	
	' PRIVATE
	
	Method SkipWhitespace() NoDebug
		While _curChar <> -1 And JWhitespaceSet.Contains(_curChar)
			GetChar()
		Wend
	End Method
	
	Method GetChar%()
		Local initLen:Int = _strbuf_length
		
		If initLen > 0 And _strbuf[_offset] = 10 Then
			_line :+ 1
			_col = 0
		EndIf
		
		While _strbuf_length-1 <= _offset
			If _stream And Not _stream.Eof() Then
				_offset :- _strbuf_length
				
				_strbuf_length = 0
				Repeat
					_strbuf[_strbuf_length] = _stream.ReadChar()
					_strbuf_length :+ 1
				Until _strbuf_length = _strbuf_size Or _stream.Eof()
				
				Continue
			EndIf
			Return -1
		Wend
		
		If initLen > 0 Then
			_offset :+ 1
			_col :+ 1
		EndIf
		
		_curChar = _strbuf[_offset]
		Return _curChar
	End Method
	
	' Peaks @n chars ahead - if n is greater than the buffer size, it will add as many lines to the
	' buffer as is necessary until either EOF is reached or the buffer is large enough
	' A negative @n will cause an exception to be thrown
	Method PeekChar%(n%)
		If n < 0 Then
			Throw JException.Create("JParser#PeekChar", "Negative peek offset is invalid", JInvalidOffsetError)
		EndIf
		
		Local off:Int = _offset+n
		If _strbuf_length <= off Then
			TrimBuffer()
			off = _offset+n
			
			If _strbuf_length <= off And (_stream And Not _stream.Eof()) Then
				Local newSize:Int = Ceil(_strbuf_size*JPARSERBUFFER_MULTIPLIER)
				If newSize <= off Then
					newSize = Ceil(off*JPARSERBUFFER_MULTIPLIER)
				EndIf
				
				Local temp:Short Ptr = Short Ptr(MemAlloc(2*newSize))
				If temp = Null Then
					Throw JException.Create("JParser#PeekChar", "Unable to allocate buffer of size "+(newSize*2)+" bytes", JBufferAllocationError)
				EndIf
				
				_strbuf_size = newSize
				MemCopy(temp, _strbuf, _strbuf_length*2)
				MemFree(_strbuf)
				_strbuf = temp
				
				Repeat
					_strbuf[_strbuf_length] = _stream.ReadChar()
					_strbuf_length :+ 1
				Until _strbuf_length = _strbuf_size Or _stream.Eof()
			EndIf
			
			If _strbuf_length <= off
				Return -1
			EndIf
		EndIf
		
		Return _strbuf[off]
	End Method
	
	Method Skip(n%)
		If n < 0 Then
			Throw JException.Create("JParser#Skip", "Negative skip amount is invalid", JInvalidOffsetError)
		EndIf
		
		While n And GetChar() <> -1
			n :- 1
		Wend
	End Method
	
	Method TrimBuffer()
		Local tail_len:Int = _strbuf_length-_offset
		If tail_len < 0 Then
			Throw ParserException("JParser#TrimBuffer", "Length of tail for buffer is a negative value", JInvalidOffsetError, _line, _col)
		EndIf
		
		If _offset = 0 Or tail_len = 0 Or Not _stream Or _stream.Eof() Then
			Return
		EndIf
		
		Local copyfrom:Short Ptr = _strbuf + _offset
		For Local idx:Int = _offset Until tail_len
			_strbuf[idx] = copyfrom[idx]
		Next
		' Fill remainder of buffer
		_offset = 0
		_strbuf_length = tail_len
		
		Repeat
			_strbuf[_strbuf_length] = _stream.ReadChar()
			_strbuf_length :+ 1
		Until _strbuf_length = _strbuf_size Or _stream.Eof()
	End Method
	
	Method ReadStringValue(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadStringValue", "Token is null", JNullTokenError)
		EndIf
		
		If tok.token <> JTokenString Then
			Throw ParserException("JParser#ReadStringValue", "Expected string literal, found "+StringForToken(tok), JInvalidTokenError, _line, _col)
		EndIf
		
		If _handler Then
			Local str$ = tok.ToString()
			Try
				str = DecodeJSONString(str)
			Catch ex:Object
				Throw ParserException("JParser#ReadStringValue", "Error decoding string literal", JMalformedStringError, _line, _col, ex)
			End Try
			_handler.StringValue(str)
		EndIf
	End Method
	
	Method ReadObjectKey(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadObjectKey", "Token is null", JNullTokenError)
		EndIf
		
		If tok.token <> JTokenString Then
			Throw ParserException("JParser#ReadObjectKey", "Expected string literal, found "+StringForToken(tok), JInvalidTokenError, _line, _col)
		EndIf

		If _handler Then
			Local str$ = tok.ToString()
			Try
				str = DecodeJSONString(str)
			Catch ex:Object
				Throw ParserException("JParser#ReadObjectKey", "Error decoding string literal", JMalformedStringError, _line, _col, ex)
			End Try
			_handler.ObjectKey(str)
		EndIf
	End Method
	
	Method ReadArrayValue(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadArrayValue", "Token is null", JNullTokenError)
		EndIf
		
		If tok.token <> JTokenArrayBegin Then
			Throw ParserException("JParser#ReadArrayValue", "Expected [, found "+StringForToken(tok), JInvalidTokenError, _line, _col)
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
					Throw ParserException("JParser#ReadArrayValue", "Malformed array: "+StringForToken(tok), JMalformedArrayError, _line, _col)
			End Select
		Wend
	End Method
	
	Method ReadObjectValue(tok:JToken)
		If Not tok Then
			Throw JException.Create("JParser#ReadObjectValue", "Token is null", JNullTokenError)
		EndIf
		
		If tok.token <> JTokenObjectBegin Then
			Throw ParserException("JReaded#ReadObjectValue", "Expected {, found "+StringForToken(tok), JInvalidTokenError, _line, _col)
		EndIf
		
		If _handler Then _handler.ObjectBegin()
		
		Local valueread%=False
		
		While True
			tok = NextToken()
			
			If tok.token = JTokenEof Then
				Throw ParserException("JParser#ReadObjectValue", "Expected } or field but reached EOF", JInvalidTokenError, _line, _col)
			EndIf
			
			
			
			Select tok.token
				Case JTokenString
					If valueread Then
						Throw ParserException("JParser#ReadObjectValue", "Expected , but found string literal", JInvalidTokenError, _line, _col)
					EndIf
					
					
					ReadObjectKey(tok)
					NextToken(JTokenValueSep, ":")
					ReadValue(NextToken())
					valueread = True
						
				Case JTokenArraySep
					If Not valueread Then
						Throw ParserException("JParser#ReadObjectValue", "Expected } or name, found field separator", JInvalidTokenError, _line, _col)
					EndIf
					
					valueread = False
					
				Case JTokenObjectEnd
					If _handler Then _handler.ObjectEnd()
					Exit
					
				Default
					Throw ParserException("JParser#ReadObjectValue", "Invalid token "+StringForToken(tok), JInvalidTokenError, _line, _col)
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
					Local ext$ = tok.ToString()
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
				Throw ParserException("JParser#ReadValue", "No value found; reached EOF", JInvalidTokenError, _line, _col)
			Default
				Throw ParserException("JParser#ReadValue", "Invalid token received "+StringForToken(tok), JInvalidTokenError, _line, _col)
		End Select
	End Method
	
	Method ReadStringToken(into:JToken)
		Local char% = GetChar()
		While char <> -1
			If char = CEscape Then
				into.BufferChar(char)
				char = GetChar()
			ElseIf char = CQuote Then
				Return
			EndIf
			
			into.BufferChar(char)
			char = GetChar()
		Wend
		Throw ParserException("JParser#ReadStringToken", "Encountered malformed string", JMalformedStringError, _line, _col)
	End Method
	
	Method ReadNumberToken(into:JToken)
		into.BufferChar(_curChar)
		Local eFound%=False, decFound%=(_curChar=46)
		Local char% = PeekChar(1)
		While char <> -1
			If char = 46 Then
				If decFound Then
					Throw ParserException("JParser#ReadNumbertoken", "Malformed fractional component in number, fraction already defined", JMalformedNumberError, _line, _col)
				ElseIf eFound Then
					Throw ParserException("JParser#ReadNumbertoken", "Malformed fractional component in number, exponent already defined", JMalformedNumberError, _line, _col)
				EndIf
				decFound = True
			ElseIf char = 69 Or char = 101 Then	' "E" and "e"
				If eFound Then
					Throw ParserException("JParser#ReadNumbertoken", "Malformed exponent in number, exponent already defined", JMalformedNumberError, _line, _col)
				EndIf
				
				eFound = True
				into.BufferChar(char)
				GetChar()
				
				char = PeekChar(1)
				If char = 43 Or char = 45 Then ' "+" and "-"
					into.BufferChar(char)
					GetChar()
					char = PeekChar(1)
				EndIf
				
				If char < 48 Or 57 < char Then
					Throw ParserException("JParser#ReadNumberToken", "Malformed exponent in number", JMalformedNumberError, _line, _col)
				EndIf
				
				Continue
			ElseIf char < 48 Or 57 < char Then
				Exit
			EndIf
			
			into.BufferChar(char)
			GetChar() ' character was a valid number character, advance
			char = PeekChar(1)
		Wend
	End Method
	
	Method NextToken:JToken(require:Int=-1, expected$="")
		SkipWhitespace()
		
		Local char% = _curChar
		
		If char = -1 Then
			Return Token(JTokenEof)
		EndIf
		
		Local tok:JToken = New JToken
		
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
				ReadStringToken(tok)
			Case CComma
				tok.token = JTokenArraySep
			Case CColon
				tok.token = JTokenValueSep
			Case Ct
				If Matches("rue") Then
					tok.token = JTokenTrue
				Else
					Throw ParserException("JParser#NextToken", "Invalid literal", JInvalidLiteralError, _line, _col)
				EndIf
			Case Cf
				If Matches("alse") Then
					tok.token = JTokenFalse
				Else
					Throw ParserException("JParser#NextToken", "Invalid literal", JInvalidLiteralError, _line, _col)
				EndIf
			Case Cn
				If Matches("ull") Then
					tok.token = JTokenNull
				Else
					Throw ParserException("JParser#NextToken", "Invalid literal", JInvalidLiteralError, _line, _col)
				EndIf
			Default
				If JNumberStartingSet.Contains(char) Then
					tok.token = JTokenNumber
					ReadNumberToken(tok)
				Else
					Throw ParserException("JParser#NextToken", "Invalid character while parsing JSON string", JInvalidCharacterError, _line, _col)
				EndIf
		End Select
		
		GetChar()
		
		If require <> -1 And tok.token <> require Then
			If expected Then
				Throw ParserException("JParser#NextToken", "Expected token "+expected+", found "+StringForToken(tok), JInvalidTokenError, _line, _col)
			Else
				Throw ParserException("JParser#NextToken", "Invalid token "+StringForToken(tok), JInvalidTokenError, _line, _col)
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
				Return tok.ToString()
			Case JTokenNumber
				Return tok.ToString()
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
				Throw ParserException("JParser#StringForToken", "Invalid token "+tok.token, JInvalidTokenError, _line, _col)
		End Select
	End Method
End Type

