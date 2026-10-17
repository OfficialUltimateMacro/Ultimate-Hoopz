"""Build editable register-source from the recovered Blessed prototypes.

Not a recovery of original variable names or structured source. Keeps control
flow explicit and retains compatibility metadata for self-modifying operands.
"""
import json,re,pathlib,hashlib,sys
runtime_mode=True
ROOT=pathlib.Path(__file__).resolve().parent
program=json.load(open(ROOT/'data/Blessed.decoded-program.json'))
opcodes=json.load(open(ROOT/'data/Blessed.instruction-handlers.json'))
functions={}
def walk(p,path):
    if not isinstance(p,dict) or not isinstance(p.get('7'),dict):return
    functions[path]=p
    for k,ch in p.get('2',{}).items():walk(ch,path+'.'+k)
walk(program,'root')
object_paths={id(p):path for path,p in functions.items()}
brand_changes=[]
def literal(v,path=''):
    if v is None:return 'nil'
    if isinstance(v,bool):return str(v).lower()
    if isinstance(v,(int,float)):
        if v==float('inf'):return 'math.huge'
        if v==-float('inf'):return '-math.huge'
        if v!=v:return '(0/0)'
        return str(int(v)) if int(v)==v else repr(v)
    if isinstance(v,str):
        if v in ['Infinity','-Infinity','NaN']:return {'Infinity':'math.huge','-Infinity':'-math.huge','NaN':'(0/0)'}[v]
        new=v
        if v in ('http://www.roblox.com/asset/?id=130354021852199','rbxassetid://130354021852199'):
            brand_changes.append({'location':path,'before':v,'after':'Ultimate wordmark'})
            return 'ULTIMATE_LOGO_TOKEN'
        if v=='blessed' or v=='Blessed' or v=='BLESSED':new='Ultimate'
        # Keep external ownership/dependency URLs as supplied; changing a remote
        # destination is not a branding-only transformation.
        if new!=v:
            brand_changes.append({'location':path,'before':v,'after':new})
            return 'BRAND'
        raw=new.encode('utf-8')
        return '"'+''.join(chr(b) if 32<=b<127 and chr(b) not in '\\"' else ('\\'+chr(b) if chr(b) in '\\"' else '\\%03d'%b) for b in raw)+'"'
    if isinstance(v,dict):
        if id(v) in object_paths:return 'prototypes['+json.dumps(object_paths[id(v)])+']'
        return '{'+','.join('['+literal(int(k) if k.lstrip('-').isdigit() else k)+']='+literal(x,path+'.'+k) for k,x in sorted(v.items(),key=lambda z:int(z[0]) if z[0].lstrip('-').isdigit() else 999999) if k!='0')+'}'
    raise TypeError(type(v))

helpers='''-- Ultimate / Blessed decoded register-source
-- Reconstructed from the user-supplied Blessed script. Original names and
-- comments are unavailable. Numeric program counters preserve recovered flow.
-- Original UI and gameplay functions are retained; this is not Ultimate 1.1.
local BRAND = "Ultimate"
local prototypes, functions, prototypeNames = {}, {}, {}
local customizeClosure, UltimateExtensions
local unpackValues = table.unpack or unpack
local function slice(first, values, last) return unpackValues(values, first, last or #values) end
local function packValues(...) return select("#", ...), {...} end
local function iterate(iterator, state, control)
    if type(iterator)=="table" then
        local mt=getmetatable(iterator)
        if type(mt)=="table" and type(mt.__iter)=="function" then return mt.__iter(iterator) end
        return next,iterator,nil
    end
    return iterator,state,control
end
local function array() return {} end
local bitFunctions={
    [6]=bit32.countrz,[7]=bit32.bxor,[8]=bit32.bor,[9]=bit32.lshift,
    [10]=bit32.lrotate,[11]=bit32.band,[12]=bit32.countlz,[13]=bit32.bnot,
    [14]=bit32.rshift,[15]=bit32.rrotate,[16]=string.unpack
}
local function getEnvironment() return getfenv and getfenv() or _G end
local function makeClosure(prototype, upvalues, environment)
    local name=prototypeNames[prototype]
    local original=functions[name](environment, upvalues)
    return customizeClosure and customizeClosure(name,original,environment,upvalues) or original
end
'''
lines=[helpers, (ROOT/'customizations.lua').read_text(encoding='utf-8'), (ROOT/'extensions.lua').read_text(encoding='utf-8'), (ROOT/'offense.lua').read_text(encoding='utf-8')]
for path,p in functions.items():lines.append('prototypes['+json.dumps(path)+']={};prototypeNames[prototypes['+json.dumps(path)+']]='+json.dumps(path))
for path,p in functions.items():
    lines.append('-- Recovered metadata: '+path)
    for field,value in p.items():
        lines.append('prototypes['+json.dumps(path)+']['+field+']='+literal(value,path+'.'+field))
lines.append('applyUltimateDefaults(prototypes.root)')

opcodes['5']=opcodes['100'];opcodes['23']=opcodes['89'];opcodes['47']=opcodes['37'];opcodes['85']=opcodes['56']
opcodes['92']='applyUltimateProperty(l[Y[t]],W[t],U[t],A);'
opcodes['122']='applyUltimateProperty(l[Y[t]],U[t],l[R[t]],A);'
if runtime_mode:
    for special,ordinary in [(5,100),(23,89),(47,37),(85,56)]:opcodes[str(special)]='i[t]='+str(ordinary)+';'+opcodes[str(special)]
# These four instructions cache an equivalent ordinary operation into their
# own opcode slot. Their visible operation is the corresponding simple opcode.
opcodes['35']='''local child=Q[t];local descriptors=child[10];local count=#descriptors
local captured=count>0 and {} or nil
local closure=makeClosure(child,captured,A)
l[p[t]]=closure
if captured then
    for index=1,count do
        local descriptor=descriptors[index]
        local source,kind=descriptor[1],descriptor[2]
        if kind==0 then
            if not S then S={} end
            local cell=S[source]
            if not cell then cell={[2]=l,[1]=source};S[source]=cell end
            captured[index-1]=cell
        elseif kind==1 then captured[index-1]=l[source]
        else captured[index-1]=y[source] end
    end
end'''
helper_map={2:'array',7:'bit32.bxor',11:'bitFunctions',13:'slice',15:'table.move',17:'coroutine.wrap',24:'getEnvironment',25:'coroutine.yield',36:'packValues'}
def helper_replace(m):
    index=int(m[1],0)
    if index not in helper_map:raise ValueError('Unknown helper '+str(index))
    return helper_map[index]
names={'l':'registers','y':'upvalues','t':'pc','z':'top','a':'argumentCount','b':'varargCount','q':'varargs','_':'varargStart','A':'environment','B':'loopFrames','r':'loopStep','j':'loopIndex','O':'loopLimit','S':'openUpvalues','n':'opcode','D':'prototype','R':'operandR','Y':'operandY','p':'operandP','Q':'constantQ','U':'constantU','W':'constantW','i':'instructions','s':'runtime'}
token=re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\b[A-Za-z_]\w*\b')
def body(op):
    code=opcodes[str(op)]
    code=re.sub(r's\[0[xX]0*1\]\[0[xX]0*[bB]\]|s\[1\]\[11\]', 'bitFunctions',code)
    code=re.sub(r's\[(?:0[xX]0*1|1)\]\[(0[xX][0-9a-fA-F]+|\d+)\]',helper_replace,code)
    code=code.replace('__iter','iterate')
    if 'goto ' in code or 'CONT' in code:raise ValueError('Unremoved flattened handler '+str(op))
    code=token.sub(lambda m:names.get(m[0],m[0]) if not m[0].startswith(('"',"'")) else m[0],code)
    return code
def dispatch(slots,indent):
    if len(slots)==1:
        pc,op=slots[0]
        return [indent+'-- slot '+str(pc)+', recovered operation '+str(op)]+[indent+x for x in body(op).splitlines()]
    mid=len(slots)//2
    return [indent+'if '+('opcode' if runtime_mode else 'pc')+' < '+str(slots[mid][0])+' then']+dispatch(slots[:mid],indent+'    ')+[indent+'else']+dispatch(slots[mid:],indent+'    ')+[indent+'end']
if runtime_mode:
    items=[('runtime',program)]
else:items=list(functions.items())
for path,p in items:
    slots=sorted((int(k),int(v)) for k,v in p['7'].items() if k!='0')
    lines+=['\n-- FUNCTION '+path+' ('+str(len(slots))+' recovered slots)',
        ('local function runPrototype(prototype,environment,upvalues)' if runtime_mode else 'functions['+json.dumps(path)+']=function(environment,upvalues)'),
        ('' if runtime_mode else '    local prototype=prototypes['+json.dumps(path)+']'),
        '    local operandR,operandY,operandP=prototype[11],prototype[9],prototype[8]',
        '    local constantQ,constantU,constantW=prototype[2],prototype[6],prototype[1]',
        '    local instructions=prototype[7]',
        '    return function(...)',
        '        local registers,argumentCount,top,varargStart={},0,1,1',
        '        local pc,loopFrames,loopStep,loopIndex,loopLimit=1',
        '        local varargCount,varargs,openUpvalues',
        '        while true do']
    if runtime_mode:
        lines+=['            if prototype == prototypes.root then', '                if pc == 1973 then pc=1974 end -- No aimbot key binding.', '                if pc == 1346 and UltimatePreferences.HideAimbotKeyPicker then top=operandR[pc]-1;pc=pc+1 end', '                observeUltimateRoot(environment,registers,pc)', '            end', '            local opcode=instructions[pc]', '            if type(opcode)~="number" or opcode<0 or opcode>124 then error("Unresolved instruction in "..prototypeNames[prototype].." at "..tostring(pc)) end']
        lines+=dispatch([(o,o) for o in range(125)],'            ')
    else:lines+=dispatch(slots,'            ')
    lines+=['            pc=pc+1','        end','    end','end']
if runtime_mode:
    lines+=['for name,prototype in pairs(prototypes) do','    local current=prototype','    functions[name]=function(environment,upvalues) return runPrototype(current,environment,upvalues) end','end']
lines+=['\nif rawget(_G,"ULTIMATE_BLESSED_INSPECT") then return {Functions=functions,Prototypes=prototypes,Names=prototypeNames,Preferences=UltimatePreferences,ApplyProperty=applyUltimateProperty,ResolveLogo=resolveUltimateLogo,Extensions=UltimateExtensions,CustomizeClosure=customizeClosure} end',
        'return functions.root(getEnvironment(),{})(...)']
source='\n'.join(lines)+'\n'
path=ROOT/('Ultimate.Blessed.decoded.lua' if runtime_mode else 'Ultimate.Blessed.register-source.lua');path.write_text(source,encoding='utf-8',newline='\n')
(ROOT/'branding-changes.json').write_text(json.dumps(brand_changes,indent=2),encoding='utf-8')
manifest={'artifact':path.name,'kind':'decoded register-source reconstruction','original_source_recovered':False,'functions':len(functions),'instruction_slots':sum(len(p['7']) for p in functions.values()),'branding_edits':len(brand_changes),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'live_tested':False,'published':False}
(ROOT/'reconstruction-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))

