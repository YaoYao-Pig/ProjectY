"""Retrieve the author's free Standard download through itch.io's public free-download flow."""
import http.cookiejar
import json
import re
import urllib.parse
import urllib.request
import hashlib
import io
import zipfile
from pathlib import Path
from html.parser import HTMLParser

base = 'https://quaternius.itch.io/universal-animation-library'
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
page = opener.open(base, timeout=25).read().decode()
token = re.search(r'<meta name="csrf_token" value="([^"]+)"', page).group(1)
endpoint = json.loads('"' + re.search(r'"generate_download_url":"([^"]+)"', page).group(1) + '"')
request = urllib.request.Request(endpoint, urllib.parse.urlencode({'csrf_token': token}).encode(),
    headers={'Referer': base, 'X-Requested-With': 'XMLHttpRequest'})
response = json.loads(opener.open(request, timeout=25).read())
assert 'url' in response, 'Free download page was not returned: ' + str(list(response))
download = opener.open(response['url'], timeout=25).read().decode()
# Report public file metadata only; session tokens and signed URLs stay in memory.
class Links(HTMLParser):
    uploads=[]
    def handle_starttag(self, tag, attrs):
        values=dict(attrs)
        if values.get('data-upload_id'):
            self.uploads.append(values['data-upload_id'])
Links().feed(download)
assert len(Links.uploads)==1 and '[Standard].zip' in download, 'Only the free Standard file is expected'
token=re.search(r'<meta name="csrf_token" value="([^"]+)"',download).group(1)
request=urllib.request.Request(base+'/file/'+Links.uploads[0]+'?source=game_download&as_props=1',
    urllib.parse.urlencode({'csrf_token':token}).encode(),headers={'Referer':response['url'],'X-Requested-With':'XMLHttpRequest'})
link=json.loads(opener.open(request,timeout=25).read())
assert 'url' in link, str(link.get('errors','Download URL unavailable'))
with opener.open(link['url'],timeout=45) as stream:
    archive=stream.read(35*1024*1024+1)
assert len(archive)<=35*1024*1024 and archive[:2]==b'PK','Unexpected archive payload'
root=Path(__file__).resolve().parents[1]
target=root/'ThirdParty/UAL1-Standard.zip';target.write_bytes(archive)
with zipfile.ZipFile(io.BytesIO(archive)) as z:
    files=z.namelist()
record={'source':base,'license':'CC0-1.0','file':target.name,'sha256':hashlib.sha256(archive).hexdigest(),'bytes':len(archive),'contents':files}
(root/'Integration/ual-source.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False,indent=2))
