#!/usr/bin/env python3
"""Map opaque, high-contrast artwork colours onto existing paths without moving cells."""
import argparse,copy,json
from pathlib import Path
from PIL import Image,ImageDraw
from catalog_json import dumps_catalog

def luminance(rgb):
    linear=[v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb]
    return sum(a*b for a,b in zip(linear,(.2126,.7152,.0722)))

def contrast(rgb):return 1.05/(luminance(rgb)+.05)

def readable(rgb,minimum):
    original=rgb
    while contrast(rgb)<minimum:
        rgb=tuple(max(0,round(v*.97)-1) for v in rgb)
    return '#'+''.join(f'{v:02X}' for v in rgb)

def without_colours(value):
    if isinstance(value,dict):return {k:without_colours(v) for k,v in value.items() if k!='color'}
    if isinstance(value,list):return [without_colours(v) for v in value]
    return value

def map_level(level,path,palette_size,minimum):
    image=Image.open(path).convert('RGBA')
    bounds=image.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
    if not bounds:raise ValueError(f'Empty artwork: {path}')
    image=image.crop(bounds)
    sample=image.copy();sample.thumbnail((160,160))
    opaque=[p[:3] for y in range(sample.height) for x in range(sample.width) if (p:=sample.getpixel((x,y)))[3]>=128]
    strip=Image.new('RGB',(len(opaque),1));strip.putdata(opaque)
    quantized=strip.quantize(colors=palette_size,method=Image.Quantize.MEDIANCUT)
    table=quantized.getpalette()
    palette=[tuple(table[i*3:i*3+3]) for _,i in sorted(quantized.getcolors(),reverse=True)]
    # RGBA resize uses premultiplied alpha, avoiding black bleed at the contour.
    cells=image.resize((level['size'],level['height']),Image.Resampling.BOX)
    owner={};changes=[]
    for arrow in level['arrows']:
        votes=[0.0]*len(palette)
        for c in arrow['body']:
            r,g,b,a=cells.getpixel((c['x'],level['height']-1-c['y']))
            nearest=min(range(len(palette)),key=lambda i:sum((v-p)**2 for v,p in zip((r,g,b),palette[i])))
            votes[nearest]+=a/255
        chosen=max(range(len(palette)),key=lambda i:votes[i])
        colour=readable(palette[chosen],minimum)
        changes.append({'arrowID':arrow['id'],'sourceColour':'#'+''.join(f'{v:02X}' for v in palette[chosen]),'colour':colour})
        arrow['color']=colour
        for c in arrow['body']:owner[c['x'],c['y']]=colour
    for target in level.get('targetCells') or []:
        c=target['cell'];target['color']=owner[c['x'],c['y']]
    # Optional gate colours are metadata; preserve gate positions and properties.
    for gate in level.get('gates',[]):
        matches=[a for a in level['arrows'] if a['direction']==gate['key']['side'] and (a['head']['y'] if a['direction'] in (0,2) else a['head']['x'])==gate['key']['lane']]
        if matches:gate['color']=matches[0]['color']
    return changes

def preview(level,path):
    step=16;pad=24
    im=Image.new('RGB',(level['size']*step+48,level['height']*step+48),'#FFFFFF');draw=ImageDraw.Draw(im)
    def xy(c):return (pad+(c['x']+.5)*step,pad+(level['height']-1-c['y']+.5)*step)
    dirs=[(1,0),(0,1),(-1,0),(0,-1)]
    for a in level['arrows']:
        draw.line([xy(c) for c in a['body']],fill=a['color'],width=3)
        x,y=xy(a['head']);dx,dy=dirs[a['direction']];dy=-dy
        draw.polygon([(x+dx*5,y+dy*5),(x-dx*3-dy*3,y-dy*3+dx*3),(x-dx*3+dy*3,y-dy*3-dx*3)],fill=a['color'])
    im.save(path)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chapter',type=Path,default=Path('ArrowGate/Levels/chapter-01.json'))
    parser.add_argument('--output',type=Path,default=Path('Design/ColourMapping'))
    parser.add_argument('--palette-size',type=int,default=12)
    parser.add_argument('--minimum-contrast',type=float,default=4.5)
    parser.add_argument('--publish',action='store_true')
    args=parser.parse_args()
    if not 2<=args.palette_size<=64 or not 1<=args.minimum_contrast<=21:parser.error('Invalid palette size or contrast')
    chapter=json.loads(args.chapter.read_text());before=copy.deepcopy(chapter)
    args.output.mkdir(parents=True,exist_ok=True)
    assets={p.parent.stem:p for p in Path('ArrowGate/Assets.xcassets').rglob('*.png') if p.parent.suffix=='.imageset'}
    report=[]
    for level in chapter['levels']:
        changes=map_level(level,assets[level['completionArtwork']],args.palette_size,args.minimum_contrast)
        colours=set(a['color'] for a in level['arrows'])
        assert all(contrast(tuple(bytes.fromhex(c[1:])))>=args.minimum_contrast for c in colours)
        report.append({'levelID':level['id'],'colourCount':len(colours),'minimumContrast':min(contrast(tuple(bytes.fromhex(c[1:]))) for c in colours),'arrows':changes})
        preview(level,args.output/f"level-{level['id']:02d}.png")
    assert without_colours(before)==without_colours(chapter),'Geometry or other level properties changed'
    (args.output/'before.json').write_text(dumps_catalog(before)+'\n')
    (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    text=dumps_catalog(chapter)+'\n'
    (args.output/args.chapter.name).write_text(text)
    if args.publish:args.chapter.write_text(text)
    print(f"Mapped {len(report)} levels; geometry unchanged; white contrast >= {args.minimum_contrast}:1")

if __name__=='__main__':main()
