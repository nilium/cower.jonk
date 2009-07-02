SuperStrict

Import brl.LinkedList
Import brl.Map
Import brl.Stream
Import brl.TextStream
Import cower.Charset
Import cower.Numerical

Import "jsonstring.bmx"
Import "jsonliterals.bmx"
Import "handler.bmx"

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
Global JNumberStartingSet:TCharacterSet = New TCharacterSet.InitWithString(".0-9\-")
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
	
	Field root:Object
	
	Field _strbuf$
	Field _offset:Int
	
	Field _handler:JParserHandler
	
	Method InitWithStream:JParser(stream:TStream, handler:JParserHandler = Null)
		Return InitWithString(LoadText(stream), handler)
	End Method
	
	Method InitWithString:JParser(str$, handler:JParserHandler = Null)
		_strbuf = str
		_offset = 0
		SetHandler(handler)
		Return Self
	End Method
	
	' Returns the old handler
	Method SetHandler:JParserHandler( newhandler:JParserHandler )
		Local orig:JParserHandler = _handler
		_handler = newhandler
	End Method
	
	Method Parse:Object()
		ReadValue(NextToken())
	End Method
	
	' PRIVATE
	
	Method SkipWhitespace()
		While _offset < _strbuf.Length And JWhitespaceSet.Contains(_strbuf[_offset])
			_offset :+ 1
		Wend
	End Method
	
	Method GetChar%() NoDebug
		Assert _offset < (_strbuf.Length-1) Else "JParser#GetChar: Attempt to get chararacter after end of buffer"
		_offset :+ 1
	End Method
	
	Method CurrentChar%() NoDebug
		Return PeekChar(0)
	End Method
	
	' Peaks @n chars ahead
	Method PeekChar%(n%) NoDebug
		Assert n>=0 Else "JParser#PeekChar: Negative peek offset is invalid"
		Assert _offset+n < _strbuf.Length Else "JParser#PeekChar: Peek offset outside of buffer"
		Return _strbuf[_offset+n]
	End Method
	
	Method ReadStringValue(tok:JToken)
		Assert tok, "JParser#ReadStringValue: Token is null"
		If tok.token <> JTokenString Then
			Throw "JParser#ReadStringValue: Expected string literal, found "+StringForToken(tok)
		EndIf
		
		If _handler Then
			Local str$ = _strbuf[tok.start+1..tok.end_]
			str = DecodeJSONString(str)
			_handler.StringValue(str)
		EndIf
	End Method
	
	Method ReadObjectKey(tok:JToken)
		Assert tok, "JParser#ReadObjectKey: Token is null"
		If tok.token <> JTokenString Then
			Throw "JParser#ReadObjectKey: Expected string literal, found "+StringForToken(tok)
		EndIf

		If _handler Then
			Local str$ = _strbuf[tok.start+1..tok.end_]
			str = DecodeJSONString(str)
			_handler.ObjectKey(str)
		EndIf
	End Method
	
	Method ReadArrayValue(tok:JToken)
		Assert tok, "JParser#ReadArrayValue: Token is null"
		If tok.token <> JTokenArrayBegin Then
			Throw "JParser#ReadArrayValue: Expected [, found "+StringForToken(tok)
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
					Throw "JParser#ReadArrayValue: Malformed array: "+StringForToken(tok)
			End Select
		Wend
	End Method
	
	Method ReadObjectValue(tok:JToken)
		Assert tok, "JParser#ReadObjectValue: Token is null"
		If tok.token <> JTokenObjectBegin Then
			Throw "JReaded#ReadObjectValue: Expected {, found "+StringForToken(tok)
		EndIf
		
		If _handler Then _handler.ObjectBegin()
		
		Local valueread%=False
		
		While True
			tok = NextToken()
			
			Assert tok.token = JTokenEof Else "JParser#ReadObjectValue: Expected } or field but reached EOF"
			
			Select tok.token
				Case JTokenString
					Assert valueread = False Else "JParser#ReadObjectValue: Expected , but found string literal"
					
					ReadObjectKey(tok)
					NextToken(JTokenValueSep, ":")
					ReadValue(NextToken())
					valueread = True
						
				Case JTokenArraySep
					Assert valueread = False Else "JParser#ReadObjectValue: Expected } or name, found field separator"
					valueread = False
					
				Case JTokenObjectEnd
					If _handler Then _handler.ObjectEnd()
					Exit
					
				Default
					Throw "JParser#ReadObjectValue: Invalid token "+StringForToken(tok)
			End Select
		Wend
	End Method
	
	Method ReadValue:Object(tok:JToken)
		Assert tok, "JParser#ReadValue: Token is null"
		
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
				Throw "JParser#ReadValue: Invalid value: EOF"
			Default
				Throw "JParser#ReadValue: Invalid token received "+StringForToken(tok)
		End Select
	End Method
	
	Method ReadStringToken()
		_offset :+ 1
		While _offset < _strbuf.Length
			If _strbuf[_offset] = CEscape Then
				_offset :+ 1
			ElseIf _strbuf[_offset] = CQuote Then
				Return
			EndIf
			_offset :+ 1
		Wend
		Throw "JParser#ReadStringToken: Encountered malformed string"
	End Method
	
	Method ReadNumberToken()
		While _offset+1 < _strbuf.Length And JDigitSet.Contains(_strbuf[_offset+1])
			_offset :+1
		Wend
	End Method
	
	Method NextToken:JToken(require:Int=-1, expected$="")
		SkipWhitespace()
		
		If _offset => _strbuf.Length Then
			Return Token(JTokenEof, _offset, _offset)
		EndIf
		
		Local char% = _strbuf[_offset]
		Local tok:JToken = New JToken
		tok.start = _offset
		
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
					Throw "JParser#NextToken: Invalid literal"
				EndIf
			Case Cf
				If Matches("alse") Then
					tok.token = JTokenFalse
				Else
					Throw "JParser#NextToken: Invalid literal"
				EndIf
			Case Cn
				If Matches("ull") Then
					tok.token = JTokenNull
				Else
					Throw "JParser#NextToken: Invalid literal"
				EndIf
			Default
				If JNumberStartingSet.Contains(char) Then
					tok.token = JTokenNumber
					ReadNumberToken
				Else
					Throw "JParser#NextToken: Invalid character while parsing JSON string"
				EndIf
		End Select
		
		tok.end_ = _offset
		_offset :+ 1
		
		If require <> -1 Then
			If expected Then
				Assert tok.token=require, "JParser#NextToken: Expected token "+expected+", found "+StringForToken(tok)
			Else
				Assert tok.token, "JParser#NextToken: Invalid token "+StringForToken(tok)
			EndIf
		EndIf
		
		Return tok
	End Method
	
	Method Matches:Int(s$)
		Local off% = _offset + 1
		For Local idx:Int = 0 Until s.Length
			If off >= _strbuf.Length Or _strbuf[off] <> s[idx] Then
				Return False
			EndIf
			off :+ 1
		Next
		_offset :+ s.Length
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
				Throw "JParser#StringForToken: Invalid token "+tok.token
		End Select
	End Method
End Type

