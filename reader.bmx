SuperStrict

Import brl.LinkedList
Import brl.Map
Import cower.Charset
Import cower.Numerical

Import "jsonstring.bmx"
Import "jsonliterals.bmx"

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

Type JReader
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
	
	Method InitWithString:JReader(str$)
		_strbuf = str
		_offset = 0
		Return Self
	End Method
	
	Method Parse:Object()
		root = ReadValue(NextToken())
		_strbuf = Null
		_offset = 0
		Return root
	End Method
	
	Method GetRoot:Object()
		Return root
	End Method
	
	' PRIVATE
	
	Method SkipWhitespace()
		While _offset < _strbuf.Length And JWhitespaceSet.Contains(_strbuf[_offset])
			_offset :+ 1
		Wend
	End Method
	
	Method ReadStringValue:String(tok:JToken)
		Assert tok, "JReader#ReadStringValue: Token is null"
		If tok.token <> JTokenString Then
			Throw "JReader#ReadStringValue: Expected {, found "+StringForToken(tok)
		EndIf
				
		Local str$ = _strbuf[tok.start+1..tok.end_]
		
		Return DecodeJSONString(str)
	End Method
	
	Method ReadArrayValue:Object[](tok:JToken)
		Assert tok, "JReader#ReadArrayValue: Token is null"
		If tok.token <> JTokenArrayBegin Then
			Throw "JReader#ReadArrayValue: Expected {, found "+StringForToken(tok)
		EndIf
		
		tok = NextToken()
		If tok.token = JTokenArrayEnd Then
			Return New Object[0]
		EndIf
		
		Local values:Object[32]
		Local val_len:Int = 1
		
		values[0] = ReadValue(tok)
		
		While True
			tok = NextToken()
			Select tok.token
				Case JTokenArraySep
					If val_len = values.Length Then
						values = values[..values.Length*2]
					EndIf
					values[val_len] = ReadValue(NextToken())
					val_len :+ 1
				Case JTokenArrayEnd
					Exit
				Default
					Throw "JReader#ReadArrayValue: Malformed array: "+StringForToken(tok)
			End Select
		Wend
		
		If val_len < values.Length Then
			Return values[..val_len]
		Else
			Return values
		EndIf
	End Method
	
	Method ReadObjectValue:TMap(tok:JToken)
		Assert tok, "JReader#ReadObjectValue: Token is null"
		If tok.token <> JTokenObjectBegin Then
			Throw "JReaded#ReadObjectValue: Expected {, found "+StringForToken(tok)
		EndIf
		
		Local obj:TMap = New TMap
		Local name:String
		Local value:Object
		While True
			tok = NextToken()
			
			Select tok.Token
				Case JTokenEof
					Throw "JReaded#ReadObjectValue: Expected } but reached EOF"
				Case JTokenString
					name = ReadStringValue(tok)
					NextToken(JTokenValueSep, ":")
					value = ReadValue(NextToken())
					obj.Insert(name,value)
				Case JTokenArraySep
					If Not name Then
						Throw "JReader#ReadObjectValue: Expected } or name, found name separator"
					Else
						name = ReadStringValue(NextToken(JTokenString, "name"))
						NextToken(JTokenValueSep, ":")
						value = ReadValue(NextToken())
						obj.Insert(name,value)
					EndIf
				Case JTokenObjectEnd
					Exit
				Default
					Throw "JReader#ReadObjectValue: Invalid token "+StringForToken(tok)
			End Select
		Wend
		Return obj
	End Method
	
	Method ReadValue:Object(tok:JToken)
		Assert tok, "JReader#ReadValue: Token is null"
		
		Select tok.token
			Case JTokenObjectBegin
				Return ReadObjectValue(tok)
			Case JTokenArrayBegin
				Return ReadArrayValue(tok)
			Case JTokenString
				Return ReadStringValue(tok)
			Case JTokenNumber
				Local ext$ = _strbuf[tok.start..tok.end_+1]
				If JDoubleSet.FindInString(ext) <> -1 Then
					Return TNumber.ForDouble(ext.ToDouble())
				Else
					Return TNumber.ForInt(ext.ToInt())
				EndIf
			Case JTokenNull
				Return Null
			Case JTokenTrue
				Return JTrue
			Case JTokenFalse
				Return JFalse
			Case JTokenEof
				Throw "JReader#ReadValue: Invalid value: EOF"
			Default
				Throw "JReader#ReadValue: Invalid token received "+StringForToken(tok)
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
		Throw "JReader#ReadStringToken: Encountered malformed string"
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
					Throw "JReader#NextToken: Invalid literal"
				EndIf
			Case Cf
				If Matches("alse") Then
					tok.token = JTokenFalse
				Else
					Throw "JReader#NextToken: Invalid literal"
				EndIf
			Case Cn
				If Matches("ull") Then
					tok.token = JTokenNull
				Else
					Throw "JReader#NextToken: Invalid literal"
				EndIf
			Default
				If JNumberStartingSet.Contains(char) Then
					tok.token = JTokenNumber
					ReadNumberToken
				Else
					Throw "JReader#NextToken: Invalid character while parsing JSON string"
				EndIf
		End Select
		
		tok.end_ = _offset
		_offset :+ 1
		
		If require <> -1 Then
			If expected Then
				Assert tok.token=require, "JReader#NextToken: Expected token "+expected+", found "+StringForToken(tok)
			Else
				Assert tok.token, "JReader#NextToken: Invalid token "+StringForToken(tok)
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
				Throw "JReader#StringForToken: Invalid token "+tok.token
		End Select
	End Method
End Type

