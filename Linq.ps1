using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Linq
using namespace System.Management.Automation
using namespace System.Reflection



# $o1 = [pscustomobject]@{a=1;b=2}
# $o2 = [pscustomobject]@{a=3;b=4}
# $ox = @($o1,$o2)
# $psox = [List[psobject]]::new([psobject[]]$ox)
# $l = [Linq99]::new($psox)


# https://gist.github.com/Jaykul/dfc355598e0f233c8c7f288295f7bb56
class _Linq99 : IEnumerable
{
    hidden [IEnumerable]$_collection

    _Linq99 ()
    {
        $this._collection = [List[PSObject]]::new()
    }

    _Linq99 ([IEnumerable]$Collection)
    {
        $this._collection = $Collection
    }

    [IEnumerator] GetEnumerator()
    {
        return [_Linq99Enumerator]::new($this._collection)
    }
}


class Linq99 : _Linq99, IEnumerable[PSObject]
{
    hidden static [Collections.Generic.IDictionary[string, MethodInfo[]]] $_extMethods

    static Linq99 ()
    {
        [Linq99]::_extMethods = [Collections.Generic.Dictionary[string, MethodInfo[]]]::new()

        [Linq.Enumerable].GetMethods('Public,Static') |
            Group-Object Name |
            ForEach-Object {[Linq99]::_extMethods.Add($_.Name, $_.Group)}
    }


    hidden [IEnumerable[PSObject]]$_collection

    Linq99 ()
    {
        $this._collection = [List[PSObject]]::new()
        $this.AddMethods()
    }

    Linq99 ([IEnumerable[PSObject]]$Collection)
    {
        $this._collection = $Collection
        $this.AddMethods()
    }

    [void] AddMethods ()
    {
        foreach ($MethodName in [Linq99]::_extMethods.Keys)
        {
            $this | Add-Member ScriptMethod $MethodName {
                [Linq99]::_extMethods[$MethodName] | ft
            } -Force
        }
    }

    [IEnumerator[PSObject]] GetEnumerator()
    {
        return [Linq99Enumerator]::new($this._collection)
    }
}






class _Linq99Enumerator : IEnumerator
{
    hidden [IEnumerator] $_enumerator

    _Linq99Enumerator () {}

    _Linq99Enumerator ([IEnumerable[PSObject]] $Collection)
    {
        $this._enumerator = $Collection.GetEnumerator()
    }

    [object] get_Current()
    {
        return $this._enumerator.Current
    }

    [bool] MoveNext()
    {
        return $this._enumerator.MoveNext()
    }

    [void] Reset()
    {
        $this._enumerator.Reset()
    }
}


class Linq99Enumerator : _Linq99Enumerator, IEnumerator[PSObject]
{
    hidden [IEnumerator[PSObject]] $_enumerator

    Linq99Enumerator ([IEnumerable[PSObject]] $Collection)
    {
        $this._enumerator = $Collection.GetEnumerator()
    }

    [PSObject] get_Current()
    {
        return $this._enumerator.Current
    }

    [void] Dispose() {}
}