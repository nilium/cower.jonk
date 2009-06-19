SuperStrict

Import brl.Reflection
Import brl.Map
Import cower.Numerical

Import "jsonliterals.bmx"

Const JNullType:Int = 0
Const JObjectType:Int = 1
Const JArrayType:Int = 2
Const JNumberType:Int = 3
Const JStringType:Int = 4
Const JBoolType:Int = 5

Function JType:Int(obj:Object)
	Global _numTypeId:TTypeId
	Global _mapTypeId:TTypeId
	
	If obj = JTrue Or obj = JFalse Then
		Return JBoolType
	EndIf
	
	If _numTypeId = Null Then
		_numTypeId = TTypeId.ForName("TNumber")
		_mapTypeId = TTypeId.ForName("TMap")
	EndIf
	
	Select TTypeId.ForObject(obj)
		Case _mapTypeId
			Return JObjectType
		Case _numTypeId
			If TNumber(obj).GetType() = TYPE_BOOL Then
				Return JBoolType
			Else
				Return JNumberType
			EndIf
		Case ArrayTypeId
			Return JArrayType
		Case StringTypeId
			Return JStringType
		Default
			Return JNullType
	End Select
End Function
