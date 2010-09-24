"Copyright (c) 2010, Edgar Klerks,I-Bytes
"All rights reserved.
"
"Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
"
"   * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
"   * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
"   * Neither the name of I-Bytes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
"
"THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

" The purpose of this file is to give ruby access to most of the functions of
" vim, so scripting in ruby for vim becomes easier. 
" Know bugs: Doesn't work with functions, which expects or wich return lists
" yet
"
" Please mail patches to e.klerks@i-bytes.nl
"
" Version 0.1 - Intial version
" Version 0.2 - Added conversion of datatype from vim to ruby with yaml.
"               Supported are: String, Number, List. The rest is coming soon
" Version 0.21 - Added support for multilevel lists
"                Cleaned up script
" @TODO:
"   Adding support for Dictionaries and Floats

"
" Example usage:
" 


function! RepeatAndNumber(m,n)
ruby << EOF
    withProxy { |p|
        p.RepeatAndNumber(getA("m"), getA("n"),p)
    }
EOF
endfunction
" This function returns output, which YAML::load can use
" It supports Numbers, Strings, FuncRefs, Lists, Dictionaries and Floats

function! DataToRuby(f)
    let z = "--- " . s:DataTypeToRuby_(a:f)
    return z
endfunction

function! s:DataTypeToRuby_(f)
    let l = a:f
    if type(l) == 0
        return s:NumberToRuby(l)
    endif
    if type(l) == 1
        return s:StringToRuby(l)
    endif
    "Func refs are unpacked before sent to ruby
    if type(l) == 2
        let x = l()
        return s:DataTypeToRuby_(x)
    endif
    if type(l) == 3
        return "\n" . s:ListToRuby(l)
    endif
    if type(l) == 4
        return s:DictionaryToRuby(l)
    endif
    if type(l) == 5
        return s:FloatToRuby(l)
    endif 
endfunction
" A float is translated to a Fixnum
" Which is shown as follow: 1\n
function! s:NumberToRuby(f)
    return string(a:f) . "\n"
endfunction
" A string is pretty basic a string with a \n at the end
function! s:StringToRuby(f)
    return string(a:f) . "\n"
endfunction


function! s:ListToRuby(ls)
    let ls = a:ls
    return s:ListToRuby_(ls, 0)
endfunction

" Needed to debug
function! s:Log(z, f, a, d, l, msg)
"    echo "(" . a:msg . ") z=" . substitute(a:z,"\\n","+","g") . ",f=" . a:f . ",a=" . a:a . ",d=" . a:d . ",l=" . a:l
endfunction

" Worker function, turns a list into yaml
function! s:ListToRuby_(ls,d)
    let ls = a:ls
    let z = ""
    let d = a:d
    let f = 1
    for l in ls
        if type(l) == 3
            call Log(z,f,"array",d,"","(before)")
            let z .= repeat('  ', d) . '- ' . s:ListToRuby_(l, d + 1) 
            call Log(z,f,"array",d,"","(after)")
        else 
            if f == 1
                call Log(z,f,"element",d,l,"(before)")
                let z .= '- ' . s:DataTypeToRuby_(l)
                call Log(z,f,"element",d,l,"(after)")
                let f = 0
            else 
                call Log(z,f,"element",d,l,"(before)")
                let z .= repeat('  ',d) . '- ' .  s:DataTypeToRuby_(l)
                call Log(z,f,"element",d,l,"(after)")
            end
        endif
        unlet l
    endfor
    return z
endfunction

" Dictionary support coming soon

function! s:DictionaryToRuby(f)
    throw "Dictionary is not supported yet" 
endfunction

function! s:DecodeTest(x)
ruby << EOF
    decodeTest(getA("x"));
EOF
endfunction

" Not sure this works, cannot test it on my vim version

function! s:FloatToRuby(f)
    return string(f) . "\n"
endfunction
ruby << EOF

require 'yaml'
# used for example
def RepeatAndNumber(m,n,v)
    r = v.Vgetline(".")
    z = []
    (m.to_i..n.to_i).each {|n|
        z.push(r.gsub(/\$i/,n.to_s))
    }
    v.Vsetline(".",z.shift());
    z.reverse.each { |s|
        v.Vappend(".", s)
    }
end
$i
def decodeTest(n)
    v = YAML::load(n)
    YAML::dump(v).split(/\n/).each { |x| puts x }
end

def withProxy 
   f = RubyProxy.new
   yield f
end
class RubyProxy
    def initialize

    end
    def decodeYaml(accum,p)
        accum.push(YAML::load(p))
    end
    def method_missing(m,*r)
        m = m.to_s.split(//)
        if(m.first() == "V")
            r = r.unshift(m.drop(1).join(""))
            res = self * r
            return res
        end
        puts "No such method: " + m.join("") + " did you forget to prefix with V?"
    end
    def convert(accum,p)
        if p.instance_of? String and (p.match(/^[0-9]+$/) == nil)
            accum.push('"'+p.gsub(/"/,'\\"')+ '"')
        else 
            if p.instance_of? String 
                accum.push(p.to_i.to_s)
            else 
                accum.push(p.to_s)
            end
        end
    end
    def *(r)
        s = r.take(1)
        r = r.drop(1)
        accum = []
        r.each{ |p|
            self.convert(accum,p)
        }  
        accum = accum.join(", ")
        YAML::load(VIM::evaluate("DataToRuby(" + s.join("") + "(" + accum + ")" + ")"))
    end
end

def getA(n)
    VIM::evaluate("a:" + n)
end

def getS(n)
    VIM::evaluate("s:" + n)

end
def getG(n)
    VIM::evaluate("g:" + n)
end

EOF
