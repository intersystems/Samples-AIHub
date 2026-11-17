Include %AI

/// Dynamic tool discovery from compiled class queries.
///
/// Scans one or more IRIS classes for SqlProc class queries and makes each one
/// callable as an agent tool -- without any compile-time registration.
/// Demonstrates both halves of %AI.Policy.Discovery:
///
///   %Resolve  -- query %Dictionary.CompiledQuery for all metadata in one pass,
///                build tool specs from FormalSpec (parameters) and ResultSetReturnsSchema,
///                reusing %AI.Tool.Schema and %AI.Tools.SQL helpers
///   %Execute  -- dispatch to %PrepareClassQuery + %Execute via variadic args,
///                then format results via %AI.Tools.SQL.FormatResultSet
///
/// Usage:
///   Set policy = ##class(Sample.AI.Policies.ClassQueryDiscovery).%New(
///       "Sample.AI.Orders.Order,Sample.AI.Orders.Product")
///   Do agent.ToolManager.SetDiscoveryPolicy(policy)
///
/// Tool names are prefixed with the last class-name segment, e.g.:
///   Sample.AI.Orders.Order + SearchByStatus -> Order_SearchByStatus
///
Class Sample.AI.Policies.ClassQueryDiscovery Extends %AI.Policy.Discovery
{

/// Comma-separated list of fully-qualified class names to scan.
Property Classes As %String(MAXLEN = "");

/// Maximum rows returned per query call.
Property MaxRows As %Integer [ InitialExpression = 100 ];

/// Internal dispatch table: toolname -> {class, query, params}
/// params is a $LIST of parameter names in declaration order.
Property ToolMap As %DynamicObject [ Internal ];

Method %OnNew(classes As %String, maxRows As %Integer = 100) As %Status [ Internal ]
{
    Set ..Classes = classes
    Set ..MaxRows = maxRows
    Set ..ToolMap = {}
    Return $$$OK
}

// ---------------------------------------------------------------------------
// %Resolve
// ---------------------------------------------------------------------------

Method %Resolve(catalog As %DynamicArray) As %Status
{
    Set ..ToolMap = {}
    For i = 1:1:$LENGTH(..Classes, ",") {
        Set cls = $ZSTRIP($PIECE(..Classes, ",", i), "<>W")
        If cls = "" Continue
        $$$ThrowOnError(..ResolveClass(cls, catalog))
    }
    Return $$$OK
}

Method ResolveClass(cls As %String, catalog As %DynamicArray) As %Status [ Internal, Private ]
{
    Set prefix = $PIECE(cls, ".", *)  // last segment used as tool-name prefix

    // Single query fetches all metadata needed for the tool spec and dispatch table.
    // SqlRowSpec is not used directly -- return shape comes from ResultSetReturnsSchema().
    Set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name, Description, FormalSpec " _
        "FROM %Dictionary.CompiledQuery " _
        "WHERE parent->ID = ? AND SqlProc = 1 AND Deprecated = 0 " _
        "ORDER BY Name",
        cls)
    If rs.%SQLCODE < 0 {
        Return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    }

    While rs.%Next() {
        Set qname      = rs.%Get("Name")
        Set desc       = rs.%Get("Description")
        Set formalspec = rs.%Get("FormalSpec")

        If desc = "" Set desc = "Execute " _ cls _ " query " _ qname _ "."

        // Parse the FormalSpec into a local array; ParseFormalSpec kills parsedArgs first
        $$$ThrowOnError(..ParseFormalSpec(qname, formalspec, .parsedArgs))

        // Build parameter JSON Schema and record name order for dispatch
        Set paramschema = {"type": "object", "properties": {}, "required": []}
        Set paramorder  = ""
        For i = 1:1:parsedArgs {
            Set argname = parsedArgs(i)
            Set argtype = $GET(parsedArgs(i, 2), "%String")
            Set argdesc = ##class(%Global).Unquote($GET(parsedArgs(i, 2, "DESCRIPTION")))

            Set sc = ##class(%AI.Tool.Schema).%ElementSchema(argtype, .propschema)
            If $$$ISERR(sc) Set propschema = {"type": "string"}
            If argdesc '= "" Set propschema.description = argdesc

            Do paramschema.properties.%Set(argname, propschema)
            If '$DATA(parsedArgs(i, 3)) Do paramschema.required.%Push(argname)
            Set paramorder = paramorder _ $LB(argname)
        }

        Set toolname = prefix _ "_" _ qname

        Do catalog.%Push({
            "name":        (toolname),
            "description": (desc),
            "source":      "iris",
            "parameters":  (paramschema),
            "returns":     (##class(%AI.Tools.SQL).ResultSetReturnsSchema()),
            "metadata":    {"kind": "query", "provider": "ClassQueryDiscovery"}
        })

        Do ..ToolMap.%Set(toolname, {
            "class":  (cls),
            "query":  (qname),
            "params": (paramorder)
        })
    }
    If rs.%SQLCODE < 0 {
        Return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    }
    Return $$$OK
}

/// Parse a compiled query FormalSpec string into a local array of argument
/// descriptors. FormalSpec's grammar (from %Dictionary.CompiledQuery) is
/// "name[:type[(params)]][=default]" comma-separated, e.g.
/// `Pattern:%String="",ClassType:%String=""`. Hand-rolled with SplitTopLevel/
/// FindTopLevel below rather than reaching into the IRIS compiler's own
/// internal formal-spec parser -- that's not a stable public API across
/// versions (confirmed: the tag this used to call no longer exists).
///
/// After the call, parsedArgs contains:
///   parsedArgs       = total number of arguments
///   parsedArgs(i)    = argument name
///   parsedArgs(i, 2) = IRIS type (e.g. "%String", "%Integer") -- any
///                      parenthesized type-parameter list is stripped
///   parsedArgs(i, 2, "DESCRIPTION") = DESCRIPTION type-parameter value if present
///   parsedArgs(i, 3) = default value (key absent = no default = required)
ClassMethod ParseFormalSpec(queryName As %String, formalSpec As %String, Output parsedArgs) As %Status [ Internal, Private ]
{
    Kill parsedArgs
    Set parsedArgs = 0
    Try {
        Set params = ..SplitTopLevel(formalSpec, ",")
        For i=1:1:$LISTLENGTH(params) {
            Set param = $ZSTRIP($LISTGET(params, i), "<>W")
            Continue:param=""

            // Split off "=default" at the first top-level "=".
            Set eqPos = ..FindTopLevel(param, "=")
            Set hasDefault = (eqPos > 0)
            Set nameType = $SELECT(hasDefault: $EXTRACT(param, 1, eqPos-1), 1: param)
            Set default  = $SELECT(hasDefault: $EXTRACT(param, eqPos+1, *), 1: "")

            // Split "name:type" at the first ":".
            Set colonPos = $FIND(nameType, ":")
            Set argname = $SELECT(colonPos>0: $EXTRACT(nameType, 1, colonPos-2), 1: nameType)
            Set argtype = $SELECT(colonPos>0: $EXTRACT(nameType, colonPos, *), 1: "")

            Set parsedArgs = parsedArgs + 1
            Set parsedArgs(parsedArgs) = argname

            // Strip a parenthesized type-parameter list, extracting DESCRIPTION if present.
            Set parenPos = $FIND(argtype, "(")
            If parenPos > 0 {
                Set typeParams = $EXTRACT(argtype, parenPos, $LENGTH(argtype)-1)
                Set argtype = $EXTRACT(argtype, 1, parenPos-2)
                Set descMatch = ##class(%Regex.Matcher).%New("DESCRIPTION\s*=\s*""([^""]*)""", typeParams)
                If descMatch.Locate() {
                    Set parsedArgs(parsedArgs, 2, "DESCRIPTION") = descMatch.Group(1)
                }
            }
            Set parsedArgs(parsedArgs, 2) = argtype
            If hasDefault Set parsedArgs(parsedArgs, 3) = default
        }
    } Catch ex {
        Return ex.AsStatus()
    }
    Return $$$OK
}

/// Split str on every top-level occurrence of delim -- one not nested inside
/// "..." quotes or (...) parens -- returning a $LIST of the pieces. Needed
/// because a default value or type-parameter list can itself contain delim.
ClassMethod SplitTopLevel(str As %String, delim As %String) As %List [ Internal, Private ]
{
    Set result = "", depth = 0, inQuote = 0, start = 1
    Set len = $LENGTH(str)
    For i=1:1:len {
        Set ch = $EXTRACT(str, i)
        If inQuote {
            If ch = """" Set inQuote = 0
        } ElseIf ch = """" {
            Set inQuote = 1
        } ElseIf ch = "(" {
            Set depth = depth + 1
        } ElseIf ch = ")" {
            Set depth = depth - 1
        } ElseIf (ch = delim) && (depth = 0) {
            Set result = result _ $LISTBUILD($EXTRACT(str, start, i-1))
            Set start = i + 1
        }
    }
    Return result _ $LISTBUILD($EXTRACT(str, start, len))
}

/// Find the first top-level occurrence of ch in str (not nested inside
/// "..." quotes or (...) parens), or 0 if none. Same nesting rules as
/// SplitTopLevel.
ClassMethod FindTopLevel(str As %String, ch As %String) As %Integer [ Internal, Private ]
{
    Set depth = 0, inQuote = 0
    Set len = $LENGTH(str)
    For i=1:1:len {
        Set c = $EXTRACT(str, i)
        If inQuote {
            If c = """" Set inQuote = 0
        } ElseIf c = """" {
            Set inQuote = 1
        } ElseIf c = "(" {
            Set depth = depth + 1
        } ElseIf c = ")" {
            Set depth = depth - 1
        } ElseIf (c = ch) && (depth = 0) {
            Return i
        }
    }
    Return 0
}

// ---------------------------------------------------------------------------
// %Execute
// ---------------------------------------------------------------------------

Method %Execute(toolName As %String, args As %DynamicObject) As %DynamicObject
{
    Set entry = ..ToolMap.%Get(toolName)
    If '$ISOBJECT(entry) Return $$$NULLOREF  // not our tool

    Set cls    = entry.class
    Set qname  = entry.query
    Set porder = entry.params  // $LIST of parameter names in declaration order

    Set stmt = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(stmt.%PrepareClassQuery(cls, qname))

    // Build positional args in formalspec order then spread into %Execute.
    // callArgs = 0 ensures zero-parameter queries dispatch correctly.
    Kill callArgs
    Set callArgs = 0
    For i = 1:1:$LL(porder) {
        Set callArgs($I(callArgs)) = args.%Get($LG(porder, i))
    }

    Set t0 = $zh
    // %SQLCODE on the result is checked inside FormatResultSet (returns error object on failure)
    Set rs = stmt.%Execute(callArgs...)

    Return ##class(%AI.Tools.SQL).FormatResultSet(rs, ..MaxRows, t0)
}

}