import readline from 'node:readline';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {runCommand} from './cli.mjs';
const string={type:'string'},integer={type:'integer'},patch={type:'object',properties:{revision:string,operations:{type:'array',minItems:1,maxItems:1000,items:{type:'object'}}},required:['revision','operations']};
const definitions=[
  ['schema','Read table fields, references, module registry and enums.',{table:string},[]],
  ['list','Search rows by name/content; paginated.',{table:string,query:string,offset:{...integer,minimum:0},limit:{...integer,minimum:1,maximum:500}},['table']],
  ['get','Read a complete row and current workspace revision.',{table:string,id:{type:['integer','string']}},['table','id']],
  ['validate','Validate all source tables without writing.',{},[]],
  ['impact','Inspect transitive incoming references before editing/deleting.',{key:string},['key']],
  ['assets','Find existing project 3D models for model-first item authoring.',{query:string},[]],
  ['create_item','Build a model-first item draft with independent subtype, grip, requirement and sockets. No writes; review and save returned operations.',{name:string,modelPath:string,templateId:integer},['name','modelPath','templateId']],
  ['create_npc','Build an NPC draft with independent actor/growth/appearance, one placement and a 24h schedule. No writes; add dialogue and mission rules before save.',{name:string,templateId:integer,areaId:integer,facilityId:integer,recruitable:{type:'boolean'}},['name','templateId','areaId','facilityId','recruitable']],
  ['review','Validate and show before/after for an atomic-intent multi-table patch; no writes.',{patch},['patch']],
  ['save','Save validated multi-table rows; revision required. exportConfig also generates game data and queues Unity asset sync. Inspect sourceSaved/exported/assetError separately.',{patch,exportConfig:{type:'boolean'}},['patch']],
  ['export','Export already saved source revision; queue model/icon/character sync in the open Unity Editor.',{revision:string},['revision']],
  ['asset_job','Queue an actual Unity model preview or content sync; never starts Editor or Play.',{kind:{type:'string',enum:['preview','sync']},path:string},['kind']],
  ['job','Read queued Unity operation result; timeout is not success.',{id:string},['id']],
];
export const mcpTools=definitions.map(([name,description,properties,required])=>({name:'content_'+name,description,inputSchema:{type:'object',properties,required,additionalProperties:false},annotations:{readOnlyHint:!['save','export','asset_job'].includes(name),destructiveHint:name==='save',idempotentHint:!['save','export','asset_job'].includes(name),openWorldHint:false}}));
export function createProtocol(root){
  let initialized=false;
  return message=>{
    const id=message?.id,reply=result=>({jsonrpc:'2.0',id,result}),error=(code,message)=>({jsonrpc:'2.0',id:id??null,error:{code,message}});
    if(!message||message.jsonrpc!=='2.0'||typeof message.method!=='string')return error(-32600,'Invalid Request');
    if(id===undefined)return null;
    if(message.method==='initialize'){
      initialized=true;const versions=['2025-11-25','2025-06-18','2025-03-26','2024-11-05'];
      return reply({protocolVersion:versions.includes(message.params?.protocolVersion)?message.params.protocolVersion:versions[0],capabilities:{tools:{}},serverInfo:{name:'project-y-content-center',version:'1.0.0'},instructions:'Read schema/get; review grouped changes; save with current revision. Conflicts require reread/merge. Source save, binary export and Unity assets have separate outcomes. Never fabricate model paths.'});
    }
    if(message.method==='ping')return reply({});
    if(!initialized)return error(-32000,'Initialize first');
    if(message.method==='tools/list')return reply({tools:mcpTools});
    if(message.method!=='tools/call')return error(-32601,'Method not found');
    const tool=mcpTools.find(t=>t.name===message.params?.name);if(!tool)return error(-32602,'Unknown tool');
    try{
      const args=message.params.arguments||{};if(!args||typeof args!=='object'||Array.isArray(args))throw new Error('Expected object arguments');
      for(const key of tool.inputSchema.required)if(!Object.hasOwn(args,key))throw new Error('Missing argument '+key);
      for(const key of Object.keys(args))if(!Object.hasOwn(tool.inputSchema.properties,key))throw new Error('Unknown argument '+key);
      const result=runCommand(root,tool.name.slice(8),args);
      return reply({content:[{type:'text',text:JSON.stringify(result)}],isError:!!result.error});
    }catch(e){return reply({content:[{type:'text',text:JSON.stringify({error:e.message,status:e.status||400})}],isError:true});}
  };
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const dispatch=createProtocol(path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'));
  for await(const line of readline.createInterface({input:process.stdin,crlfDelay:Infinity})){
    let response;try{response=dispatch(JSON.parse(line));}catch{response={jsonrpc:'2.0',id:null,error:{code:-32700,message:'Parse error'}};}
    if(response)process.stdout.write(JSON.stringify(response)+'\n');
  }
}
