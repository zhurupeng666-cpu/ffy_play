import json
from pathlib import Path

root = Path(__file__).parent
def obj(properties, required=None):
    return {'type':'object','properties':properties,'required':list(properties) if required is None else required,'additionalProperties':False}
def arr(item): return {'type':'array','items':item}
def ref(name): return {'$ref':'#/$defs/'+name}
string={'type':'string','minLength':1}
integer={'type':'integer','minimum':0}
number={'type':'number','minimum':0,'maximum':100}
boolean={'type':'boolean'}
nullable={'type':['string','null']}
ids=arr(string)
amounts={'type':'object','additionalProperties':integer}
collection=lambda name: {'type':'object','additionalProperties':ref(name)}
defs={}
defs['inventory']=obj({'id':string,'capacity':amounts,'amounts':amounts,'reserved':amounts})
defs['population']=obj({k:integer for k in ['employable','dependents','employed','builders','training','idle','housing_capacity']})
defs['clock']=obj({'strategic_tick':integer,'day':integer,'last_settled_day':integer,'speed':{'enum':[1,2,4]},'paused':boolean})
defs['region']=obj({'id':string,'def_id':string,'owner_id':nullable,'visibility':{'enum':['hidden','known','scouted']},'access':{'enum':['blocked','open']},'town_ids':ids,'resource_sites':arr(string)})
defs['town']=obj({'id':string,'region_id':string,'population':ref('population'),'inventory':ref('inventory'),'building_ids':ids,'tax_policy':{'enum':['low','standard','high']},'satisfaction':number})
defs['building']=obj({'id':string,'def_id':string,'town_id':string,'level':{'type':'integer','minimum':1,'maximum':3},'cell':{'type':'array','items':{'type':'integer'},'minItems':2,'maxItems':2},'state':{'enum':['constructing','active','disabled','destroyed']},'workers':integer,'progress':number})
defs['soldier']=obj({'id':string,'def_id':string,'squad_id':string,'hp':integer,'status':{'enum':['healthy','wounded','dead']},'equipment_tier':{'type':'integer','minimum':0,'maximum':2}})
defs['squad']=obj({'id':string,'army_id':string,'unit_def_id':string,'soldier_ids':ids})
defs['order']=obj({'type':{'enum':['idle','move','attack_move','hold','focus','retreat','travel','scout']},'target_id':nullable})
defs['army']=obj({'id':string,'owner_id':string,'region_id':string,'squad_ids':ids,'inventory':ref('inventory'),'order':ref('order'),'morale':number,'satisfaction':number,'arrears':integer})
defs['quest']=obj({'id':string,'status':{'enum':['locked','active','completed','failed']},'counters':amounts,'claimed':boolean})
defs['training']=obj({'id':string,'town_id':string,'unit_def_id':string,'target_army_id':string,'reserved_people':integer,'remaining_work':integer})
defs['shipment']=obj({'id':string,'origin_id':string,'destination_id':string,'route':ids,'cargo':amounts,'edge_progress':number})
defs['market_order']=obj({'id':string,'town_id':string,'cargo':amounts,'paid_gold':integer,'arrival_day':integer})
# v1 only accepts deployment snapshots. Runtime battle persistence requires a schema migration.
defs['battle']=obj({'id':string,'phase':{'const':'deployment'},'region_id':string,'participants':ids,'tick':{'const':0},'rng_state':string,'result_applied':{'const':False}})
props={'schema_version':{'const':1},'game_version':string,'content_version':string,'campaign_id':string,'revision':integer,'id_counters':amounts,'rng':obj({'seed':string,'state':string}),'clock':ref('clock'),'treasury':obj({'gold':integer}),'regions':collection('region'),'towns':collection('town'),'buildings':collection('building'),'soldiers':collection('soldier'),'squads':collection('squad'),'armies':collection('army'),'training_orders':arr(ref('training')),'shipments':arr(ref('shipment')),'pending_market_orders':arr(ref('market_order')),'battle_states':arr(ref('battle')),'technology':obj({'unlocked_ids':ids,'active_id':nullable,'progress_hours':integer}),'quests':collection('quest'),'event_history':ids,'applied_result_ids':ids}
schema={'$schema':'https://json-schema.org/draft/2020-12/schema','$id':'https://frontier-guardian.local/save-v1.schema.json','title':'Frontier Guardian MVP Save v1',**obj(props),'$defs':defs}
save={'schema_version':1,'game_version':'0.1.0','content_version':'mvp-001','campaign_id':'campaign_test_001','revision':1,'id_counters':{'army':1,'squad':1,'soldier':1,'building':1},'rng':{'seed':'12345','state':'12345'},'clock':{'strategic_tick':0,'day':1,'last_settled_day':0,'speed':1,'paused':True},'treasury':{'gold':300},'regions':{},'towns':{},'buildings':{},'soldiers':{},'squads':{},'armies':{},'training_orders':[],'shipments':[],'pending_market_orders':[],'battle_states':[],'technology':{'unlocked_ids':[],'active_id':None,'progress_hours':0},'quests':{'q_food':{'id':'q_food','status':'active','counters':{'produced_food':0},'claimed':False}},'event_history':[],'applied_result_ids':[]}
for region,vis,owner,towns in [('r_home','scouted','player',['town_000001']),('r_woods','known',None,[]),('r_fort','hidden','enemy',[])]:
    save['regions'][region]={'id':region,'def_id':region,'owner_id':owner,'visibility':vis,'access':'open','town_ids':towns,'resource_sites':[]}
inv=lambda id,cap,amount: {'id':id,'capacity':cap,'amounts':amount,'reserved':{}}
save['towns']['town_000001']={'id':'town_000001','region_id':'r_home','population':{'employable':24,'dependents':6,'employed':0,'builders':0,'training':0,'idle':24,'housing_capacity':30},'inventory':inv('inv_town_000001',{'food':1000,'material':1000},{'wood':120000,'stone':80000,'grain':60000,'food':180000}),'building_ids':['building_000001'],'tax_policy':'standard','satisfaction':50}
save['buildings']['building_000001']={'id':'building_000001','def_id':'b_hall','town_id':'town_000001','level':1,'cell':[10,10],'state':'active','workers':0,'progress':100}
save['armies']['army_000001']={'id':'army_000001','owner_id':'player','region_id':'r_home','squad_ids':['squad_000001'],'inventory':inv('inv_army_000001',{'food':8},{'food':5000}),'order':{'type':'idle','target_id':None},'morale':70,'satisfaction':70,'arrears':0}
save['squads']['squad_000001']={'id':'squad_000001','army_id':'army_000001','unit_def_id':'u_shield','soldier_ids':['soldier_000001']}
save['soldiers']['soldier_000001']={'id':'soldier_000001','def_id':'u_shield','squad_id':'squad_000001','hp':100,'status':'healthy','equipment_tier':0}
for filename,data in [('frontier_guardian.schema.json',schema),('frontier_guardian.save.example.json',save)]:
    (root/filename).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
try:
    import jsonschema
    jsonschema.Draft202012Validator.check_schema(schema)
    jsonschema.validate(save,schema)
    print('Schema and example validated')
except ImportError:
    print('JSON generated; jsonschema library unavailable')
assert save['towns']['town_000001']['population']['idle']==24
for army in save['armies'].values():
    assert army['region_id'] in save['regions']
    for squad_id in army['squad_ids']:
        squad=save['squads'][squad_id]
        assert squad['army_id']==army['id']
        for soldier_id in squad['soldier_ids']:
            assert save['soldiers'][soldier_id]['squad_id']==squad_id
print('Example references checked')
