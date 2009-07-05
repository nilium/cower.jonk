Rem
Copyright (c) 2009 Noel R. Cower

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
EndRem

SuperStrict

Import cower.Charset
Import "exception.bmx"

Private

Include "characters.bmx"

Function JHexCharToByte:Int(char:Int)
	Global _HexAF:Int[] = [$0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $A, $B, $C, $D, $E, $F]
	If char >= 97 And char <= 122 Then
		Return _HexAF[char-87]
	ElseIf char >= 65 And char <= 90 Then
			Return _HexAF[char-55]
	ElseIf char >= 48 And char <= 58 Then
			Return _HexAF[char-48]
	EndIf
	Throw JException.Create("JHexCharToByte", "Invalid hex character ~q"+Chr(char)+"~q", JInvalidOffsetError)
End Function

Public

Function EncodeJSONString:String(str:String)
	Global hexchartable:Int[] = [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70]
	Global complexEscapes:TCharacterSet = New TCharacterSet.InitWithRanges([1,5, 14,12, 28,3])
	
	Local idx:Int
	Local strlen% = 0
	Local char%
	Local buf:Short[]
	Local p:Short Ptr
	
	For idx = 0 Until str.Length
		char = str[idx]
		If complexEscapes.Contains(str[idx]) Then
			strlen :+ 6
		ElseIf char <= 27 Or char = JCHAR_BACKSLASH Or char = JCHAR_QUOTE Then
			strlen :+ 2
		Else
			strlen :+ 1
		EndIf
	Next
	
	If strlen = str.Length Then
		Return str
	EndIf
	
	buf = New Short[strlen]
	p = buf
	
	For idx = 0 Until str.Length
		char = str[idx]
		If complexEscapes.Contains(char) Then
			p[0] = JCHAR_BACKSLASH
			p[1] = JCHAR_U
			p[2] = JCHAR_ZERO
			p[3] = JCHAR_ZERO
			p[4] = hexchartable[char Shr 4]
			p[5] = hexchartable[char & $F]
			p :+ 6
		ElseIf char <= 27 Or char = JCHAR_BACKSLASH Or char = JCHAR_QUOTE Then
			p[0] = JCHAR_BACKSLASH
			Select char
				Case 0
					p[1] = JCHAR_ZERO
				Case 7
					p[1] = JCHAR_A
				Case 8
					p[1] = JCHAR_B
				Case 9
					p[1] = JCHAR_T
				Case 10
					p[1] = JCHAR_N
				Case 11
					p[1] = JCHAR_V
				Case 12
					p[1] = JCHAR_F
				Case 13
					p[1] = JCHAR_R
				Case 27
					p[1] = JCHAR_E
				Default
					p[1] = char
			End Select
			p :+ 2
		Else
			p[0] = char
			p :+ 1
		EndIf
	Next
	
	Return String.FromShorts(buf, buf.Length)
End Function

Function DecodeJSONString:String(str:String)
	Local buf:Short Ptr = Short Ptr(MemAlloc(str.Length*2))
	If buf = Null Then
		Throw JException.Create("DecodeJSONString", "Unable to allocate buffer of size "+(str.Length*2)+" bytes", JBufferAllocationError)
	EndIf
	Local bufSize:Int = 0
	Local p:Short Ptr = buf
	Local char:Int
	For Local idx:Int = 0 Until str.Length
		char = str[idx]
		Select char
			Case JCHAR_BACKSLASH
				Try
					idx :+ 1
					char = str[idx]
					Select char
						Case JCHAR_ZERO  ' \0
							p[0] = 0
						Case JCHAR_A  ' \a
							p[0] = 7
						Case JCHAR_B  ' \b
							p[0] = 8
						Case JCHAR_T ' \t
							p[0] = 9
						Case JCHAR_N ' \n
							p[0] = 10
						Case JCHAR_V ' \v
							p[0] = 11
						Case JCHAR_F ' \f
							p[0] = 12
						Case JCHAR_R ' \r
							p[0] = 13
						Case JCHAR_E ' \e
							p[0] = 27
						Case JCHAR_U '\u[a-fA-F0-9]{4}
							p[0] = Short((JHexCharToByte(str[idx+1]) Shl 12)|(JHexCharToByte(str[idx+2]) Shl 8)|(JHexCharToByte(str[idx+3]) Shl 4)|JHexCharToByte(str[idx+4]))
							idx :+ 4
						Default
							p[0] = char
					End Select
				Catch o:Object
					Throw MalformedStringException("DecodeJSONString", "Malformed escape in string", str, idx, o)
				End Try
			Default
				p[0] = char
		End Select
		p :+ 1
		bufSize :+ 1
	Next
	str = String.FromShorts(buf, bufSize)
	MemFree(buf)
	Return str
End Function

Function PrettyDouble$(n:Double)
	If n = Int(n) Then
		Return String(Int(n))
	EndIf
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
