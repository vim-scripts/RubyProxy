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
"
" @TODO:
"   Adding support for lists

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

ruby << EOF

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

def withProxy 
   f = RubyProxy.new
   yield f
end
class RubyProxy
    def initialize

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
    def *(r)
        s = r.take(1)
        r = r.drop(1)
        accum = []
        r.each{ |p|
            if p.instance_of? String and (p.match(/^[0-9]+$/) == nil)
                accum.push('"'+p.gsub(/"/,'\\"')+ '"')
            else 
                if p.instance_of? String 
                    accum.push(p.to_i.to_s)
                else 
                    accum.push(p.to_s)
                end
            end
        }  
        accum = accum.join(", ")
        VIM::evaluate(s.join("") + "(" + accum + ")")
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
