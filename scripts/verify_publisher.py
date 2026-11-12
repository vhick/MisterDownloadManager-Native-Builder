#!/usr/bin/env python3
"""Validate pinned publisher source identity and documented action interface."""
import re
import subprocess
import urllib.request

REF='cb64f86ac2d8c67506db5832de07f9ff58cbeaeb' # verified upstream v1.1.1 release commit
REMOTE='https://github.com/vhick/portable-release-publisher.git'
url=f'https://raw.githubusercontent.com/vhick/portable-release-publisher/{REF}/action.yml'
result=subprocess.run(['git','ls-remote',REMOTE,'refs/tags/v1.1.1','refs/tags/v1.1.1^{}'],
                      capture_output=True,text=True,check=True)
shas = [row.split()[0].lower() for row in result.stdout.splitlines()]
if REF not in shas:
    raise RuntimeError('Pinned action tag moved; refusing build')
request=urllib.request.Request(url,headers={'User-Agent':'mdm-native-builder-b1r4'})
with urllib.request.urlopen(request,timeout=30) as response:
    content=response.read().decode('utf-8')
for parameter in ('files:','tag:','release-title:','tag-prefix:',
                  'keep-releases:','prune:','dry-run:'):
    if not re.search(r'^  '+re.escape(parameter)+r'\s*$', content, flags=re.MULTILINE):
        raise RuntimeError(f'Unexpected pinned publisher interface: {parameter}')
for indicator in ('using: composite','shell: bash','PUBLISH_DRY_RUN:', 'github.token'):
    if indicator not in content: raise RuntimeError(f'Publisher marker missing: {indicator}')
print('SOURCE-INSPECTED: publisher v1.1.1 tag, immutable SHA and inputs match requirements')
