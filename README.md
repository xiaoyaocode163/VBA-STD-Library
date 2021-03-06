# VBA-STD-Library

A Collection of libraries to form a common standard layer for modern VBA applications.

## Motivation

VBA first appeared in 1993 (over 25 years ago) and the language's age is definitely noticable. VBA has a lot of specific libraries for controlling Word, Excel, Powerpoint etc. However the language massively lacks in generic modern libraries for accomplishing common programming tasks. VBA projects ultimately become a mish mash of many different technologies and programming styles. Commonly for me that means calls to Win32 DLLs, COM libraries via late-binding, calls to command line applications and calls to .NET assemblies.

Over time I have been building my own libraries and have gradually built my own layer above the simple VBA APIs.

The VBA Standard Library aims to give users a set of common libraries, maintained by the community, which aid in the building of VBA Applications.

## Road map

Progress on this project is likely to be slow, as this is community led and currently maintained by very few contributers. As implementation usually follows interest, the following list of classes are likely to be worked on at different rates, and all in parallel instead of in a particular order.

* Finish off core WIP classes (e.g. `Date`, `Debug`, `Regex`).
* Create a callable expression language / lambda syntax for VBA.
* Other core classes need implementing (e.g. `String`, `Math`, `COM`, `Pointer`, `Dictionary`, `VBR`, `Kernel`, `Windows`, `FileSystem` ...)
* Can start to implement `JSON`, `HTTP`, `XML`, `OXML`, `Zip` etc ... now.
* Runtimes! `CLR`, `Powershell`, `JavaScript`,`SerialisedVBA`
* Threading
* Events

## Planned Global Objects:

| Status | VBType |Type       |Name             | Description  |
|--------|--------|-----------|-----------------|--------------|
| HOLD   | Class  |File       |stdFileSystem    | A wrapper around Shell's and FSO's file system APIs.
| HOLD   | Class  |File       |stdZip           | A wrapper around shell's Zip functionality.
| HOLD   | Class  |Debug      |stdDebug         | A wrapper around `Debug` while adding new options like styling messages and printing to an external html console.
| READY  | Class  |Debug      |stdError         | Better error handling, including stack trace and error handling diversion and events.
| WIP    | Class  |Data       |stdJSON          | [Tim Hall's fantastic JSON library](https://github.com/VBA-tools/VBA-JSON)
| HOLD   | Class  |Data       |stdHTTP          | A wrapper around HTTP COM libraries.
| HOLD   | Class  |Data       |stdOXML          | A library to assist in the modification of Office documents via Open XML format.
| READY  | Class  |Type       |stdArray         | A library designed to re-create the Javascript dynamic array object.
| WIP    | Class  |Type       |stdDictionary    | A drop in replacement for VBScript's dictionary.
| READY  | Class  |Type       |stdDate          | A standard date parsing library. No more will you have to rely on Excel's interpreter. State the format, get the data.
| READY  | Class  |Type       |stdRegex         | A wrapper around `VBScript.RegExp` but with more features e.g. named capture groups and free-spaces.
| READY  | Class  |Type       |stdStringBuilder | A better way of creating large strings.
| UNK    | Module |Type       |stdIniVariantEnum| Initialising [IEnumVARIANT](http://www.vbforums.com/showthread.php?854963-VB6-IEnumVARIANT-For-Each-support-without-a-typelib) by recreating vtable. Used to overcome pitfalls of VB collections. Alternatively will implement an IFxEnumVariant interface
| WIP    | Class  |Runtimes   |stdCLR           | Host CLR (Common Language Runtime). Allows execution of C#.NET and VB.NET scripts in-process.
| WIP    | Class  |Runtimes   |stdPowershell    | Host [Powershell](https://docs.microsoft.com/en-us/powershell/developer/hosting/windows-powershell-host-quickstart)
| WIP    | Class  |Runtimes   |stdJavaScript    | Host [Edge and IE Javascript engine](https://docs.microsoft.com/en-us/microsoft-edge/hosting/chakra-hosting/hosting-the-javascript-runtime). [IE11 Hosting](https://docs.microsoft.com/en-us/microsoft-edge/hosting/chakra-hosting/targeting-edge-vs-legacy-engines-in-jsrt-apis)
| WIP    | Class  |Runtimes   |stdJSBridge      | A VbaJsBridge module allowing applications to open and close programmatic access to VBA from OfficeJS.
| UNK    | Class  |Runtimes   |stdVBR           | [Hidden functions from VB VirtualMachine library](http://www.freevbcode.com/ShowCode.asp?ID=7520)
| UNK    | Class  |Runtimes   |stdSerialisedVBA | Custom engine for executing VBA from a serialised JSON string.
| UNK    | Class  |Runtimes   |stdExecLib       | Execute external applications in-memory. [src](https://github.com/itm4n/VBA-RunPE)
| WIP    | Class  |Automation |stdCOM           | Low level COM APIs.
| WIP    | Class  |Automation |stdAccessibility | Use Microsoft Active Accessibility framework within VBA - Very useful for automation.
| WIP    | Class  |Automation |stdWindows       | Standard functions for handling Windows
| WIP    | Class  |Automation |stdKernel        | Low level but useful APIs. Won't be loading Kernel32.dll entirely, but will try to expose static methods to common useful functions.
| WIP    | Class  |Processing |stdThread        | Multithreading in VBA? [src](http://www.freevbcode.com/ShowCode.asp?ID=1287#A%20Quick%20Review%20Of%20Multithreading)
| WIP    | Class | Application | stdEvents | More events for VBA.

## Structure

All modules or classes will be prefixed by `std`.

Commonly implementations will be of classes which are factory classes. E.G:

```vb
Class stdRegex
  private p_pattern as string
  private p_flags as string
  '...
  
  'Creates a regex object given a pattern and flags.
  '@constructor
  '
  '@param {string}  Pattern - The pattern to match
  '@param {string}  Flags - Optional flags to apply
  '@return {stdRegex} Regular expression object
  '@example
  '    stdRegex.Create("A\d+","i")
  Public Function Create(ByVal pattern As String, Optional ByVal flags As String = "") As stdRegex
    If Not Me Is stdRegex Then
      stdError.Raise ("Constructor called on object not class")
      Exit Function
    End If
    
    Set Create = New stdRegex
    Call Create.init(pattern, flags)
  End Function

  'Initialises the class from within the static superclass. This method is meant for internal use only. Use at your own risk.
  '@protected
  '
  '@param {string}  Pattern - The pattern to match
  '@param {string}  Flags - Optional flags to apply
  '@example
  '    obj.init("A\d+","i")
  Friend Sub init(ByVal pattern As String, ByVal flags As String)
    If Me Is stdRegex Then
      stdError.Raise ("Cannot run init on class")
      Exit Sub
    End If
    
    p_pattern = pattern
    p_flags = flags
    '...
  End Sub
  '..
End Class
```

With the above example, the Regex class is constructed with the `Create()` method, which can only be called on the `stdRegex` static class. We will try to keep this structure across all STD VBA classes.

# Contributing

If you are looking to contribute to the VBA standard library codebase, the best place to start is the [GitHub "issues" tab](https://github.com/sancarn/VBA-STD-Library/issues). This is also a great place for filing bug reports and making suggestions for ways in which we can improve the code and documentation. A list of options of different ways to contribute are listed below:

* If you have a Feature Request - Create a new issue
* If you have found a bug - Create a new issue
* If you have written some code which you want to contribute see the Contributing Code section below.

## Contributing Code

There are several ways to contribute code to the project:

* Opening pull requests is the easiest way to get code intergrated with the standard library.
* Create a new issue and providing the code in a code block - Bare in mind, it will take us a lot longer to pick this up than a standard pull request.

Please make sure code contributions follow the following guidelines:

* `stdMyClass.cls` should have `Attribute VB_PredeclaredId = True`. 
* `Attribute VB_Name` should follow the STD convention e.g. `"stdMyClass"`
* Follow the STD constructor convention `stdMyClass.Create(...)`.
* Ensure there are plenty of comments where required.
* Ensure lines end in `\r\n` and not `\n` only.

As long as these standard conventions are met, the rest is up to you! Just try to be as general as possible! We're not necessarily looking for optimised code, at the moment we're just looking for code that works!

> Note: Ensure that all code is written by you. If the code is not written by you, you will be responsible for any repercussions!

## Inspiration documents

Inspiration was initially stored in this repository, however the vast swathes of examples, knowledge and data became too big for this repository, therefore it was moved to:

https://github.com/sancarn/VBA-STD-Lib-Inspiration
