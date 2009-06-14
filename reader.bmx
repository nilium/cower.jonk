SuperStrict

Import cower.Charset
Import brl.Stream

Import "jobject.bmx"

Public

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

Private

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

Function JHexCharToByte:Int(char:Int)
	Global _HexAF:Int[] = [$0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $A, $B, $C, $D, $E, $F]
	If char >= 97 And char <= 122 Then
		Return _HexAF[char-87]
	ElseIf char >= 65 And char <= 90 Then
			Return _HexAF[char-55]
	ElseIf char >= 48 And char <= 58 Then
			Return _HexAF[char-48]
	EndIf
	Throw "Invalid hex character "+char
End Function

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
	
	Field root:JValue
	
	Field _tokens:TList
	Field _tokenLink:TLink
	Field _strbuf$
	Field _offset:Int
	
	Method New()
		_tokens = New TList
	End Method
	
	Method InitWithString:JReader(str$)
		_strbuf = str
		_offset = 0
		Return Self
	End Method
	
	Method Parse:JValue()
		root = ReadValue(NextToken())
		Return root
	End Method
	
	Method GetRoot:JValue()
		Return root
	End Method
	
	' PRIVATE
	
	Method SkipWhitespace()
		While _offset < _strbuf.Length And JWhitespaceSet.Contains(_strbuf[_offset])
			_offset :+ 1
		Wend
	End Method
	
	Method ReadStringValue:JString(tok:JToken)
		Assert tok, "Token is null"
		If tok.token <> JTokenString Then
			Throw "Expected {, found "+StringForToken(tok)
		EndIf
		
		Rem
		jstring_escape_codes[0, 0] = Chr(0);   jstring_escape_codes[0, 1]  = "\0"
		jstring_escape_codes[7, 0] = Chr(7);   jstring_escape_codes[7, 1]  = "\a"
		jstring_escape_codes[8, 0] = Chr(8);   jstring_escape_codes[8, 1]  = "\b"
		jstring_escape_codes[9, 0] = Chr(9);   jstring_escape_codes[9, 1]  = "\t"
		jstring_escape_codes[10, 0] = Chr(10); jstring_escape_codes[10, 1] = "\n"
		jstring_escape_codes[11, 0] = Chr(11); jstring_escape_codes[11, 1] = "\v"
		jstring_escape_codes[12, 0] = Chr(12); jstring_escape_codes[12, 1] = "\f"
		jstring_escape_codes[13, 0] = Chr(13); jstring_escape_codes[13, 1] = "\r"
		jstring_escape_codes[27, 0] = Chr(27); jstring_escape_codes[27, 1] = "\e"
		EndRem
		
		Local str$ = _strbuf[tok.start+1..tok.end_]
		Local unibuf:Byte[] = [$24:Byte, 0:Byte, 0:Byte, 0:Byte, 0:Byte]
		Local buf:Short Ptr = Short Ptr(MemAlloc(str.Length*2))
		Local bufSize:Int = 0
		Local p:Short Ptr = buf
		Local char:Int
		For Local idx:Int = 0 Until str.Length
			char = str[idx]
			Select char
				Case CEscape
					' Try
						idx :+ 1
						char = str[idx]
						Select char
							Case 48  ' \0
								p[0] = 0
							Case 97  ' \a
								p[0] = 7
							Case 98  ' \b
								p[0] = 8
							Case 116 ' \t
								p[0] = 9
							Case 110 ' \n
								p[0] = 10
							Case 118 ' \v
								p[0] = 11
							Case 102 ' \f
								p[0] = 12
							Case 114 ' \r
								p[0] = 13
							Case 101 ' \e
								p[0] = 27
							Case 117
								p[0] = ("$"+str[idx+1..idx+5]).ToInt()'Short((JHexCharToByte(str[idx+1]) Shr 12)|(JHexCharToByte(str[idx+2]) Shr 8)|(JHexCharToByte(str[idx+3]) Shr 4)|JHexCharToByte(str[idx+4]))
								idx :+ 4
							Default
								p[0] = char
						End Select
					' Catch o:Object
					' 	Throw "Malformed escape in ~q"+str+"~q at offset "+idx
					' End Try
				Default
					p[0] = char
			End Select
			p :+ 1
			bufSize :+ 1
		Next
		str = String.FromShorts(buf, bufSize)
		MemFree(buf)
		Return New JString.InitWithString(str)
	End Method
	
	Method ReadArrayValue:JArray(tok:JToken)
		Assert tok, "Token is null"
		If tok.token <> JTokenArrayBegin Then
			Throw "Expected {, found "+StringForToken(tok)
		EndIf
		
		Local values:TList = New TList
		Local value:JValue
		
		tok = NextToken()
		If tok.token = JTokenArrayEnd Then
			Return New JArray
		EndIf
		
		values.AddLast(ReadValue(tok))
		
		While True
			tok = NextToken()
			Select tok.token
				Case JTokenArraySep
					values.AddLast(ReadValue(NextToken()))
				Case JTokenArrayEnd
					Exit
				Default
					Throw "Malformed array: "+StringForToken(tok)
			End Select
		Wend
		
		Return New JArray.InitWithList(values)
	End Method
	
	Method ReadObjectValue:JObject(tok:JToken)
		Assert tok, "Token is null"
		If tok.token <> JTokenObjectBegin Then
			Throw "Expected {, found "+StringForToken(tok)
		EndIf
		
		Local obj:JObject = New JObject
		Local name:JString
		Local value:JValue
		While True
			tok = NextToken()
			
			Select tok.Token
				Case JTokenEof
					Throw "Expected } but reached EOF"
				Case JTokenString
					name = ReadStringValue(tok)
					NextToken(JTokenValueSep, ":")
					value = ReadValue(NextToken())
					obj.SetValueForName(name.GetValue(),value)
				Case JTokenArraySep
					If Not name Then
						Throw "Expected } or name, found name separator"
					Else
						name = ReadStringValue(NextToken(JTokenString, "name"))
						NextToken(JTokenValueSep, ":")
						value = ReadValue(NextToken())
						obj.SetValueForName(name.GetValue(),value)
					EndIf
				Case JTokenObjectEnd
					Exit
				Default
					Throw "Invalid token "+StringForToken(tok)
			End Select
		Wend
		Return obj
	End Method
	
	Method ReadValue:JValue(tok:JToken)
		Assert tok, "Token is null"
		
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
					Return New JDouble.InitWithNumber(ext.ToDouble())
				Else
					Return New JInt.InitWithNumber(ext.ToInt())
				EndIf
			Case JTokenNull
				Return JNull
			Case JTokenTrue
				Return JTrue
			Case JTokenFalse
				Return JFalse
			Case JTokenEof
				Return Null
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
		Throw "Encountered malformed string"
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
					Throw "Invalid literal"
				EndIf
			Case Cf
				If Matches("alse") Then
					tok.token = JTokenFalse
				Else
					Throw "Invalid literal"
				EndIf
			Case Cn
				If Matches("ull") Then
					tok.token = JTokenNull
				Else
					Throw "Invalid literal"
				EndIf
			Default
				If JNumberStartingSet.Contains(char) Then
					tok.token = JTokenNumber
					ReadNumberToken
				Else
					Throw "Invalid character while parsing JSON string"
				EndIf
		End Select
		
		tok.end_ = _offset
		_offset :+ 1
		
		If require <> -1 Then
			If expected Then
				Assert tok.token=require, "Expected token "+expected+", found "+StringForToken(tok)
			Else
				Assert tok.token, "Invalid token "+StringForToken(tok)
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
				Throw "Invalid token "+tok.token
		End Select
	End Method
End Type

