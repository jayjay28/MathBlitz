
import os, time, requests, jwt

TEAM_ID=os.environ['CK_TEAM_ID']
KEY_ID=os.environ['CK_KEY_ID']
CONTAINER=os.environ['CK_CONTAINER_ID']
CK_ENV=os.environ.get('CK_ENV','development')

raw=os.environ['CK_PRIVATE_KEY'].replace('\\n','\n')
# strip wrapping quotes if the key is passed through env with quotes included
if raw.startswith('"') and raw.endswith('"'):
    raw=raw[1:-1]
PRIVATE_KEY=raw

now=int(time.time())
token=jwt.encode(
{'iss': TEAM_ID, 'iat': now, 'exp': now+45*60},
PRIVATE_KEY,
algorithm='ES256',
headers={'kid': KEY_ID},
)

payload={
'operations': [{
  'operationType':'forceUpdate',
  'record':{
      'recordType':'BroadcastMessage',
      'recordName':f'broadcast-{now}',
      'fields':{
	  'title':{'value':'Local Test'},
	  'body':{'value':'Ping'},
	  'createdAt':{'value':time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())},
      },
  }
}]
}

url=f"https://api.apple-cloudkit.com/database/1/{CONTAINER}/{CK_ENV}/public/records/modify"
resp=requests.post(url, json=payload, headers={'Authorization':f'Bearer {token}'}, timeout=10)
print('status', resp.status_code)
print(resp.text)
