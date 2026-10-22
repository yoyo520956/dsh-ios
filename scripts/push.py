#!/usr/bin/env python3
"""向空/已有仓库推送整棵目录，建 main ref。用法: python3 scripts/push.py"""
import base64, json, os, subprocess, sys, urllib.request, urllib.error

REPO = os.environ.get('DSH_REPO', 'yoyo520956/dsh-ios')
TOK = os.environ['GITHUB_TOKEN']
H = {'Authorization': 'Bearer ' + TOK, 'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json'}

def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request('https://api.github.com/repos/' + REPO + path, data=data, headers=H, method=method)
    try:
        return json.load(urllib.request.urlopen(req, timeout=120))
    except urllib.error.HTTPError as e:
        print('HTTP', e.code, path, e.read()[:200])
        raise

# 1) 本地 git 列 HEAD 树（server 上还没有对象）
files = subprocess.check_output(['git', 'ls-tree', '-r', 'HEAD']).decode().strip().splitlines()
print('files:', len(files))

blobs = {}
for line in files:
    meta, path = line.split('\t', 1)
    mode, otype, sha = meta.split()
    content = subprocess.check_output(['git', 'show', f'HEAD:{path}'])
    b = api('POST', '/git/blobs', {'content': base64.b64encode(content).decode(), 'encoding': 'base64'})
    blobs[path] = b['sha']
    print('blob', path, b['sha'][:10])

# 2) 从叶子目录起逐层建 tree
from collections import defaultdict
dirs = defaultdict(list)
for p in blobs:
    parent = os.path.dirname(p)
    dirs[parent].append((os.path.basename(p), 'blob', blobs[p]))

def build(dirpath):
    entries = []
    subs = {d: v for d, v in dirs.items() if d != dirpath and (d.startswith(dirpath + '/') if dirpath else True)
            and (os.path.dirname(d) == dirpath if dirpath else '/' not in d)}
    # 本目录直属 blob
    for name, _, sha in dirs.get(dirpath, []):
        entries.append({'path': name, 'mode': '100644', 'type': 'blob', 'sha': sha})
    # 本目录直属子目录（先递归建）
    for d in list(subs):
        subsha = build(d)
        entries.append({'path': os.path.basename(d), 'mode': '040000', 'type': 'tree', 'sha': subsha})
    return api('POST', '/git/trees', {'tree': entries})['sha']

root_tree = build('')
print('root tree:', root_tree)

# 3) commit（main 可能已存在 → 带 parent）
try:
    ref = api('GET', '/git/refs/heads/main')
    parents = [ref['object']['sha']]
except Exception:
    parents = []
c = api('POST', '/git/commits', {'message': sys.argv[1] if len(sys.argv) > 1 else 'push via API', 'tree': root_tree, 'parents': parents})
print('commit:', c['sha'])
if parents:
    api('PATCH', '/git/refs/heads/main', {'sha': c['sha'], 'force': True})
else:
    api('POST', '/git/refs', {'ref': 'refs/heads/main', 'sha': c['sha']})
print('done')
