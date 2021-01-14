using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Linq
using namespace System.Management.Automation


# https://gist.github.com/Jaykul/dfc355598e0f233c8c7f288295f7bb56
class _Linq99 : IEnumerable
{
    hidden [IEnumerable[PSObject]]$_collection

    Linq99 ()
    {
        $this._collection = [List[PSObject]]::new()
    }

    Linq99 ([IEnumerable[PSObject]]$Collection)
    {
        $this._collection = $Collection
    }

    [IEnumerator[PSObject]] GetEnumerator()
    {
        return $this._collection.GetEnumerator()
    }
}

class Linq99 : IEnumerable[PSObject]
{
    hidden [IEnumerable[PSObject]]$_collection

    Linq99 ()
    {
        $this._collection = [List[PSObject]]::new()
    }

    Linq99 ([IEnumerable[PSObject]]$Collection)
    {
        $this._collection = $Collection
    }

    [IEnumerator[PSObject]] GetEnumerator()
    {
        return $this._collection.GetEnumerator()
    }
}

class _Linq99Enumerator : IEnumerator
{
    hidden [PSObject] $_enumerator

    _Linq99Enumerator ([IEnumerable[PSObject]] $Collection)
    {
        $this._enumerator = $Collection.GetEnumerator()
    }

    [PSObject] get_Current()
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

}