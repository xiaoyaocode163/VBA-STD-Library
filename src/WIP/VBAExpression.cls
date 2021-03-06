VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "VBAExpression"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

'A VBA wrapper for Excel formulae
'Allows accessing of registered object data

'Example:
'  Dim f_x as VBAExpression
'  set f_x = VBAExpression.Create()
'
'  set f_x.RegisteredObjects["sheet"] = ActiveSheet
'  f_x.Formula = "#sheet.UsedRange.rows.count"
'
'  ==> Count of rows in used range of ActiveSheet
'
'  Public Functions in modules are also of course available within the VBA Expression.
'  As with formulae, the module name can also be included:
'
'    f_x.Formula = "VBAExpressionTesting.TestPublicFunc()"
'    ?f_x() '=> True
'
'  Calling functions on objects is not supported. E.G.
'
'    f_x.Formula = "#obj.SomeFunc()"
'
'  As a work around, use a Public module function:
'
'    Module MyModule
'      Function SomeFunc(obj as object)
'        SomeFunc = obj.SomeFunc()
'      End Function
'    End Module
'    ...
'    f_x.Formula = "MyModule.SomeFunc(#obj)"


' SPEC:
'----------------------------
'
'**************
'* WHITESPACE *
'**************
' Represents /\s/
' Any whitespace including spaces, tabs and new lines
'
'
'***********
'* KEYWORD *
'***********
' A keyword is a word or phrase which represents a constant or value
'
'************
'* WRAPPERS *
'************
'Wrappers declare a start and an end.
'All characters between the start and end point will be consumed and passed to the build AST callback
'Wrappers can declare whether they allow wrappers withing themselves (allowing "(a*(b+c))" to be parse correctly vs "hello","world")
'Wrappers can declare escape characters also
'  Standard wrappers:
'    " ... "" ... " --> String
'    / ... \/ ... / --> Regex
'    ( ... )        --> Brackets
'  Non-standard wrappers:
'     [ ... ] --> Array
'     { ... } --> Dictionary
'    @{ ... } --> Callback
'    [@ ... ] --> Field in current table (only makes sense in specific context (caller has to be set))
'
'Wrappers need to be registered before lexing/compiling can begin.


'*************
'* OPERATORS *
'*************
'Operators are keywords which alias to existing functions:
'  Standard Operators:
'     . --> Access(obj,acc)
'     + --> Sum(a,b)
'     - --> Subtract(a,b)
'     * --> Multiply(a,b)
'     / --> Divide(a,b)
'     % --> Mod(a,b)
'     & --> Concatenate(a,b)
'    >= --> IsLThanE(a,b)
'    <= --> IsGThanE(a,b)
'     > --> IsGThan(a,b)
'     < --> IsLThan(a,b)
'    <> --> IsNEqual(a,b)
'     = --> IsEqual(a,b)
'  Non Standard Operators:
'    && --> AND(a,b)
'    || --> OR(a,b)
'    ~= --> Regex(haystack,pattern)
'Operators need to be registered before lexing/compiling can begin.
'
'*************
'* FUNCTIONS *
'*************
'Functions are named executables
'  like --> NOTKEYWORD\( ... params ... \)
'Functions can be registered after lexing/compiling.
'

'THE REAL POWER:
'   ALL OF THE ABOVE IS OVERRIDABLE!!


'Parsing process
'* Isolate wrappers - These handle themselves
'* Convert operators to function call convention
'* Identify functions
'* Identify Keywords

'1*5+[1,2,3,{a:"hello"}]
'
'Literal Op(*) Literal Op(+) Wrapper([, Literal Sep Literal Sep Literal Sep Wrapper({, Key Sep Wrapper(", Literal  ,")   ,})     ,])
'
'General parsing process is:
'* All all letters and numbers (i.e. \w+) are classified as literals
'* When we come across an operator we simply mark it an move on
'* When we come across a Wrapper:
'  * We hand over parsing to the Wrapper (allows e.g. string wrappers to assume .+ as string literals)
'  * Depth of wrapping effects evaluation order. 
'  * Evaluation of wrappers is handled by the wrapper also.
'
'
'TODO: Suggested Parsing algorithm  =   Shunting-yard algorithm   (https://en.wikipedia.org/wiki/Shunting-yard_algorithm)



Const ChildrenProperty = "Children"

Public RegisteredObjects As Object
Private pInitialised As Boolean

'Compilation variables
Private isCompiled As Boolean
Private AST As Object

Private pFormula As String

Public Property Get formula() As String
  formula = pFormula
End Property
Public Property Let formula(v As String)
  pFormula = v
  isCompiled = False
End Property

Public Function Create(Optional formula As String, Optional RegisteredObjects As Object) As VBAExpression
  Set Create = New VBAExpression
  Call Create.init(formula, RegisteredObjects)
End Function
Public Function Evaluate() As Variant
Attribute Evaluate.UserMemId=0
  If Not isCompiled Then
    Me.Compile False
  End If
  
  'Evaluate equation:
  Evaluate = Application.Evaluate(sCompiled)
End Function


Public Sub Compile(Optional setCompiled As Boolean = True)
  Set AST = CompileToAST(pFormula)
  isCompiled = setCompiled
End Sub


'New compile is going to do the following:
'    Imagine the following formula:
'        IF("hel""lo #world""",True,$("do").diddle & " hello!",$("do").something.cool("a#sdf",1))
'    In this case we want to scan all the way up to #do
'    Parse previous into a literal
'    Continue parsed #do until we find a "," (or function boundary) while at iBracketScope = 0
'    Pass this section off to be parsed seperately (by ParseVBAExpression), and then continue onwards as a literal.
'Result will look something like this:
'  {
'    Type: "AST",
'    Children: [
'      {Type: "Method", Value: "IF", Children: [
'        {Type: "Wrapper", Value: """",Children: [
'          {Type: "Literal", Value: "hel\"\"lo #world\""}
'        ]},
'        {Type: "Literal", Value: True}
'        {Type: "Operator", Value: "&", Children: [
'          {Type: "Operator", Value: ".", Children: [
'            {Type: "Method", Value: "$", Children: [
'              {Type: "Wrapper", Value: """", Children: [
'                {Type: "Literal", Value: "do"}
'              ]},
'            ]},
'            {Type: "Literal", Value: "diddle"}
'          ]},
'          {Type: "Wrapper", Value: """", Children: [
'            {Type: "Literal", Value: " hello"}
'          ]}
'        ]},
'      {Type: "Operator", Value: ".", Children: [
'        {Type: "Operator", Value: ".", Children: [
'          {Type: "Method", Value: "$", Children: [
'            {Type: "Wrapper", Value: """", Children: [
'              {Type: "Literal", Value: "do"}
'            ]},
'          ]},
'          {Type: "Accessor", Value: "something", Children:[]}
'        ]},
'      {Type: "Accessor", Value: "cool", Children:[
'        {Type: "Wrapper", Value: """", Children: [
'          {Type: "Literal", Value: "a#sdf"}
'        ]},
'        {Type: "Literal", Value: "1"}
'      ]}
'    ]
'  }
'

'Example:
'?VBAExpression.CompileToAST("IF(""hel""""lo #world"""""",True,#do.diddle,#do.something.cool(""a#sdf"",1))")("Children").Count
Function CompileToAST(formula As String) As Object
  'formula as byte array
  Dim sFormula() As Byte
  sFormula = formula
  
  'Upper bound of array
  Dim iFormulaLen As Long
  iFormulaLen = Len(formula)
  
  'If Formula is blank then exit the function
  If iFormulaLen = 0 Then
    Exit Function
  End If
  
  'Create an Abstract syntax tree to store compilation structure
  Dim AST As Object
  Set AST = CreateCompiledPart("AST")
  
  'Temporary compiled part for use
  Dim TmpCompiledPart As Object
  
  'Test for formula is guaranteed literal
  If InStr(1, formula, "#") = 0 Then
    AST("Children").Add CreateLiteralPart(formula, AST)
    Set CompileToAST = AST
    Exit Function
  End If
  
  'Constants used for Compiling fast
  Dim iHashChar As Integer: iHashChar = Asc("#")
  Dim iQuoteChar As Integer: iQuoteChar = Asc("""")
  Dim iBracketCharO As Integer: iBracketCharO = Asc("(")
  Dim iBracketCharC As Integer: iBracketCharC = Asc(")")
  Dim iCommaChar As Integer: iCommaChar = Asc(",")
  
  'Keeping track of parts
  Dim sLiteral As String
  Dim iBracketScope As Integer
  
  'Loop through string
  Dim iChar As Long, char As Integer
  Dim bIsVBAExpression As Boolean
  For i = 1 To iFormulaLen
    'Get char position and bytes
    iChar = (i - 1) * 2
    char = sFormula(iChar)
    
    'Detect quotes
    If char = iQuoteChar Then
      If bString Then
        'If next char is also iQuoteChar, append and skip 2 chars
        If iChar + 2 < iFormulaLen * 2 Then
          If sFormula(iChar + 2) = iQuoteChar Then
            sLiteral = sLiteral & """"""
            i = i + 1
            GoTo NextChar
          Else
            'In this case we need to end the string:
            bString = False
            sLiteral = sLiteral & """"
            AST("Children").Add CreateLiteralPart(sLiteral, AST)
            sLiteral = ""
          End If
        Else
          bString = False
          sLiteral = sLiteral & """"
          AST("Children").Add CreateLiteralPart(sLiteral, AST)
          sLiteral = ""
        End If
        GoTo NextChar
      Else
        'Append existing sLiteral if exists
        If sLiteral <> "" Then
          AST("Children").Add CreateLiteralPart(sLiteral, AST)
        End If
        
        'Begin sLiteral
        bString = True
        sLiteral = """"
        GoTo NextChar
      End If
    End If
    
    'If is string then...
    If bString Then
      sLiteral = sLiteral & Chr(char)
      GoTo NextChar
    End If
    
    Dim j As Integer
    If char = iHashChar Then
      'Append existing sLiteral if exists
      If sLiteral <> "" Then
        AST("Children").Add CreateLiteralPart(sLiteral, AST)
        sLiteral = ""
      End If
      
      'Capture 0 depth VBA expressions
      For j = i + 1 To iFormulaLen
        iChar = (j - 1) * 2
        char = sFormula(iChar)
        If Not bString Or char = iQuoteChar Then
          'If this char is not a vba char and ibracket scope is 0 then complete expression
          If Not isVbaChar(char) And iBracketScope = 0 Then
            GoTo VBAExpressionEnd
          End If
          
          Select Case char
            Case iQuoteChar
              If bString Then
                If iChar + 2 < iFormulaLen * 2 Then
                  If (sFormula(iChar + 2) = iQuoteChar) Then
                    j = j + 1
                  Else
                    bString = False
                  End If
                End If
              Else
                bString = True
              End If
            Case iBracketCharO
              iBracketScope = iBracketScope + 1
            Case iBracketCharC
              'If already out of scope, end expression.
              If iBracketScope = 0 Then GoTo VBAExpressionEnd
              
              'Else continue
              iBracketScope = iBracketScope - 1
            Case iCommaChar
              'If already out of scope, end expression.
              If iBracketScope = 0 Then GoTo VBAExpressionEnd
          End Select
        End If
      Next
      
VBAExpressionEnd:
      AST("Children").Add CreateMacroPart(Mid(formula, i, j - i))
      i = j
    End If
    
    'If nothing else, append literal
    sLiteral = sLiteral & Chr(char)
NextChar:
  Next
  
  'Final literal part
  If sLiteral <> "" Then
    AST("Children").Add CreateLiteralPart(sLiteral, AST)
  End If
  
  'Optimise and return AST
  Set CompileToAST = OptimiseAST(AST)
End Function

Private Sub Class_Initialize()
  Set RegisteredObjects = CreateObject("Scripting.Dictionary")
End Sub
Friend Sub init(Optional formula As String, Optional RegisteredObjects As Object)
  If pInitialised Then
    Err.Raise 1, "VBAExpression::Init", "Cannot initialise initialised object"
  Else
    pFormula = formula
    isCompiled = False
    If Not RegisteredObjects Is Nothing Then Set Me.RegisteredObjects = RegisteredObjects
    pInitialised = True
  End If
End Sub

Private Function CreateCompiledPart(TypeName As String) As Object
  Set NewCompiledPart = CreateObject("Scripting.Dictionary")
  NewCompiledPart("Type") = TypeName
  Set NewCompiledPart("Children") = New Collection
  Set CreateCompiledPart = NewCompiledPart
End Function

Private Function CreateLiteralPart(value As String, Parent As Object) As Object
  'Create literal part
  Dim TmpCompiledPart As Object
  Set TmpCompiledPart = CreateCompiledPart("Literal")
  Set TmpCompiledPart("Parent") = Parent
  TmpCompiledPart("Value") = value
  
  'Return Literal
  Set CreateLiteralPart = TmpCompiledPart
End Function


Private Function CreateMacroPart(sToCompile As String) As Object
  'Macro part to return
  Dim MacroPart As Object
  Set MacroPart = CreateCompiledPart("Macro")
  
  'Parse VBA:
  '=======================
  'Split based on 0 depth "."
  Dim iLen As Long: iLen = Len(sToCompile)
  
  Dim char As String
  Dim iScope As Long
  Dim bString As Boolean
  Dim i As Integer
  Dim splitLoc As Long: splitLoc = 1
  Dim iPath As Integer: iPath = 0
  
  Dim parts() As String
  For i = 1 To iLen
    char = Mid(sToCompile, i, 1)
    If Not bString Or char = """" Then
      Select Case char
        Case "("
          iScope = iScope + 1
        Case ")"
          iScope = iScope - 1
          If iScope = -1 Then
            'ERROR - Syntax error!
            Err.Raise 1, "VBAExpression::CreateMacroPart", "SYNTAX ERROR - Found Closing bracket "")"" out of scope"
          End If
        Case "."
          If iScope = 0 Then
            'Make parts array...
            ReDim Preserve parts(0 To iPath)
            parts(iPath) = Mid(sToCompile, splitLoc, i - splitLoc)
            
            'Make parts array...
            iPath = iPath + 1
            splitLoc = i + 1
          End If
        Case """"
          If bString Then
            If Mid(sToCompile, i + 1, 1) = """" Then
              i = i + 1
            Else
              bString = False
            End If
          Else
            bString = True
          End If
      End Select
    End If
  Next
  
  If splitLoc < iLen Then
    ReDim Preserve parts(0 To iPath)
    parts(iPath) = Mid(sToCompile, splitLoc, iLen - splitLoc + 1)
  End If
  
  'First part is entry point
  MacroPart("Children").Add CreateEntryPointPart(Mid(parts(0), 2), MacroPart)
  
  'All other parts will be getters and will occasionally have parameters
  iLen = UBound(parts) - LBound(parts) + 1
  If iLen > 1 Then
    For i = 1 To iLen - 1
      MacroPart("Children").Add CreateGetterPart(parts(i), MacroPart)
    Next
  End If
  
  'Return macro part
  Set CreateMacroPart = MacroPart
End Function

Function CreateEntryPointPart(Identifier As String, ByRef Parent As Object) As Object
  'Create literal part
  Dim TmpCompiledPart As Object
  Set TmpCompiledPart = CreateCompiledPart("EntryPoint")
  Set TmpCompiledPart("Parent") = Parent
  TmpCompiledPart("Value") = Identifier
  
  'Return Literal
  Set CreateEntryPointPart = TmpCompiledPart
End Function

'Create getter:
'For #___.something
'  {Type:"Getter", Value:"something", Params:[]}
'
'For #___.cool("a#sdf",1)
'  {Type:"Getter", Value:"cool", Params:[
'    {Type:"Literal", Value:"\"a#sdf\",1"}
'  ]}
Function CreateGetterPart(Identifier As String, ByRef Parent As Object) As Object
  'Create literal part
  Dim TmpCompiledPart As Object
  Set TmpCompiledPart = CreateCompiledPart("Getter")
  Set TmpCompiledPart("Parent") = Parent
  
  Dim iBracketLocation As Long: iBracketLocation = InStr(1, Identifier, "(")
  
  If iBracketLocation = 0 Then iBracketLocation = Len(Identifier) + 1
  TmpCompiledPart("Value") = Mid(Identifier, 1, iBracketLocation - 1)
  
  'Get parameters if they exist
  Set TmpCompiledPart("Params") = New Collection
  
  Dim sParams As String
  sParams = Mid(Identifier, iBracketLocation)
  
  'Handle params
  If (sParams <> "") Then
    'Remove brackets
    sParams = Mid(sParams, 2, Len(sParams) - 2)
    
    'Compile params
    Dim oAST As Object, oHandle As Object
    Set oAST = CompileToAST(sParams)
    
    'Loop over compiled params
    For Each oHandle In oAST("Children")
      TmpCompiledPart("Params").Add oHandle
    Next
  End If
  
  'Return Literal
  Set CreateGetterPart = TmpCompiledPart
End Function

Private Function OptimiseAST(AST As Object) As Object
  'TODO: CompressAST by Joining neighbouring literals
  Set OptimiseAST = AST
End Function

'
'Converts AST for Macros to string expressions using VBAExpressionEx module
'
'E.G.
'    #myRange.Find("*").Address
'  -->
'    {Type:"Macro",  Children:[
'      {Type:"EntryPoint", Value:"myRange"},
'      {Type:"Getter", Value:"Find", Params:[
'        {Type:"Literal",Value:"*"}
'      ]},
'      {Type:"Getter", Value:"Address", Params:[]}
'    ]},
'  -->
'    guid = VBAExpressionEx.addVar(RegisteredValues("myRange"))
'    VBAExpressionEx.getChild(VBAExpressionEx.getChild(VBAExpressionEx.getVar("<<guid>>"),"Find","*"),"address")
Public Function SerialiseMacro(macro As Object) As String
  'Loop over macro's children
  Dim transpiled As String, child As Object
  For Each child In macro("Children")
    'If child is entry point then add to VBAExpressionEx variables and use a getVar expression
    If child("Type") = "EntryPoint" Then
      Dim guid As String
      guid = VBAExpressionEx.addVar(RegisteredObjects(child("Value")))
      transpiled = "VBAExpressionEx.getVar(""" & guid & """)"
    'If child is getter then use getChild.
    ElseIf child("Type") = "Getter" Then
      transpiled = "VBAExpressionEx.getChild(" & transpiled & ",""" & child("Value") & """" & SerialiseParams(child("Params")) & ")"
    End If
  Next
  
  SerialiseMacro = transpiled
End Function

Public Function SerialiseParams(params As Collection) As String
  Dim param As Object
  Dim sParams As String
  For Each param In params
    If param("Type") = "Literal" Then
      sParams = sParams & "," & param("Value")
    ElseIf param("Type") = "Macro" Then
      sParams = sParams & "," & SerialiseParams(param)
    End If
  Next
  SerialiseParams = sParams
End Function

Private Function isVbaChar(id As Integer) As Boolean
  isVbaChar = (id >= 48 And id < 57) Or (id >= 65 And id <= 90) Or id = 46 Or (id >= 97 And id <= 122) Or id = 40
End Function
