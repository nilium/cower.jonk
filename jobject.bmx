SuperStrict

Import cower.Charset
Import brl.Map
Import brl.LinkedList
Import brl.Reflection

Global JNull:JValue = New _JNull
Global JTrue:JValue = New _JBoolean.InitWithBool(True)
Global JFalse:JValue = New _JBoolean.InitWithBool(False)

Global JNullType:TTypeId = TTypeId.ForName("_JNull")
Global JBooleanType:TTypeId = TTypeId.ForName("_JBoolean")
Global JObjectType:TTypeId = TTypeId.ForName("JObject")
Global JArrayType:TTypeId = TTypeId.ForName("JArray")
Global JStringType:TTypeId = TTypeId.ForName("JString")
Global JIntType:TTypeId = TTypeId.ForName("JInt")
Global JDoubleType:TTypeId = TTypeId.ForName("JDouble")

Private

Function __prettyNumber$(n:Double)
	Global nonzeroSet:TCharacterSet = New TCharacterSet.InitWithString("1-9")
	Local str$ = String(n)
	If str.Find(".") <> -1 Then
		Local eidx% = str.Find("e")
		If eidx <> -1 Then
			Local nzidx% = nonzeroSet.FindLastInString(str, eidx-1)
			If nzidx < eidx-1 Then
				str = str[..nzidx+1]+str[eidx..]
			EndIf
		Else
			Local idx:Int = nonzeroSet.FindLastInString(str)
			If idx <> -1 And idx < (str.Length-1) Then
				str = str[..idx+1]
			EndIf
		EndIf
	EndIf
	Return str
End Function

Public

Type JValue Abstract
	Field _type:TTypeId
	
	Method PrettyString$(tab$="")
		Return ToString()
	End Method
	
	Method GetType:TTypeId() Final
		If Not _type Then
			_type = TTypeId.ForObject(Self)
		EndIf
		Return _type
	End Method
End Type

Type JObjectMember
	Field Name:String
	Field Value:JValue
	
	Method Compare:Int(other:Object)
		Return Name.Compare(JObjectMember(other).Name)
	End Method
End Type

Type JObjectEnumerator Final
	Field _enum:TListEnum
	Field _key:Int
	
	Method InitWithKeys:JObjectEnumerator( values:TList )
		_enum = values.ObjectEnumerator()
		_key = True
		Return Self
	End Method
	
	Method InitWithValues:JObjectEnumerator( values:TList )
		_enum = values.ObjectEnumerator()
		_key = False
		Return Self
	End Method
	
	Method HasNext%()
		Return _enum.HasNext()
	End Method
	
	Method NextObject:Object()
		Local member:JObjectMember = JObjectMember(_enum.NextObject())
		If member Then
			If _key Then
				Return member.Name
			Else
				Return member.Value
			EndIf
		Else
			Return Null
		EndIf
	End Method
End Type

Type JObject Extends JValue Final
	Field _values:TList
	
	Method New()
		_values = New TList
	End Method
	
	Method InitWithMap:JObject( values:TMap )
		For Local i:TNode = EachIn values
			SetValueForName(String(i.Key()), JValue(i.Value()))
		Next
		Return Self
	End Method
	
	Method InitWithKeysAndValues:JObject( keys:TList, values:TList )
		Local keyEnum:TListEnum = keys.ObjectEnumerator()
		Local valueEnum:TListEnum = values.ObjectEnumerator()
		While keyEnum.HasNext() And valueEnum.HasNext()
			SetValueForName(String(keyEnum.NextObject()), JValue(valueEnum.NextObject()))
		Wend
		Return Self
	End Method
	
	Method GetValueForName:JValue(name:String)
		Local link:TLink = _values.FindLink(name)
		If link Then
			Local member:JObjectMember = JObjectMember(link.Value())
			If member Then
				Return member.Value
			EndIf
		EndIf
		Return Null
	End Method
	
	Method SetValueForName(name:String, value:JValue)
		If Not name Then
			Throw "JObject#SetValue: Empty key"
		EndIf
		
		If Not value Then
			value = JNull
		EndIf
		
		Local ov:JObjectMember = New JObjectMember
		ov.Name = name
		ov.Value = value
		
		_values.AddLast(ov)
	End Method
	
	Method EnumKeys:JObjectEnumerator()
		Return New JObjectEnumerator.InitWithKeys(_values)
	End Method
	
	Method EnumValues:JObjectEnumerator()
		Return New JObjectEnumerator.InitWithValues(_values)
	End Method
	
	Method ObjectEnumerator:TListEnum()
		Return _values.ObjectEnumerator()
	End Method
	
	Method PrettyString$(tab$="")
		Local innerTab$ = tab+"~t"
		Local outs$ = "{~n"
		Local name:JString = New JString
		Local nodeEnum:TListEnum = _values.ObjectEnumerator()
		Local member:JObjectMember
		While nodeEnum.HasNext()
			member = JObjectMember(nodeEnum.NextObject())
			
			outs :+ innerTab
			
			name.SetValue(member.Name)
			outs :+ name.PrettyString(tab)
			outs :+ ": "
			
			outs :+ member.Value.PrettyString(innerTab)
			
			If nodeEnum.HasNext() Then
				outs :+ ",~n"
			EndIf
		Wend
		outs :+ "~n"+tab+"}"
		Return outs
	End Method
	
	Method ToString$()
		Local outs$ = "{"
		Local name:JString = New JString
		Local nodeEnum:TListEnum = _values.ObjectEnumerator()
		Local member:JObjectMember
		While nodeEnum.HasNext()
			member = JObjectMember(nodeEnum.NextObject())
			
			name.SetValue(member.Name)
			outs :+ name.ToString()
			outs :+ ":"
			outs :+ member.Value.ToString()
			
			If nodeEnum.HasNext() Then
				outs :+ ","
			EndIf
		Wend
		outs :+ "}"
		Return outs
	End Method
End Type

Type JArray Extends JValue Final
	Field _values:JValue[]
	
	Method New()
	End Method
	
	Method InitWithList:JArray(list:TList)
		__expandToFit(list.Count())
		Local idx:Int = 0
		For Local i:JValue = EachIn list
			SetValueAtIndex(idx, i)
			idx :+ 1
		Next
		Return Self
	End Method
	
	Method InitWithArray:JArray(arr:JValue[])
		SetArray(arr)
		Return Self
	End Method
	
	Method SetValueAtIndex(idx:Int, val:JValue)
		__expandToFit(idx+1)
		If val = Null Then
			val = JNull
		EndIf
		_values[idx] = val
	End Method
	
	Method GetValueAtIndex:JValue(idx:Int)
		If idx < _values.Length Then
			Return _values[idx]
		EndIf
		Return JNull
	End Method
	
	Method GetArray:JValue[]()
		Return _values
	End Method
	
	Method SetArray(values:JValue[])
		If values.Length Then
			Local lastValue:Int = 0
			For Local idx:Int = 0 Until values.Length
				If values[idx] Then
					lastValue = idx
				EndIf
			Next
			
			_values = values[0..lastValue+1]
				
			For Local idx:Int = 0 Until _values.Length
				If Not _values[idx] Then
					_values[idx] = JNull
				EndIf
			Next
		Else
			_values = Null
		EndIf
	End Method
	
	Method PrettyString$(tab$="")
		Local containsObject%=False
		For Local i:JValue = EachIn _values
			If i.GetType() = JObjectType Then
				containsObject = True
				Exit
			EndIf
		Next
		
		If containsObject Then
			Local innerTab$ = tab+"~t"
			Local outs$ = "[~n"
			For Local i:Int = 0 Until _values.Length
				outs :+ innerTab+_values[i].PrettyString(innerTab)
				If i < _values.Length-1 Then
					outs :+ ",~n"
				EndIf
			Next
			outs :+ tab+"~n]"
			Return outs
		Else
			Return ToString()
		EndIf
	End Method
	
	Method ToString$()
		Local outs$ = "["
		Local idx:Int
		Local last:Int = _values.Length-1
		Local val:JValue
		For idx = 0 Until _values.Length
			val = _values[idx]
			If val Then
				outs :+ _values[idx].ToString()
			Else
				outs :+ "null"
			EndIf
			
			If idx < last Then
				outs :+ ", "
			EndIf
		Next
		outs :+ "]"
		Return outs
	End Method
	
	' PRIVATE
	
	Method __expandToFit(size:Int)
		If size <= _values.Length Then
			Return
		EndIf
		
		_values = _values[..size]
	End Method
End Type

Private

Global jstring_escape_codes:String[32, 2]
jstring_escape_codes[0, 0] = Chr(0);   jstring_escape_codes[0, 1]  = "\0"
jstring_escape_codes[1, 0] = Chr(1);   jstring_escape_codes[1, 1]  = "\u0001"
jstring_escape_codes[2, 0] = Chr(2);   jstring_escape_codes[2, 1]  = "\u0002"
jstring_escape_codes[3, 0] = Chr(3);   jstring_escape_codes[3, 1]  = "\u0003"
jstring_escape_codes[4, 0] = Chr(4);   jstring_escape_codes[4, 1]  = "\u0004"
jstring_escape_codes[5, 0] = Chr(5);   jstring_escape_codes[5, 1]  = "\u0005"
jstring_escape_codes[6, 0] = Chr(6);   jstring_escape_codes[6, 1]  = "\u0006"
jstring_escape_codes[7, 0] = Chr(7);   jstring_escape_codes[7, 1]  = "\a"
jstring_escape_codes[8, 0] = Chr(8);   jstring_escape_codes[8, 1]  = "\b"
jstring_escape_codes[9, 0] = Chr(9);   jstring_escape_codes[9, 1]  = "\t"
jstring_escape_codes[10, 0] = Chr(10); jstring_escape_codes[10, 1] = "\n"
jstring_escape_codes[11, 0] = Chr(11); jstring_escape_codes[11, 1] = "\v"
jstring_escape_codes[12, 0] = Chr(12); jstring_escape_codes[12, 1] = "\f"
jstring_escape_codes[13, 0] = Chr(13); jstring_escape_codes[13, 1] = "\r"
jstring_escape_codes[14, 0] = Chr(14); jstring_escape_codes[14, 1] = "\u000e"
jstring_escape_codes[15, 0] = Chr(15); jstring_escape_codes[15, 1] = "\u000f"
jstring_escape_codes[16, 0] = Chr(16); jstring_escape_codes[16, 1] = "\u0010"
jstring_escape_codes[17, 0] = Chr(17); jstring_escape_codes[17, 1] = "\u0011"
jstring_escape_codes[18, 0] = Chr(18); jstring_escape_codes[18, 1] = "\u0012"
jstring_escape_codes[19, 0] = Chr(19); jstring_escape_codes[19, 1] = "\u0013"
jstring_escape_codes[20, 0] = Chr(20); jstring_escape_codes[20, 1] = "\u0014"
jstring_escape_codes[21, 0] = Chr(21); jstring_escape_codes[21, 1] = "\u0015"
jstring_escape_codes[22, 0] = Chr(22); jstring_escape_codes[22, 1] = "\u0016"
jstring_escape_codes[23, 0] = Chr(23); jstring_escape_codes[23, 1] = "\u0017"
jstring_escape_codes[24, 0] = Chr(24); jstring_escape_codes[24, 1] = "\u0018"
jstring_escape_codes[25, 0] = Chr(25); jstring_escape_codes[25, 1] = "\u0019"
jstring_escape_codes[26, 0] = Chr(26); jstring_escape_codes[26, 1] = "\u001a"
jstring_escape_codes[27, 0] = Chr(27); jstring_escape_codes[27, 1] = "\e"
jstring_escape_codes[28, 0] = Chr(28); jstring_escape_codes[28, 1] = "\u001c"
jstring_escape_codes[29, 0] = Chr(29); jstring_escape_codes[29, 1] = "\u001d"
jstring_escape_codes[30, 0] = Chr(30); jstring_escape_codes[30, 1] = "\u001e"
jstring_escape_codes[31, 0] = Chr(31); jstring_escape_codes[31, 1] = "\u001f"

Public

Type JString Extends JValue Final
	Field _value:String
	
	Method InitWithString:JString(s$)
		_value = s
		Return Self
	End Method
	
	Method ToString$()
		Local val:String = _value.Replace("\","\\")
		For Local i:Int = 0 Until 32
			val = val.Replace(jstring_escape_codes[i,0], jstring_escape_codes[i,1])
		Next
		Return "~q"+val+"~q"
	End Method
	
	Method GetValue$()
		Return _value
	End Method
	
	Method SetValue(s$)
		_value = s
	End Method
	
	Method Compare:Int(other:Object)
		Local os:JString = JString(other)
		If os Then
			Return _value.Compare(os._value)
		ElseIf String(other)
			Return _value.Compare(other)
		Else
			Return Super.Compare(other)
		EndIf
	End Method
End Type

Type JInt Extends JValue Final
	Field _value:Int
	
	Method InitWithNumber:JInt(i%)
		_value = i
		Return Self
	End Method
	
	Method GetValue%()
		Return _value
	End Method
	
	Method SetValue(i%)
		_value = i
	End Method
	
	Method ToString$()
		Return String(_value)
	End Method
End Type

Type JDouble Extends JValue Final
	Field _value:Double
	
	Method InitWithNumber:JDouble(d!)
		_value = d
		Return Self
	End Method
	
	Method GetValue!()
		Return _value
	End Method
	
	Method SetValue(d!)
		_value = d
	End Method
	
	Method ToString$()
		Return __prettyNumber(_value)
	End Method
End Type

Private

Type _JNull Extends JValue Final
	Method ToString$()
		Return "null"
	End Method
End Type

Type _JBoolean Extends JValue Final
	Field _value:Int
	
	Method InitWithBool:_JBoolean(v%)
		_value = v>0
		Return Self
	End Method
	
	Method ToString$()
		If _value Then
			Return "true"
		Else
			Return "false"
		EndIf
	End Method
End Type
