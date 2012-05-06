# library.awk

# globals EXITCODE, MISSING


# if you call die, assert, or check*: start END blocks with
#    { if (EXITCODE) exit EXITCODE; ... }
function die(msg) {
    EXITCODE=1
    printf("%s: %s\n", ARGV[0], msg) > "/dev/stderr"
    exit EXITCODE
}


function assert(test, msg) {
    if (!test) die(msg ? msg : "assertion failed")
}


# missing values are only isnull(), isnum(), iszero(), isint(), isnat() when a true second arg is supplied
# "" values (even if set from command-line) are only isnull()
# 0 and "0" values are isnum(), iszero(), isint(), isnat(), but other values coercable to 0 aren't
# floats are isnum() but not ispos(), isneg()


# unitialized scalar
function ismissing(u) {
    return u == 0 && u == ""
}


function check(u, missing) {
    if (u == 0 && u == "") {
        MISSING = 1
        return missing
    }
    MISSING = 0
    return u
}

# explicit ""
function isnull(s, u) {
    if (u) return s == "" # accept missing as well
    return !s && s != 0
}


function isnum(n, u) {
    # return n ~ /^[+-]?[0-9]+$/
    if (u) return n == n +0 # accept missing as well
    return n "" == n +0 
    # NOTE: awk will also convert when there's leading space/trailing anything
    #       and will convert any other non-numeric to 0
}


# returns num or missing, else die(msg)
function checknum(n, missing, msg) {
    if (n "" == n + 0) {
        MISSING = 0
        return n # explicit numbers are preserved
    } else if (msg && n != n + 0) die(msg)
    MISSING = 1
    return missing
}


# explicit 0 or "0"
function iszero(n, u) {
    # return n + 0 == 0 # accept any coercable
    if (u) return n == 0 # accept missing as well
    return n == 0 && n != ""
}


function isint(n, u) {
    if (u) return int(n) == n # accept missing as well
    return int(n) == n && n != ""
}


# explicit isnum >= 0
function isnat(n, u) {
    if (u) return int(n) == n && n >= 0 # accept missing as well
    return int(n) == n && n "" >= 0
}


# returns nat or missing, else die(msg)
function checknat(n, missing, msg) {
    if (int(n) == n) {
        if (n "" >= 0) {
            MISSING = 0
            return n # explicit numbers are preserved
        } else if (msg && n < 0) die(msg)
    } else if (msg) die(msg)
    MISSING = 1
    return missing
}


# explicit isnum > 0
function ispos(n) {
    # return n "" == n +0 && n > 0 # accept float as well
    return int(n) == n && n > 0
}


# returns pos or missing, else die(msg)
function checkpos(n, missing, msg) {
    if (int(n) == n) {
        if (n "" > 0) {
            MISSING = 0
            return n # explicit numbers are preserved
        } else if (msg && (n < 0 || n "" >=  0)) die(msg)
    } else if (msg) die(msg)
    MISSING = 1
    return missing
}


function isneg(n) {
    # return n "" == n +0 && n < 0 # accept float as well
    return int(n) == n && n < 0
}



## numeric utils #########

# might as well inline
function max(m, n) { return (m > n) ? m : n }


# might as well inline
function min(m, n) { return (m < n) ? m : n }


# return k=1 distinct random elements A[1 <= i <= n], separated by SUBSEP
function choose(n,  k,   A, i, r, p) {
    k = checkpos(k, 1, "choose: second argument must be positive")
    if (!isempty(A)) {
        # A is already populated, choose k elements from A[1]..A[n], ordered by index
        if (!n) {
            n = 1
            while (n in A) n++
            n--
        }
        p = r = ""
        for (i = 1; n > 0; i++)
            if (rand() < k/n--) {
                p = p r A[i]
                r = SUBSEP
                k--
            }
        return p
    }
    # else choose k integers from 1..n, ordered
    if (k == 1)
        return int(n*rand())+1
    for (i = n-k+1; i <= n; i++)
        ((r = int(i*rand())+1) in A) ? A[i] : A[r]
    p = r = ""
    for (i=1; i<=n; i++)
       if (i in A) {
            p = p r i
            r = SUBSEP
        }
    split("", A) # does it help to delete the aux array?
    return p
}


# random permutation of k=n integers between 1 and n
# the distribution of this isn't great, but it does cover the whole range of permutations
# a random deck is: split(permute(52,52), deck, SUBSEP)
function permute(n,  k,   i, r, p) {
    k = checkpos(k, n, "permute: second argument must be positive")
    p = SUBSEP
    for (i = n-k+1; i <= n; i++) {
        if (p ~ SUBSEP (r = int(i*rand())+1) SUBSEP)
            # since i is higher than before, p only contains r when r < i
            sub(SUBSEP r SUBSEP, SUBSEP r SUBSEP i SUBSEP, p)    # put i after r
        else p = SUBSEP r p                                      # put r at beginning
    }
    return substr(p, 2, length(p)-2)
}


# Shuffle an array with indexes from 1 to n. (Knuth or Fisher-Yates shuffle)
function shuffle(A, n,    i, j, t) {
    if (!n) {
        n = 1
        while (n in A) n++
        n--
    }
    for (i = n; i > 1; i--) {
            j = int(i * rand()) + 1 # random integer from 1 to i
            t = A[i]; A[i] = A[j]; A[j] = t # swap A[i], A[j]
    }
}


## array utils #########

function isempty(array,   i) {
    for (i in array) return 0
    return 1
}


# insertion sort A[1..n]
# stable, O(n^2) but fast for small arrays
function sort(A,n,   i,j,t) {
    if (!n) {
        n = 1
        while (n in A) n++
        n--
    }
    for (i = 2; i <= n; i++) {
        t = A[i]
        for (j = i; j > 1 && A[j-1] > t; j--)
            A[j] = A[j-1]
        A[j] = t
    }
}

# mergesort is stable, O(n log n) worst-case
# on arrays uses O(n) auxiliary space; but on linked lists only a small constant space
# implementation not provided here


# in-place quicksort A[left..right]
# for efficiency, left and right must be supplied, default values aren't calculated
# unstable
# on avg thought to be constantly better than heapsort, but has worst-case O(n^2)
# choose random pivot to avoid worst-case behavior on already-sorted arrays
# advantage over mergesort is that it only uses O(log n) auxiliary space (if we have tail-calls)
function qsort(A,left,right,   i,last,t) {
    if (left >= right)  # do nothing if array contains at most one element
        return
    i = left + int((right-left+1)*rand()) # choose pivot
    t = A[left]; A[left] = A[i]; A[i] = t # swap A[left] and A[i]
    last = left
    for (i = left+1; i <= right; i++)
        if (A[i] < A[left]) {
            ++last
            t = A[last]; A[last] = A[i]; A[i] = t # swap A[last] and A[i]
        }
    t = A[left]; A[left] = A[last]; A[last] = t # swap A[left] and A[last]
    qsort(A, left, last-1)
    qsort(A, last+1, right)
}


# heapsort
# also unstable, and unlike merge and quicksort it relies on random-access so has poorer cache performance
# advantage over quicksort is that its worst-case same as avg: O(n log n)
# this presentation based on http://dada.perl.it/shootout/heapsort.lua5.html
function hsort(A, n,   c, p, t, i) {
    if (!n) {
        n = 1
        while (n in A) n++
        n--
    }
    i = int(n/2) + 1
    while (1) {
        if (i > 1) {
            i--
            t = A[i]
        } else {
            t = A[n]
            A[n] = A[1]
            n--
            if (n == 1) {
                A[1] = t
                return
            }
        }
        for (p = i; (c = 2*p) <= n; p = c) {
            if ((c < n) && (A[c] < A[c+1]))
                c++
            if (t < A[c])
                A[p] = A[c]
            else break
        }
        A[p] = t
    }
}

# # one of the more usual presentations
# function hsort(A,n,  i,t) {
#     if (!n) {
#         n = 1
#         while (n in A) n++
#         n--
#     }
#     for (i = int(n/2); i >= 1; i--)
#         heapify(A, i, n)
#     for (i = n; i > 1; i--) {
#         t = A[1]; A[1] = A[i]; A[i] = t # swap A[1] and A[i]
#         heapify(A, 1, i-1)
#     }
# }
#
# function heapify(A,left,right,   p,c,t) {
#     for (p = left; (c = 2*p) <= right; p = c) {
#         if (c < right && A[c] < A[c+1])
#             c++
#         if (A[p] < A[c]) {
#             t = A[c]; A[c] = A[p]; A[p] = t # swap A[c] and A[p]
#         } else break
#     }
# }



# if used on $0, rewrites it using OFS
#   if you want to preserve existing FS, need to use gsplit
# can also be used on array
# returns popped elements separated by SUBSEP
function pop(start,  len, A,   stop, p, last) {
    start = checkpos(start, 0, "pop: first argument must be positive")
    len = checknat(len, 0, "pop: second argument must be >= 0")
    if (isempty(A)) {
        if (!start)
            start = NF
        if (!len && !MISSING)
            return "" # explicit len=0
        if (!len)
            len = NF - start + 1
        stop = start + len - 1
        p = res = ""
        for(; ++stop <= NF; ++start) {
            if (len-- > 0) {
                res = res p $start
                p = SUBSEP
            }
            $start = $stop
        }
        stop = start - 1
        for (; start <= NF; ++start) {
            if (len-- > 0) {
                res = res p $start
                p = SUBSEP
            }
        }
        NF = stop
        if (!p) {
            # nawk won't recompute $0 just because NF was mutated
            if (NF) $1 = $1
            else $0 = ""
        }
        return res
    } else {
        # using array
        last = 1
        while (last in A) last++
        last--
        if (!start)
            start = last
        if (!len && !MISSING)
            return "" # explicit len=0
        if (!len)
            len = last - start + 1
        stop = start + len - 1
        p = res = ""
        for(; ++stop <= last; ++start) {
            if (len-- > 0) {
                res = res p A[start]
                p = SUBSEP
            }
            A[start] = A[stop]
        }
        for (; start <= last; ++start) {
            if (len-- > 0) {
                res = res p A[start]
                p = SUBSEP
            }
            delete A[start]
        }
        return res
    }
}


function insert(value, start,  A,   stop, last) {
    start = checkpos(start, 0, "insert: second argument must be positive")
    if (isempty(A)) {
        if (!start)
            start = NF + 1
        for (stop = NF; stop >= start; stop--) {
            $(stop+1) = $stop
        }
        $start = value
        return NF
    } else {
        # using array
        last = 1
        while (last in A) last++
        last--
        if (!start)
            start = last+1
        for (stop = last; stop >= start; stop--) {
            A[stop+1] = A[stop]
        }
        A[start] = value
        return (start > last) ? start : last + 1
    }
}


function extend(V, start,  A,   stop, lastV, last) {
    start = checkpos(start, 0, "insert: second argument must be positive")
    lastV = 1
    while (lastV in V) lastV++
    lastV--
    if (isempty(A)) {
        if (!lastV)
            return NF
        if (!start)
            start = NF + 1
        for (stop = NF; stop >= start; stop--) {
            $(stop+lastV) = $stop
        }
        for (start--; lastV > 0; lastV--)
            $(start+lastV) = V[lastV]
        return NF
    } else {
        # using array
        last = 1
        while (last in A) last++
        last--
        if (!lastV)
            return last
        if (!start)
            start = last+1
        for (stop = last; stop >= start; stop--) {
            A[stop+lastV] = A[stop]
        }
        last = (start > last) ? start + lastV - 1 : last + lastV
        for (start--; lastV > 0; lastV--)
            A[start + lastV] = V[lastV]
        return last
    }
}


function reverse(A,   i, t, last) {
    if (isempty(A)) {
        last = NF + 1
        for (i=1; i < last--; i++) {
            t = $i
            $i = $last
            $last = t
        }
    } else {
        # using array
        last = 1
        while (last in A) last++
        for (i=1; i < last--; i++) {
            t = A[i]
            A[i] = A[last]
            A[last] = t
        }
    }
}


# defaults to fields $start..$NF, using OFS
# if you want to preserve existing FS, need to use gsplit
# to concat an array without specifying len: concat(start, <uninitialized>, OFS, array)
function concat(start,  len, fs, A,   i, s, p, stop) {
    fs = check(fs, OFS)
    start = checkpos(start, 1, "concat: first argument must be positive")
    len = checknat(len, 0, "concat: second argument must be >= 0")
    if (!len && !MISSING)
        return "" # explicit len=0
    s = p = ""
    if (isempty(A)) {
        if (len)
            stop = start + len - 1
        else
            stop = NF
        # more with fields
        for (i=start; i<=stop; i++) {
            s = s p $i
            p = fs
        }
    } else {
        # using array
        if (len)
            stop = start + len - 1
        for (i=start; len ? i<=stop : i in A; i++) {
            s = s p A[i]
            p = fs
        }
    }
    return s
}


function has_value(A, value,   k) {
    for (k in A)
        if (k[A] == value)
            return true
    return false
}


# if onlykeys, values are ignored
function includes(A, B,  onlykeys,   k) {
    for (k in B)
        if (!(k in A && (onlykeys || A[k] == B[k])))
            return 0
    return 1
}


# if conflicts=0, drop keys; else favor A1 or A2; default=1
function union(A1, A2,  conflicts,   k) {
    conflicts = checknat(conflicts, 1, "union: third argument must be 0, 1, or 2")
    if (conflicts > 2) die("union: third argument must be 0, 1, or 2")
    for (k in A2)
        if (k in A1) {
           if (conflicts == 2)
                A1[k] = A2[k]
            else if (conflicts == 0 && A1[k] != A2[k])
                delete A1[k]
        } else {
            A1[k] = A2[k]
        }
}


# if conflicts=0, drop keys; else favor A1 or A2; default=1
function intersect(A1, A2,  conflicts,   k) {
    conflicts = checknat(conflicts, 1, "intersect: third argument must be 0, 1, or 2")
    if (conflicts > 2) die("intersect: third argument must be 0, 1, or 2")
    for (k in A1)
        if (k in A2) {
            if (conflicts == 2)
                A1[k] = A2[k]
            else if (conflicts == 0 && A1[k] != A2[k])
                delete A1[k]
        } else {
            delete A1[k]
        }
}


# if conflicts=0, drop keys; else keep them (favoring A1); default=1
function subtract(A1, A2,  conflicts,   k) {
    conflicts = checknat(conflicts, 1, "subtract: third argument must be 0 or 1")
    if (conflicts > 1) die("subtract: third argument must be 0 or 1")
    for (k in A2)
        if (k in A1) {
            if (conflicts == 0 || A1[k] == A2[k])
                delete A1[k]
        }
}


## string utils #########


# 'quote' str for shell
function quote(str) {
    gsub(/'/, "'\\''", str)
    return "'" str "'"
}


# delete "quoted" spans, honoring \\ and \"
function delete_quoted(str, repl) {
#     gsub(/"((\\")*([^"\\]|\\[^"])*)*"/, repl, str)
    gsub(/"([^"\\]|\\.)*"/, repl, str)
    return str
}


function json(str, T, V,    c,s,n,a,A,b,B,C,U,W,i,j,k,u,v,w,root) {
    # use strings, numbers, booleans as separators
    # c = "[^\"\\\\[:cntrl:]]|\\\\[\"\\\\/bfnrt]|\\u[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]"
    c = "[^\"\\\\\001-\037]|\\\\[\"\\\\/bfnrt]|\\u[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]"
    s ="\"(" c ")*\""
    n = "-?(0|[1-9][[:digit:]]*)(\\.[[:digit:]]+)?([eE][+-]?[[:digit:]]+)?"

    root = gsplit(str, A, s "|" n "|true|false|null", T)
    assert(root > 0, "unexpected")

    # rejoin string using value indices
    str = ""
    for (i=1; i<root; i++)
        str = str A[i] i
    str = str A[root]

    # sanitize string
    gsub(/[[:space:]]+/, "", str)
    if (str !~ /^[][}{[:digit:],:]+$/) return -1

    # cleanup types and values
    for (i=1; i<root; i++) {
        if (T[i] ~ /^\"/) {
            b = split(substr(T[i], 2, length(T[i])-2), B, /\\/)
            if (b == 0) v = ""
            else {
                v = B[1]
                k = 0
                for (j=2; j <= b; j++) {
                    u = B[j]
                    if (u == "") {
                       if (++k % 2 == 1) v = v "\\"
                    } else {
                        w = substr(u, 1, 1)  
                        if (w == "b") v = v "\b" substr(u, 2)
                        else if (w == "f") v = v "\f" substr(u, 2)
                        else if (w == "n") v = v "\n" substr(u, 2)
                        else if (w == "r") v = v "\r" substr(u, 2)
                        else if (w == "t") v = v "\t" substr(u, 2)
                        else v = v u
                    }
                }
            }
            V[i] = v
            T[i] = "string"
        } else if (T[i] !~ /true|false|null/) {
            V[i] = T[i] + 0
            T[i] = "number"
        } else {
            V[i] = T[i]
        }
    }

    # atomic value?
    a = gsplit(str, A, "[[{]", B)
    if (A[1] != "") {
        if (a > 1) return -2
        else if (A[1] !~ /^[[:digit:]]+$/) return -3
        else return A[1]+0
    }

    # parse objects and arrays
    k = root
    C[0] = 0
    for (i=2; i<=a; i++) {
        T[k] = (B[i-1] ~ /\{/) ? "object" : "array"
        C[k] = C[0]
        C[0] = k
        u = gsplit(A[i], U, "[]}]", W)
        assert(u > 0, "unexpected")
        V[k++] = U[1]
        if (i < a && A[i] != "" && U[u] !~ /[,:]$/)
            return -4
        for (j=1; j<u; j++) {
            if (C[0] == 0 || T[C[0]] != ((W[j] == "}") ? "object" : "array")) return -5
            v = C[0]
            w = C[v]
            C[0] = w
            delete C[v]
            if (w) V[w] = V[w] v U[j+1]
        }
    }
    if (C[0] != 0) return -6

    # check contents
    for (i=root; i<k; i++) {
        if (T[i] == "object") {
            # check object contents
            b = split(V[i], B, /,/) 
            for (j=1; j <= b; j++) {
                if (B[j] !~ /^[[:digit:]]+:[[:digit:]]+$/)
                    return -7
                if (T[substr(B[j], 1, index(B[j],":")-1)] != "string")
                    return -8
            }
        } else {
            # check array contents
            if (V[i] != "" && V[i] !~ /^[[:digit:]]+(,[[:digit:]]+)*$/)
                return -9
        }
    }
    return root
}


# repeat str n times, from http://awk.freeshell.org/RepeatAString
function rep(str, n,  sep,   remain, result) {
    if (n < 2) {
        remain = (n == 1)
        result = sep = ""
    } else {
        remain = (n % 2 == 1)
        result = rep(str, (n - remain) / 2, sep)
        result = result sep result
    }
    return result (remain ? sep str  :"")
}


# -- remove trailing and leading whitespace from string
function trim(str) {
    if (match(str, /[^ \t\n].*[^ \t\n]/))
        return substr(str, RSTART, RLENGTH)
    else if (match(str, /[^ \t\n]/))
        return substr(str, RSTART, 1)
    else
        return ""
}

# # faster than either of:
# function trim2(str) {
#     sub(/^[ \t\n]+/, "", str)
#     sub(/[ \t\n]+$/, "", str)
#     return str
# }
# function trim3(str,  from) {
#     match(str, /^[ \t\n]*/)
#     if ((from = RLENGTH) < length(str)) {
#         match(str, /.*[^ \t\n]/)
#         return substr(str, from+1, RLENGTH-from)
#     } else return ""
# }


# -- remove leading whitespace from string
function trimleft(str) {
    if (match(str, /^[ \t\n]+/))
        return substr(str, RLENGTH+1)
    else
        return str
}

# # nearly the same performance as
# function trimleft2(str) {
#     sub(/^[ \t\n]+/, "", str)
#     return str
# }


# -- remove trailing whitespace from string
function trimright(str) {
    if (match(str, /.*[^ \t\n]/))
        return substr(str, RSTART, RLENGTH)
    else
        return ""
}

# # faster than either of:
# function trimright2(str,   n) {
#     n = length(str)
#     while (n && match(substr(str, n), /^[ \t\n]/)) n--
#     return substr(str, 1, n)
# }
# function trimright3(str) {
#     sub(/[ \t\n]+$/, "", str)
#     return str
# }


# TODO
## cut to max of 10 chars: `sprintf "%.10s", str`


# TODO
# function string:linewrap(width, indent)
#     checktype(self, 1, "string")
#     checkopt(width, 2, "positive!") or 72
#     checkopt(indent, 3, "natural!") or 0
#     local pos = 1
#     -- rest needs to be converted from Lua
#     return self:gsub("(%s+)()(%S+)()",
#         function(sp, st, word, fi)
#             if fi - pos > width then
#                 pos = st
#                 return "\n" .. rep(" ", indent) .. word
#             end
#         end)
# end


function has_prefix(str, pre,   len2) {
        len2 = length(pre)
        return substr(str, 1, len2) == pre
}


function has_suffix(str, suf,   len1, len2) {
        len1 = length(str)
        len2 = length(suf)
        return len2 <= len1 && substr(str, len1 - len2 + 1) == suf
}


function detab(str, siz,    n, r, s, start) {
    siz = checkpos(siz, 8, "detab: second argument must be positive")
    r = ""
    n = start = 0
    while (match(str, "\t")) {
        start += RSTART
        s = siz - (start - 1 + n) % siz
        n += s - 1
        r = r substr(str, 1, RSTART-1) rep(" ", s)
        str = substr(str, RSTART+1)
    }
    return r str
}


function entab(str, siz) {
    siz = checkpos(siz, 8, "detab: second argument must be positive")
    str = detab(str, siz)
    gsub(".{" siz "}", "&\1", str)
    gsub("  +\1", "\t", str)
    gsub("\1", "", str)
    return str
}


## regexp utils #########
## WARNING: /re/ evaluates as boolean, so have to pass "re"s to user functions

# populate array from str="key key=value key=value"
# can optionally supply "re" for equals, space; if they're the same or equals is "", array will be setlike
function asplit(str, array,  equals, space,   aux, i, n) {
    n = split(str, aux, (space == "") ? "[ \n]+" : space)
    if (space && equals == space)
        equals = ""
    else if (ismissing(equals))
        equals = "="
    split("", array) # delete array
    for (i=1; i<=n; i++) {
        if (equals && match(aux[i], equals))
            array[substr(aux[i], 1, RSTART-1)] = substr(aux[i], RSTART+RLENGTH)
        else
            array[aux[i]]
    }
    split("", aux) # does it help to delete the aux array?
    return n
}


# like lua's find("%b()"), --> RSTART and sets RSTART and RLENGTH
function bmatch (s, opener, closer,   len, i, n, c) {
    len = length(s)
    n = 0
    for (i=1; i <= len; ++i) {
        c = substr(s, i, 1)
        if (c == opener) {
            if (n == 0) RSTART = i
            ++n
        } else if (c == closer) {
            --n
            if (n == 0) {
                RLENGTH = i - RSTART + 1
                return RSTART
            }
        }
    }
    return 0
}


# TODO
# tail not defined for negative nth (doesn't make sense, will always be none)
# negative nth with zero-length matches:
#   - head returns one element too early, or sometimes wrongly?
#   - matchstr diverges
function tail(str,  re, nth, m,  start, n) {
    nth = checkpos(nth, 1, "tail: third argument must be positive")
    re = check(re, SUBSEP)
    if (nth == 1) {
        if (match(str, re)) {
            m = substr(str, RSTART + RLENGTH)
            RSTART += RLENGTH
            RLENGTH = length(m)
        }
        return m
    } else {
        RLENGTH = -1
        start = 1
        while (nth--) {
            if (RLENGTH > 0) {
                str = substr(str, RSTART + RLENGTH)
                start += RLENGTH - 1
            } else if (RLENGTH == 0) {
                start++
                if ((str = substr(str, RSTART + 1)) == "") {
                    nth--
                    break
                }
            }
            n = (RLENGTH > 0)
            if (!match(str, re)) break
            if (n && !RLENGTH) {
                assert(RSTART == 1 && nth >= 0)
                if ((str = substr(str, 2)) == "" || !match(str, re)) break
                start++
            }
            start += RSTART + n - 1
        }
        if (nth >= 0) {
            RSTART = 0
            RLENGTH = -1
        } else {
            m = substr(str, RSTART + RLENGTH)
            RSTART = start + RLENGTH
            RLENGTH = length(m)
        }
        return m
    }
}


# this returns items between "re"; matchstr returns what matches "re"
# 3rd argument to specify which item (-1 for last)
# defaults to re=SUBSEP nth=1st none=""
function head(str, re, nth,  none,   start, m, n) {
    if (nth != -1) {
        nth = checkpos(nth, 1, "head: third argument must be positive")
    }
    re = check(re, SUBSEP)
    if (nth == 1) {
        if (match(str, re)) {
            RLENGTH = RSTART - 1
            str = substr(str, 1, RLENGTH)
        } else {
            RLENGTH = length(str)
        }
        RSTART = 1
        return str
    } else {
        # # to get arbitrary item, we just split
        # nf = split(str, aux, re)
        # if (nth == -1 && nf > 0)
        #     m = aux[nf]
        # else if (nth in aux)
        #     m = aux[nth]
        # split("", aux) # does it help to delete the aux array?
        # return m

        # I simplified and streamlined as much as I could, while still passing tests.
        m = (nth > 0) ? none : ""
        RLENGTH = -1
        start = 1
        while (nth--) {
            if (RLENGTH > 0) {
                str = substr(str, RSTART + RLENGTH)
                start += RSTART + RLENGTH - n
                m = (nth > 0) ? none : str
            } else if (RLENGTH==0) {
                start += RSTART + 1
                m = n ? substr(str, 2, 1) : str
                if ((str = substr(str, 2+n)) == "") {
                    if (!m || nth > 1) {
                        RSTART = 0
                        RLENGTH = -1
                        return none
                    } else if (nth-- > 0)
                        m = ""
                    else
                        start--
                    break
                }
            }
            n = (RLENGTH > 0)
            if (!match(str, re)) break
            if (RSTART > 1)
                m = substr(str, 1, RSTART-1)
            else
                m = (n && RLENGTH) ? "" : substr(m, 1, 1)
            start += n - 1
        }
        if (nth <= 0) {
            RSTART = start
            RLENGTH = length(m)
        }
        return m
    }
}


# 3rd argument to specify occurrence (default=1st, -1=last)
# permits one 0-length match at RSTART = length(str)+1
function matchstr(str, re, nth,  none,   m, start, len, n) {
    start = n = 0
    if (nth == -1) {
        # find last occurrence
        len = -1
        m = none
        while (match(str, re)) {
            start = (n += RSTART)
            len = RLENGTH
            m = substr(str, RSTART, RLENGTH)
            # handle 0-length match
            if (!RLENGTH) RLENGTH++
            n += RLENGTH - 1
            str = substr(str, RSTART + RLENGTH)
        }
        RSTART = start
        RLENGTH = len
        return m
    }
    nth = checkpos(nth, 1, "matchstr: third argument must be positive")
    RLENGTH = -1
    start = 1
    while (nth--) {
        if (RLENGTH > 0) {
            str = substr(str, RSTART + RLENGTH)
            start += RLENGTH - 1
        } else if (RLENGTH == 0) {
            start++
            if ((str = substr(str, RSTART + 1)) == "") {
                nth--
                break
            }
        }
        n = (RLENGTH > 0)
        if (!match(str, re)) break
        if (n && !RLENGTH) {
            assert(RSTART == 1 && nth >= 0)
            if ((str = substr(str, 2)) == "" || !match(str, re)) break
            start++
        }
        start += RSTART + n - 1
    }
    if (nth >= 0) {
        RSTART = 0
        RLENGTH = -1
        return none
    } else {
        m = substr(str, RSTART, RLENGTH)
        RSTART = start
        return m
    }
}


# 3rd argument to specify occurrence (default=1st, -1=last)
function nthindex(str, needle, nth,   i, n, len, start) {
    start = 0
    n = 0
    len = length(needle)
    if (nth == -1) {
        # find last occurrence
        while ((i = index(str, needle)) > 0) {
            n = start + i
            start += (i + len -1)
            str = substr(str, i + len)
        }
        return n
    }
    nth = checkpos(nth, 1, "nthindex: third argument must be positive")
    do {
        if (n > 0) {
            str = substr(str, n + len)
            start += (len -1)
        }
        n = index(str, needle)
        start += n
    } while (n && --nth)
    return nth ? 0 : start
}


# gawk's match does only a single match, and returns \0,\1..\n, starts, and lengths in a single array
# this function does global match, and returns only \0 and starts, in two arrays
function gmatch(str, re,  ms, starts,   i, n, start, sep1, sep2) {
    # find separators that don't occur in str
    i = 1
    do
        sep1 = sprintf("%c", i++)
    while (sep1 ~ /[][^$(){}.*+?|\\]/ || index(str, sep1))
    do
        sep2 = sprintf("%c", i++)
    while (index(str, sep2))
    split("", starts) # delete array
    n = gsub(re, sep1 "&" sep2, str)
    split(str, ms, sep1)
    start = 1
    for (i=1; i<=n; i++) {
        start += length(ms[i])
        starts[i] = start--
        ms[i] = substr(ms[i+1], 1, index(ms[i+1], sep2) - 1)
    }
    delete ms[i]
    return n
}


# function gmatch(str, re,  ms, starts,   n, i, start, stop, eaten, sep1, sep2) {
#     n = 0
#     eaten = 0
#     # find separators that don't occur in str
#     i = 1
#     do
#         sep1 = sprintf("%c", i++)
#     while (index(str, sep1))
#     do
#         sep2 = sprintf("%c", i++)
#     while (index(str, sep2))
#     split("", ms) # delete array
#     split("", starts) # delete array
#     i = gsub(re, sep1 "&" sep2, str)
#     while (i--) {
#         start = index(str, sep1)
#         stop = index(str, sep2) - 1
#         # testing for the arrays interpret them as scalar; just use them
#         ms[++n] = substr(str, start + 1, stop - start)
#         starts[n] = eaten + start
#         eaten += stop - 1
#         str = substr(str, stop + 2)
#     }
#     return n
# }


# based on <http://awk.freeshell.org/FindAllMatches>
# function gmatch(str, re,  ms, starts,   n, i, eaten) {
#     n = 0
#     eaten = 0
#     # we check number of matches to help avoid rematching anchored REs
#     # but note this isn't a reliable solution: "^a|b" will wrongly match indices 1 and 2 of "aab"
#     i = gsub(re, "&", str)
#     while (i-- && match(str, re) > 0) {
#         # testing for the arrays interpret them as scalar; just use them
#         ms[++n] = substr(str, RSTART, RLENGTH)
#         starts[n] = eaten + RSTART
#         # handle 0-length match
#         if (!RLENGTH) RLENGTH++
#         eaten += (RSTART + RLENGTH -1)
#         str = substr(str, RSTART + RLENGTH)
#     }
#     return n
# }


# behaves like gawk's split; special cases re == "" and " "
# unlike split, will honor 0-length matches
function gsplit(str, items, re,  seps,   n, i, start, stop, sep1, sep2, sepn) {
    n = 0
    # find separators that don't occur in str
    i = 1
    do
        sep1 = sprintf("%c", i++)
    while (index(str, sep1))
    do
        sep2 = sprintf("%c", i++)
    while (index(str, sep2))
    sepn = 1
    split("", seps) # delete array
    if (ismissing(re))
        re = FS
    if (re == "") {
        split(str, items, "")
        n = length(str)
        for (i=1; i<n; i++)
            seps[i]
        return n
    }
    split("", items) # delete array
    if (re == " ") {
        re = "[ \t\n]+"
        if (match(str, /^[ \t\n]+/)) {
            seps[0] = substr(str, 1, RLENGTH)
            str = substr(str, RLENGTH+1)
        }
        if (match(str, /[ \t\n]+$/)) {
            sepn = substr(str, RSTART, RLENGTH)
            str = substr(str, 1, RSTART-1)
        }
    }
    i = gsub(re, sep1 "&" sep2, str)
    while (i--) {
        start = index(str, sep1)
        stop = index(str, sep2) - 1
        seps[++n] = substr(str, start + 1, stop - start)
        items[n] = substr(str, 1, start - 1)
        str = substr(str, stop + 2)
    }
    items[++n] = str
    if (sepn != 1) seps[n] = sepn
    return n
}


## debugging #########

function dump(array,  prefix,   i) {
    for (i in array) {
        printf "%s[%s]=<%s>\n", prefix, i, array[i]
    }
}


# idump(array, [[start],stop], [prefix])
function idump(array,  stop, prefix,   i, start) {
    if (isnum(prefix)) {
        start = stop
        stop = prefix
        prefix = i
    } else start = 1
    for (i=start; !stop || i<=stop; i++)
        if (i in array) {
            printf "%s[%d]=<%s>\n", prefix, i, array[i]
        } else if (!stop) break
}


## getopt-handling #########

function usage(basename, version, description, summary, longsummary, addl, optstring, options, minargs) {
    gsub(/\n/, "\n ", longsummary)
    description = "Usage:   " basename " " summary "\n         " description "\nAuthor:  Jim Pryor <dubiousjim@gmail.com>\nVersion: " version "\n\nOptions:\n " longsummary (addl ? "\n\n" addl : "") "\n\nThis script is in the public domain, free from copyrights or restrictions."
    getopt(optstring, options, basename, version, description)
    if (ARGC - 1 < minargs) {
        print description > "/dev/stderr"
        exit 2
    }
}


function getopt(optstring, options, basename, version, usage_msg,   i, j, o, m, n, a, d) {
    # options["long"] = ""         option with no argument
    # options["long"] = ":"        option with required argument, only remember last occurrence
    # options["long"] = "?default" option with optional argument, only remember last occurrence
    # options["long"] = "+"        repeatable option with required argument, results will be separated by SUBSEP
    # options["long"] = "*default" repeatable option with optional argument, results will be separated by SUBSEP (not useful? disabled)

    # optstring = "ab:c?d+e*" ~~> { a="", b=":", c="?", d="+", e="*" }

    for (i=1; i<=length(optstring); ) {
        options[m = substr(optstring, i++, 1)]
        if (substr(optstring, i, 1) ~ /[:+?]/)  # /[:+?*]/ disabled *
            options[m] = substr(optstring, i++, 1)
    }

    for (i=1; i<ARGC; ) {
        if (ARGV[i] == "--") {
            # end of option arguments
            i++
            break
        } else if (ARGV[i] ~ /^--[a-z][a-z]/) {
            m = substr(ARGV[i++], 3)
            if (m == "version") {
                printf "%s version %s\n", basename, version > "/dev/stderr"
                exit 0
            } else if (m == "help") {
                print usage_msg > "/dev/stderr"
                exit 0
            }
            if (j = index(m, "=")) {
                a = substr(m, j+1)
                m = substr(m, 1, j-1)
            }
            if (!(m in options)) {
                printf "%s: unknown option --%s\n", basename, m > "/dev/stderr"
                exit 2
            }
        } else if (ARGV[i] ~ /^--/) {
            printf "%s: unknown option %s\n", basename, ARGV[i] > "/dev/stderr"
            exit 2
        } else if (ARGV[i] ~ /^-./) { 
            m = substr(ARGV[i], 2, 1)
            if (length(ARGV[i]) == 2) {
                j = 0 # no argument yet
                i++
            } else {
                j = 1 # flag unknown argument
                a = substr(ARGV[i], 3)
                ARGV[i] = "-" a
            }
            if (!(m in options)) {
                printf "%s: unknown option -%s\n", basename, m > "/dev/stderr"
                exit 2
            }
        } else {
            # first non-option argument
            break
        }

        n = substr(options[m], 1, 1)
        if (n == ":" || n == "+") {
            if (j==1) {
                # consume rest of current ARGV
                i++
            } else if (j==0)
                if (i<ARGC && (a = ARGV[i]) !~ /^-/)
                    i++
                else {
                    printf "%s: option -%s%s missing required argument\n", basename, (length(m)==1) ? "" : "-", m > "/dev/stderr"
                    exit 2
                }
            # :[SUBSEP arg] gets reassigned
            # +[SUBSEP arg...] is repeatable
            options[m] = ((n==":") ? n : options[m]) SUBSEP a
        } else if (n == "?") {  #   || n == "*" disabled *
            d = index(options[m], SUBSEP)
            d = substr(options[m], 2, d ? d-1 : length(options[m]))
            if (j==1) {
                # consume rest of current ARGV
                i++
            } else if (j==0)
                if (i<ARGC && (a = ARGV[i]) !~ /^-/)
                    i++
                else {
                    # missing optional argument
                    a = d
                }
            # ?default[SUBSEP arg] gets reassigned
            # *default[SUBSEP arg...] is repeatable
            options[m] = ((n=="?") ? "?" d : options[m]) SUBSEP a
        } else {
            if (j>1) {
                printf "%s: option --%s doesn't accept an argument\n", basename, m > "/dev/stderr"
                exit 2
            }
            options[m] = ++o
        }
    }
    if (i>1) {
        for (j=1; i<ARGC; )
            ARGV[j++] = ARGV[i++]
        ARGC = j
    }
    for (m in options) {
        if (options[m] ~ /^[:+?*]/) {
            if (k = index(options[m], SUBSEP))
                options[m] = substr(options[m], k+1)
            else
                delete options[m]
        } else if (!(options[m]))
            delete options[m]
    }
}



## os/filesystem #########

# assert(system(cmd) == 0, "system(\"" cmd "\") failed")


function isreadable(path) {
    return (system("test -r " quote(path)) == 0)
}

# function isreadable(path,   v, res) {
#     res = 0
#     if ((getline v < path) >= 0) {
#         res = 1 # though file may be empty
#         close(path)
#     }
#     return res
# }


function filesize(path,   followlink,  v, cmd) {
    cmd = "ls -ld " (followlink ? "-L " : "") quote(path) " 2>/dev/null"
    if (0 < (cmd | getline v)) {
        close(cmd)
        if (v ~ /^-/) {
            return head(v, " ", 5) # filesize
        } else {
            return "" # not regular file
        }
    } else {
        close(cmd)
        return -1 # file doesn't exist
    }
}


function filetype(path,   followlink,  v, cmd) {
    cmd = "ls -ld " (followlink ? "-L " : "") quote(path) " 2>/dev/null"
    if (0 < (cmd | getline v)) {
        close(cmd)
        v = substr(v, 1, 1) # -dlcbsp
        if (v == "-")
            return "f" # this ensures that error result < all non-error results
        else
            return v
    } else {
        close(cmd)
        return -1 # file doesn't exist
    }
}


function basename(path, suffix) {
    sub(/\/$/, "", path)
    if (path == "")
        return "/"
    sub(/^.*\//, "", path)
    if (suffix != "" && has_suffix(path, suffix))
        path = substr(path, 1, length(path) - length(suffix))
    return path
}


function dirname(path) {
    if (!sub(/\/[^\/]*\/?$/, "", path))
        return "."
    else if (path != "")
        return path
    else
        return "/"
}


function getfile(path,   v, p, res) {
    res = p = ""
    while (0 < (getline v < path)) {
        res = res p v
        p = "\n"
    }
    assert(close(path) == 0, "close(\"" path "\") failed")
    return res
}


function getpipe(cmd,   v, p, res) {
    res = p = ""
    while (0 < (cmd | getline v)) {
        res = res p v
        p = "\n"
    }
    assert(close(cmd) == 0, "close(\"" cmd "\") failed")
    return res
}


# creates a file that will be deleted when awk exits; works on FreeBSD, should also work on BusyBox, whose `trap` accepts only numeric signals; also FreeBSD permits `mktemp -t awk` but BusyBox requires `mktemp -t /tmp/awk.XXXXXX`
function mktemp(   cmd, v) {
    # base directory is -p DIR, else ${TMPDIR-/tmp}
    # -t tmp.XXXXXX or TEMPLATE
    cmd = "T=`mktemp \"${TMPDIR:-/tmp}/awk.XXXXXX\"` || exit 1; trap \"rm -f '$T'\" 0 1 2 3 15; printf '%s\n' \"$T\"; cat /dev/zero"
#     0/EXIT
#     1/HUP: controlling terminal or process died
#     2/INT ^C from keyboard
#     15/TERM

#     3/QUIT ^\ from keyboard
#     6/ABRT from abort(2)
#     13/PIPE: write to pipe with no readers
#     14/ALRM from alarm(2), e.g. if script calls sleep

# other stty keys: eof=^d start/stop=^q/^s susp=^z dsusp=^y
#                  erase/erase2=^?/^h werase=^w kill=^u reprint=^r lnext=^v
#                  flush/discard=^o status=^t

    if (0 < (cmd | getline v)) {
        return v
    } else {
        return ""
    }
    # we intentionally don't close the pipe
}

