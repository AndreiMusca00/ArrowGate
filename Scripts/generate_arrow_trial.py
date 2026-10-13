#!/usr/bin/env python3
"""Generate a reproducible monochrome playable trial from transparent chapter assets.
Uses point_shape_profiles.json. Writes chapter only after every board is solved.
"""
import argparse, json, random, math, sys
from pathlib import Path
from PIL import Image, ImageDraw
from generate_point_shapes import extract, components
DIRS=[(1,0),(0,1),(-1,0),(0,-1)]
COLOUR='#34373D'
TARGETS=json.loads(Path(__file__).with_name('point_shape_profiles.json').read_text())['arrowCounts']

def ray(head,direction,active):
    dx,dy=DIRS[direction];c=(head[0]+dx,head[1]+dy);out=[]
    while c in active:
        out.append(c);c=(c[0]+dx,c[1]+dy)
    return out

def generate(active,target,seed):
    rng=random.Random(seed);remaining=set(active);arrows=[]
    lanes={(h,d):set(ray(h,d,active)) for h in active for d in range(4)}
    average=len(active)/target
    while remaining:
        free=[(h,d) for h in sorted(remaining) for d in range(4) if not lanes[h,d]&remaining]
        rng.shuffle(free);candidates=[]
        for h,d in free[:65]:
            dx,dy=DIRS[d];path=[h];used={h};second=(h[0]-dx,h[1]-dy)
            if second in remaining:
                path.append(second);used.add(second)
                limit=max(4,round(average)+rng.randint(0,3))
                while len(path)<limit:
                    x,y=path[-1];ns=[(x+a,y+b) for a,b in DIRS]
                    ns=[c for c in ns if c in remaining and c not in used and c not in lanes[h,d]]
                    if not ns:break
                    rng.shuffle(ns)
                    ns.sort(key=lambda c:sum((c[0]+a,c[1]+b) in remaining and (c[0]+a,c[1]+b) not in used for a,b in DIRS))
                    c=ns[0];path.append(c);used.add(c)
            score=len(path)+len(lanes[h,d])*.03+rng.random()
            candidates.append((score,d,path))
        _,d,path=max(candidates,key=lambda c:c[0]);arrows.append((d,path));remaining-=set(path)
    try:
        arrows=fit_budget(arrows,active,target)
        arrows=repair_short_paths(arrows,active)
        arrows=fit_budget(arrows,active,target)
        analyse(arrows,active)
        return arrows
    except (RuntimeError,AssertionError):return None

def analyse(arrows,active,minimum_length=3):
    owner={c:i for i,(_,path) in enumerate(arrows) for c in path}
    assert set(owner)==active and sum(len(p) for _,p in arrows)==len(active)
    deps=[]
    for i,(d,path) in enumerate(arrows):
        assert len(path)>=minimum_length
        if len(path)>1:assert (path[0][0]-path[1][0],path[0][1]-path[1][1])==DIRS[d]
        assert all(abs(a[0]-b[0])+abs(a[1]-b[1])==1 for a,b in zip(path,path[1:]))
        blockers={owner[c] for c in ray(path[0],d,active)}
        assert i not in blockers
        deps.append(blockers)
    remaining=set(range(len(arrows)));widths=[];solution=[]
    while remaining:
        free=sorted(i for i in remaining if not deps[i]&remaining)
        assert free,'Unsolvable dependency cycle'
        widths.append(len(free));solution+=free;remaining.difference_update(free)
    return {'initiallyFree':widths[0],'dependencyLayers':len(widths),'layerWidths':widths,'solution':solution}

def fit_budget(arrows,active,target):
    def orient(body):
        for p in (body,list(reversed(body))):
            delta=(p[0][0]-p[1][0],p[0][1]-p[1][1])
            if delta in DIRS:yield (DIRS.index(delta),p)
    def valid(candidate):
        try:analyse(candidate,active,1);return True
        except AssertionError:return False
    # Split existing paths into valid shorter paths where more arrows are needed.
    while len(arrows)<target:
        found=False
        for i,(d,body) in sorted(enumerate(arrows),key=lambda pair:-len(pair[1][1])):
            for cut in range(3,len(body)-2):
                for a in orient(body[:cut]):
                    for b in orient(body[cut:]):
                        candidate=arrows[:i]+arrows[i+1:]+[a,b]
                        if valid(candidate):arrows=candidate;found=True;break
                    if found:break
                if found:break
            if found:break
        if not found:break
    # Join neighboring paths, including local rerouting, to reduce the count.
    while len(arrows)>target or any(len(p)<3 for _,p in arrows):
        found=False
        pairs=[]
        for i,(_,a) in enumerate(arrows):
            sa=set(a)
            for j in range(i+1,len(arrows)):
                b=arrows[j][1]
                if any((x+dx,y+dy) in sa for x,y in b for dx,dy in DIRS):
                    pairs.append((len(a)+len(b) - (1000 if min(len(a),len(b))<3 else 0),i,j))
        for _,i,j in sorted(pairs):
            if len(arrows)<=target and min(len(arrows[i][1]),len(arrows[j][1]))>=3:continue
            a=arrows[i][1];b=arrows[j][1];rest=[v for k,v in enumerate(arrows) if k not in (i,j)]
            bodies=[]
            for x in (a,list(reversed(a))):
                for y in (b,list(reversed(b))):
                    if abs(x[-1][0]-y[0][0])+abs(x[-1][1]-y[0][1])==1:bodies.append(x+y)
            region=set(a+b);budget=[2500]
            if len(region)<3:continue
            def walk(path,unused):
                budget[0]-=1
                if budget[0]<0:return
                if not unused:yield path;return
                x,y=path[-1];ns=[(x+dx,y+dy) for dx,dy in DIRS];ns=[c for c in ns if c in unused]
                ns.sort(key=lambda c:sum((c[0]+dx,c[1]+dy) in unused for dx,dy in DIRS))
                for c in ns:yield from walk(path+[c],unused-{c})
            def possible():
                yield from bodies
                for h in sorted(region):yield from walk([h],region-{h})
            for body in possible():
                for merged in orient(body):
                    candidate=rest+[merged]
                    if valid(candidate):arrows=candidate;found=True;break
                if found:break
            if found:break
        if not found:break
    return arrows

def repair_short_paths(arrows,active):
    def oriented(path):
        for p in (path,list(reversed(path))):
            if len(p)>=3:yield (DIRS.index((p[0][0]-p[1][0],p[0][1]-p[1][1])),p)
    def valid(candidate):
        try:analyse(candidate,active,1);return True
        except AssertionError:return False
    for iteration in range(100):
        shorts=[i for i,(_,p) in enumerate(arrows) if len(p)<3]
        if not shorts:return arrows
        found=False
        for i in shorts:
            region=set(arrows[i][1])
            neighbors=[j for j,(_,p) in enumerate(arrows) if j!=i and any((x+dx,y+dy) in region for x,y in p for dx,dy in DIRS)]
            groups=[[j] for j in neighbors]
            for j in neighbors:
                near=region|set(arrows[j][1])
                groups += [[j,k] for k,(_,p) in enumerate(arrows) if k not in (i,j) and any((x+dx,y+dy) in near for x,y in p for dx,dy in DIRS)]
            for group in groups:
                union=region|{c for j in group for c in arrows[j][1]}
                rest=[v for k,v in enumerate(arrows) if k not in [i]+group]
                budget=[15000]
                def walk(path,unused):
                    budget[0]-=1
                    if budget[0]<0:return
                    if not unused:yield path;return
                    x,y=path[-1];ns=[(x+dx,y+dy) for dx,dy in DIRS];ns=[c for c in ns if c in unused]
                    ns.sort(key=lambda c:sum((c[0]+dx,c[1]+dy) in unused for dx,dy in DIRS))
                    for c in ns:yield from walk(path+[c],unused-{c})
                def split(path,unused):
                    budget[0]-=1
                    if budget[0]<0:return None
                    if len(path)>=3 and len(unused)>=3 and len(components(unused))==1:
                        for second in walk([min(unused)],unused-{min(unused)}):
                            for a in oriented(path):
                                for b in oriented(second):
                                    if valid(rest+[a,b]):return rest+[a,b]
                    if len(unused)<=3:return None
                    x,y=path[-1]
                    for dx,dy in DIRS:
                        c=(x+dx,y+dy)
                        if c in unused:
                            result=split(path+[c],unused-{c})
                            if result:return result
                    return None
                for h in sorted(union):
                    result=split([h],union-{h})
                    if result:arrows=result;found=True;break
                if found:break
            if found:break
        if not found:raise RuntimeError('Unable to repartition a short path')
    raise RuntimeError('Short-path repair limit reached')

def tune_dependencies(arrows,active,difficulty):
    if difficulty not in ('hard','veryHard','nightmare'):return arrows
    best=analyse(arrows,active)
    def score(stats):return -stats['initiallyFree']*1000+stats['dependencyLayers']*20
    for _ in range(3):
        changed=False
        for i,(d,body) in enumerate(arrows):
            reversed_body=list(reversed(body))
            delta=(reversed_body[0][0]-reversed_body[1][0],reversed_body[0][1]-reversed_body[1][1])
            candidate=arrows.copy();candidate[i]=(DIRS.index(delta),reversed_body)
            try:stats=analyse(candidate,active)
            except AssertionError:continue
            if score(stats)>score(best):arrows=candidate;best=stats;changed=True
        if not changed:break
    return arrows

def draw_board(arrows,active,width,height,path):
    step=16;pad=24
    im=Image.new('RGB',(width*step+pad*2,height*step+pad*2),'#FAF8F2');draw=ImageDraw.Draw(im)
    def xy(c):return (pad+(c[0]+.5)*step,pad+(height-1-c[1]+.5)*step)
    for c in active:
        x,y=xy(c);draw.ellipse((x-1,y-1,x+1,y+1),fill='#DDD9D0')
    for d,body in arrows:
        draw.line([xy(c) for c in body],fill=COLOUR,width=2)
        x,y=xy(body[0]);dx,dy=DIRS[d];dy=-dy
        tip=(x+dx*4,y+dy*4)
        draw.polygon([tip,(x-dx*3-dy*3,y-dy*3+dx*3),(x-dx*3+dy*3,y-dy*3-dx*3)],fill=COLOUR)
    im.save(path)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--chapter',type=Path,default=Path('ArrowGate/Levels/chapter-01.json'))
    ap.add_argument('--output',type=Path,default=Path('Design/ArrowTrial'))
    ap.add_argument('--publish',action='store_true')
    args=ap.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    chapter=json.loads(args.chapter.read_text());profiles=json.loads(Path(__file__).with_name('point_shape_profiles.json').read_text())
    if len(chapter['levels'])!=len(profiles['chapterPlan']):ap.error('Chapter and plan length mismatch')
    assets={p.parent.stem:p for p in Path('ArrowGate/Assets.xcassets').rglob('*.png') if p.parent.suffix=='.imageset'}
    report=[]
    backup=args.output/'original-chapter-01.json'
    if not backup.exists():backup.write_text(args.chapter.read_text())
    for index,level in enumerate(chapter['levels']):
        difficulty=profiles['chapterPlan'][index];target=TARGETS[difficulty]
        grid=profiles['introGridSizes'][index] if index<4 else profiles['gridSizes'][difficulty]
        while True:
            shape,_=extract(assets[level['completionArtwork']],grid,128,.35)
            active={(c['x'],c['y']) for c in shape['activeCells']}
            # Sub-three disconnected islands cannot hold an arrow. Explicitly record their removal.
            todo=set(active);removed=set()
            while todo:
                region={todo.pop()};stack=list(region)
                while stack:
                    x,y=stack.pop()
                    for dx,dy in DIRS:
                        c=(x+dx,y+dy)
                        if c in todo:todo.remove(c);region.add(c);stack.append(c)
                if len(region)<3:removed.update(region)
            active-=removed
            if len(active)>=target*5:break
            grid+=1
        arrows=None
        for attempt in range(6):
            arrows=generate(active,target,level['id']*1000+attempt)
            if arrows is not None:break
            print(f"Level {level['id']}: retry {attempt+1}",flush=True)
        if arrows is None:
            # Retry at a slightly higher resolution before rejecting the entire batch.
            for extra in (2,4,6):
                shape,_=extract(assets[level['completionArtwork']],grid+extra,128,.35)
                active={(c['x'],c['y']) for c in shape['activeCells']}
                tiny={c for c in active if not any((c[0]+dx,c[1]+dy) in active for dx,dy in DIRS)}
                active-=tiny;removed=tiny
                for attempt in range(3):
                    arrows=generate(active,target,level['id']*1000+extra*10+attempt)
                    if arrows is not None:break
                if arrows is not None:grid+=extra;break
        if arrows is None:raise RuntimeError(f"Could not fill level {level['id']} with {target} arrows")
        arrows=fit_budget(arrows,active,target)
        arrows=tune_dependencies(arrows,active,difficulty)
        if len(arrows)!=target:raise RuntimeError(f"Level {level['id']} did not reach its arrow budget")
        metrics=analyse(arrows,active)
        cell=lambda c:{'x':c[0],'y':c[1]}
        level.update(size=shape['size'],height=shape['height'],difficulty=difficulty,
                     timeLimit=0 if level['id']==1 else {'easy':120,'hard':180,'veryHard':240,'nightmare':360}[difficulty],
                     arrows=[{'id':i,'head':cell(body[0]),'direction':d,'color':COLOUR,'length':len(body),'body':[cell(c) for c in body]} for i,(d,body) in enumerate(arrows)],
                     gates=[],activeCells=[cell(c) for c in sorted(active,key=lambda c:(c[1],c[0]))],
                     targetCells=[{'cell':cell(c),'color':COLOUR} for c in sorted(active,key=lambda c:(c[1],c[0]))])
        record={'levelID':level['id'],'difficulty':difficulty,'gridSize':grid,'pointCount':len(active),'arrowCount':len(arrows),'removedTinyIslandCells':[cell(c) for c in sorted(removed)],**metrics}
        record['targetArrowCount']=target
        report.append(record)
        (args.output/f"level-{level['id']:02d}.json").write_text(json.dumps({'level':level,'report':record},ensure_ascii=False)+'\n')
        draw_board(arrows,active,shape['size'],shape['height'],args.output/f"level-{level['id']:02d}.png")
        print(f"Level {level['id']}: {difficulty}, {grid}, {len(active)} points, {len(arrows)} arrows, {metrics['initiallyFree']} free",flush=True)
    (args.output/'chapter-01.json').write_text(json.dumps(chapter,ensure_ascii=False,separators=(',',':'))+'\n')
    (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    if args.publish:args.chapter.write_text(json.dumps(chapter,ensure_ascii=False,separators=(',',':'))+'\n')

if __name__=='__main__':main()
