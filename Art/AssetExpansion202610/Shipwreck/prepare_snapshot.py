"""Convert the generator's actual JSON snapshot losslessly to a plain Lua table."""
from pathlib import Path
import json,math,sys
root=Path(__file__).parent/'Integration'
stem=sys.argv[1] if len(sys.argv)>1 else 'layout_snapshot'
assert stem in ['layout_snapshot','world_snapshot']
source=root/(stem+'.json')
data=json.loads(source.read_text(encoding='utf8'))
def lua(v):
    if v is None:return 'nil'
    if isinstance(v,bool):return 'true' if v else 'false'
    if isinstance(v,(int,float)):
        assert math.isfinite(v)
        return repr(v)
    if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
    if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
    if isinstance(v,dict):return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'
    raise TypeError(type(v))
(root/(stem+'.lua')).write_text('return '+lua(data),encoding='utf8')
print('snapshot conversion',len(data.get('cells',[])),'cells')
