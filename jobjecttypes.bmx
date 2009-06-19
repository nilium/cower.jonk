SuperStrict

Import brl.Reflection
Import brl.Map
Import cower.Numerical

Import "jsonliterals.bmx"

Const JInvalidType:Int = -1
Const JNullType:Int = 0
Const JObjectType:Int = 1
Const JArrayType:Int = 2
Const JNumberType:Int = 3
Const JStringType:Int = 4
Const JBoolType:Int = 5

Function JType:Int(obj:Object)
	Global _numTypeId:TTypeId
	Global _mapTypeId:TTypeId
	Global _objArrTypeId:TTypeId
	
	If obj = JTrue Or obj = JFalse Then
		Return JBoolType
	EndIf
	
	If _numTypeId = Null Then
		_numTypeId = TTypeId.ForName("TNumber")
		_mapTypeId = TTypeId.ForName("TMap")
		_objArrTypeId = ObjectTypeId.ArrayType()
	EndIf
	
	Local tid:TTypeId = TTypeId.ForObject(obj)
	Select tid
		Case _mapTypeId
			Return JObjectType
		Case _objArrTypeId, ArrayTypeId ' this is called a "hackjob"
			Return JArrayType
		Case StringTypeId
			Return JStringType
		Default
			If obj Then
				If tid.ExtendsType(_numTypeId) Then
					If TNumber(obj).GetType() = TYPE_BOOL Then
						Return JBoolType
					Else
						Return JNumberType
					EndIf
				ElseIf tid.ExtendsType(_mapTypeId) Then
					Return JObjectType
				Else
					Return JInvalidType
				EndIf
			Else
				Return JNullType
			EndIf
	End Select
End Function
