#!/usr/bin/env python3
"""Extract regular point grids from transparent asset images; never edits the catalog.
Requires Pillow. Example:
  python3 Scripts/generate_point_shapes.py --grid-size 30 --output Design/PointShapes
Coordinates in JSON use the game's bottom-left origin. All disconnected regions
and holes are preserved and reported, rather than silently filled or removed.
"""
import argparse
import json
import math
from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw


def components(cells):
    remaining = set(cells)
    sizes = []
    while remaining:
        queue = deque([remaining.pop()])
        count = 0
        while queue:
            x, y = queue.popleft()
            count += 1
            for neighbor in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    queue.append(neighbor)
        sizes.append(count)
    return sorted(sizes, reverse=True)


def extract(path, grid_size, alpha_threshold, coverage):
    image = Image.open(path).convert('RGBA')
    mask = image.getchannel('A').point(lambda a: 255 if a >= alpha_threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError(f'{path}: empty image at selected alpha threshold')
    if image.getchannel('A').getextrema()[0] == 255:
        raise ValueError(f'{path}: opaque background; supply a transparent image or mask')
    mask = mask.crop(bbox)
    w, h = mask.size
    scale = grid_size / max(w, h)
    width, height = max(1, round(w * scale)), max(1, round(h * scale))
    sampled = mask.resize((width, height), Image.Resampling.BOX)
    cells = [(x, height-1-y) for y in range(height) for x in range(width)
             if sampled.getpixel((x,y)) / 255 >= coverage]
    if not cells:
        raise ValueError(f'{path}: no cells; lower coverage or increase grid size')
    sizes = components(cells)
    result = {
        'source': str(path), 'size': width, 'height': height,
        'coordinateOrigin': 'bottomLeft', 'sourceBounds': list(bbox),
        'parameters': {'gridSize': grid_size, 'alphaThreshold': alpha_threshold,
                       'minimumCoverage': coverage},
        'activeCells': [{'x':x,'y':y} for x,y in cells],
        'statistics': {'pointCount':len(cells), 'componentSizes':sizes,
                       'isolatedPointCount': sizes.count(1)}
    }
    return result, image.crop(bbox)


def preview(result, source):
    panel = 340
    canvas = Image.new('RGB', (panel*2, 400), '#FAF8F2')
    draw = ImageDraw.Draw(canvas)
    draw.text((16,12), Path(result['source']).stem + (' | '+result['difficulty'] if result.get('difficulty') else ''), fill='#292A30')
    thumb = source.copy()
    thumb.thumbnail((300,300), Image.Resampling.LANCZOS)
    canvas.paste(thumb, ((panel-thumb.width)//2, 45+(300-thumb.height)//2), thumb)
    w,h = result['size'],result['height']
    step = 290 / max(w,h)
    left = panel+(panel-step*w)/2
    top = 45+(300-step*h)/2
    radius = step*0.17
    for c in result['activeCells']:
        x=left+(c['x']+0.5)*step
        y=top+(h-1-c['y']+0.5)*step
        draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill='#34373D')
    stats=result['statistics']
    draw.text((16,360), 'Original',fill='#666666')
    draw.text((panel+16,360), f"{w} x {h} | {stats['pointCount']} points | {len(stats['componentSizes'])} regions",fill='#666666')
    return canvas


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets',type=Path,default=Path('Backend/ContentSource/Artwork'))
    parser.add_argument('--image',type=Path,help='Process one transparent image instead of all image sets')
    parser.add_argument('--output',type=Path,default=Path('Design/PointShapes'))
    parser.add_argument('--grid-size',type=int,help='Explicit longest side; overrides difficulty size')
    parser.add_argument('--difficulty',choices=['tutorial','easy','normal','hard','veryHard','nightmare'])
    parser.add_argument('--profiles',type=Path,default=Path(__file__).with_name('point_shape_profiles.json'))
    parser.add_argument('--chapter',type=Path,help='Generate artwork shapes for levels in a chapter JSON')
    parser.add_argument('--use-plan',action='store_true',help='Use the configured 25-level plan instead of existing difficulty labels')
    parser.add_argument('--alpha-threshold',type=int,default=128)
    parser.add_argument('--coverage',type=float,default=0.35,help='Minimum fraction of opaque pixels per cell')
    args=parser.parse_args()
    if (args.grid_size is not None and args.grid_size<3) or not 1<=args.alpha_threshold<=255 or not 0<args.coverage<=1:
        parser.error('grid-size >= 3, alpha-threshold 1..255, coverage (0,1]')
    profiles=json.loads(args.profiles.read_text())
    if args.use_plan and not args.chapter:
        parser.error('--use-plan requires --chapter')
    if args.chapter and (args.image or args.difficulty):
        parser.error('--chapter cannot be combined with --image or --difficulty')
    paths=[args.image] if args.image else sorted(args.assets.rglob('*.imageset/Contents.json'))
    if not args.image:
        selected=[]
        for metadata in paths:
            entries=json.loads(metadata.read_text()).get('images',[])
            names=list(dict.fromkeys(e['filename'] for e in entries if e.get('filename')))
            if names: selected.append(metadata.parent/names[-1])
        paths=selected
    asset_paths={path.parent.stem:path for path in paths}
    jobs=[]
    if args.chapter:
        chapter=json.loads(args.chapter.read_text())
        levels=chapter['levels']
        plan=profiles['chapterPlan']
        if args.use_plan and len(levels)!=len(plan):
            parser.error(f'Plan has {len(plan)} entries but chapter has {len(levels)} levels')
        for index,level in enumerate(levels):
            difficulty=plan[index] if args.use_plan else level.get('difficulty') or 'normal'
            asset=level.get('completionArtwork')
            if asset not in asset_paths: parser.error(f'Missing artwork asset for level {level["id"]}: {asset}')
            override=profiles.get('levelOverrides',{}).get(str(level['id']),{})
            grid=args.grid_size or override.get('gridSize') or (profiles['introGridSizes'][index] if index<len(profiles['introGridSizes']) and difficulty in ('tutorial','easy') else profiles['gridSizes'][difficulty])
            jobs.append((asset_paths[asset],f'level-{level["id"]:03d}-{asset}',grid,difficulty,level['id'],level.get('difficulty')))
    else:
        grid=args.grid_size or profiles['gridSizes'].get(args.difficulty,30)
        jobs=[(path,path.stem if args.image else path.parent.stem,grid,args.difficulty,None,None) for path in paths]
    if not jobs: parser.error('No image assets found')
    args.output.mkdir(parents=True,exist_ok=True)
    tiles=[];summary=[]
    for path,name,grid,difficulty,level_id,catalog_difficulty in jobs:
        result,source=extract(path,grid,args.alpha_threshold,args.coverage)
        result.update(difficulty=difficulty,levelID=level_id)
        result['parameters']['minimumArrowLength']=3
        result['catalogDifficulty']=catalog_difficulty
        (args.output/f'{name}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
        tile=preview(result,source)
        tile.save(args.output/f'{name}.png')
        tiles.append(tile)
        summary.append({'asset':name,'levelID':level_id,'difficulty':difficulty,'catalogDifficulty':catalog_difficulty,'gridSize':grid,**result['statistics'],'width':result['size'],'height':result['height']})
    sheet=Image.new('RGB',(680*2,400*math.ceil(len(tiles)/2)),'#FAF8F2')
    for i,tile in enumerate(tiles):sheet.paste(tile,((i%2)*680,(i//2)*400))
    sheet.save(args.output/'overview.png')
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(f'Generated {len(summary)} shapes in {args.output}')
    print(f"Isolated points: {sum(s['isolatedPointCount'] for s in summary)} (preserved for inspection)")


if __name__=='__main__':
    main()
