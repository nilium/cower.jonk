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
		Case Null
			Return JNullType
		Case _mapTypeId
			Return JObjectType
		Case _objArrTypeId, ArrayTypeId ' this is called a "hackjob"
			Return JArrayType
		Case StringTypeId
			Return JStringType
		Default
			Local nm:TNumber = TNumber(obj)
			If nm And nm.GetType() = TYPE_BOOL Then 'literal bool
				Return JBoolType
			ElseIf nm Then			'regular number
				Return JNumberType
			ElseIf TMap(obj) Then	'check for subclass of TMap
				Return JObjectType
			EndIf
	End Select
	
	Return JInvalidType
End Function
